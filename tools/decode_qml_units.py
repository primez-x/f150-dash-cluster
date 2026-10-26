"""Decode Qt 5.14.2 cache metadata without target execution or binary edits."""
import argparse
import collections
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import capstone

SHA256 = "2451c3fb6f6c1344625aa2882760eaaccd3dc0979ad1296c9028838e77e2823b"
BASE = Path(__file__).resolve().parents[1]
BIND_TYPES = ["Invalid", "Boolean", "Number", "String", "Null", "Translation", "TranslationById", "Script", "Object", "AttachedProperty", "GroupProperty"]
BUILTINS = "Var Variant Int Bool Real String Url Color Font Time Date DateTime Rect Point Size Vector2D Vector3D Vector4D Matrix4x4 Quaternion InvalidBuiltin".split()
TABLES = ["string", "function", "class", "templateObject", "block", "lookup", "regexp", "constant", "jsClass", "translation", "localExportEntry", "indirectExportEntry", "starExportEntry", "importEntry", "moduleRequest"]
STRIDES = [4, 4, 4, 4, 4, 4, 4, 8, 4, 16, 20, 20, 20, 16, 4]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify_identity(data):
    require(hashlib.sha256(data).hexdigest() == SHA256, "source identity mismatch")


def location(value):
    return {"line": value & 0xfffff, "column": value >> 20}


def number(value):
    tag = value >> 32
    if tag == 0x38000:
        return {"kind": "int32", "value": struct.unpack("<i", struct.pack("<I", value & 0xffffffff))[0]}
    if tag == 0x30000:
        return {"kind": "boolean", "value": bool(value & 0xffffffff)}
    if tag == 0x28000:
        return {"kind": "null", "value": None}
    if value == 0:
        return {"kind": "undefined"}
    if value >> 50:
        result = struct.unpack("<d", struct.pack("<Q", value ^ 0xfffc000000000000))[0]
        return {"kind": "double", "value": result if math.isfinite(result) else str(result)}
    return {"kind": "unresolved", "raw": hex(value)}


def opcode_schema(path):
    text = path.read_text(encoding="utf-8")
    definitions = {}
    for match in re.finditer(r"^#define INSTR_(\w+)\(op\) INSTRUCTION\(op, \w+, (\d+)([^\n]*)", text, re.M):
        name, count, tail = match.groups()
        args = tail.rstrip().rstrip(")").lstrip(", ").split(", ") if int(count) else []
        require(len(args) == int(count), "opcode operand schema mismatch")
        definitions[name] = args
    region = text.split("#define FOR_EACH_MOTH_INSTR(F)", 1)[1].split("#define MOTH_NUM_INSTRUCTIONS", 1)[0]
    order = ["Nop"] + re.findall(r"F\((\w+)\)", region)
    require(len(order) == len(set(order)) and all(name in definitions for name in order), "invalid opcode order")
    return [(name, definitions[name]) for name in order]


def infer_expression(function):
    """Infer a single branch-free return expression; reject all unsupported operations."""
    accumulator = None
    registers = {}
    calls = []
    binary_ops = {"Add": "+", "Sub": "-", "Mul": "*", "Div": "/", "Mod": "%", "Exp": "**",
                  "CmpEq": "==", "CmpNe": "!=", "CmpStrictEqual": "===", "CmpStrictNotEqual": "!==",
                  "CmpGt": ">", "CmpGe": ">=", "CmpLt": "<", "CmpLe": "<=", "BitAnd": "&", "BitOr": "|",
                  "BitXor": "^", "UShr": ">>>", "Shr": ">>", "Shl": "<<"}

    def literal(constant):
        if constant["kind"] in {"int32", "double", "boolean", "null"}:
            return json.dumps(constant["value"], ensure_ascii=True)
        return None

    for row in function["bytecode"]:
        name, args, refs = row["name"], row["args"], row.get("references", {})
        if name in {"Nop", "CreateCallContext", "PopContext"}:
            continue
        if name in {"LoadName", "LoadGlobalLookup", "LoadQmlContextPropertyLookup"}:
            accumulator = refs.get("name", refs.get("index"))
        elif name in {"LoadRuntimeString", "LoadInt", "LoadTrue", "LoadFalse", "LoadZero", "LoadNull", "LoadUndefined"}:
            accumulator = {"LoadTrue": "true", "LoadFalse": "false", "LoadZero": "0", "LoadNull": "null", "LoadUndefined": "undefined"}.get(name)
            if name == "LoadRuntimeString":
                accumulator = json.dumps(refs["stringId"], ensure_ascii=True)
            elif name == "LoadInt":
                accumulator = str(args["value"])
        elif name == "LoadConst":
            accumulator = literal(refs["index"])
        elif name == "MoveConst":
            registers[args["destTemp"]] = literal(refs["constIndex"])
        elif name == "StoreReg":
            registers[args["reg"]] = accumulator
        elif name == "LoadReg":
            accumulator = registers.get(args["reg"])
        elif name == "MoveReg":
            registers[args["destReg"]] = registers.get(args["srcReg"])
        elif name in {"GetLookup", "LoadProperty"}:
            prop = refs.get("index", refs.get("name"))
            accumulator = f"{accumulator}.{prop}" if accumulator is not None else None
        elif name == "LoadElement":
            base = registers.get(args["base"])
            accumulator = f"{base}[{accumulator}]" if base is not None and accumulator is not None else None
        elif name in binary_ops:
            left = registers.get(args["lhs"])
            accumulator = f"({left} {binary_ops[name]} {accumulator})" if left is not None and accumulator is not None else None
        elif name in {"CmpEqInt", "CmpNeInt"}:
            op = "==" if name == "CmpEqInt" else "!="
            accumulator = f"({args['lhs']} {op} {accumulator})" if accumulator is not None else None
        elif name in {"UNot", "UMinus", "UPlus", "UCompl"}:
            op = {"UNot": "!", "UMinus": "-", "UPlus": "+", "UCompl": "~"}[name]
            accumulator = f"({op}{accumulator})" if accumulator is not None else None
        elif name in {"CallQmlContextPropertyLookup", "CallGlobalLookup", "CallPropertyLookup", "CallName", "CallProperty"}:
            argv = [registers.get(args["argv"] + index) for index in range(args["argc"])]
            if any(value is None for value in argv):
                return None
            callee = refs.get("index", refs.get("lookupIndex", refs.get("name")))
            if "base" in args:
                base = registers.get(args["base"])
                if base is None:
                    return None
                callee = f"{base}.{callee}"
            expression = f"{callee}({', '.join(argv)})"
            accumulator = f"__qml_call_{len(calls)}__"
            calls.append((accumulator, expression))
        elif name == "DefineArray":
            values = [registers.get(args["args"] + index) for index in range(args["argc"])]
            accumulator = "[" + ", ".join(values) + "]" if all(value is not None for value in values) else None
        elif name == "Ret":
            for token, expression in reversed(calls):
                if accumulator is None or accumulator.count(token) != 1:
                    return None
                accumulator = accumulator.replace(token, expression)
            return accumulator
        else:
            return None
    return None


class Decoder:
    def __init__(self, data, base, schema):
        self.base = base
        self.data = data
        self.schema = schema
        self.size = len(data)
        self.strings = []
        self.tables = {}
        self.functions = []

    def span(self, offset, count, stride=1, lower=0, upper=None):
        upper = self.size if upper is None else upper
        require(lower <= offset <= upper and 0 <= count and stride > 0 and count * stride <= upper - offset,
                f"span outside cache: offset={offset:#x} count={count} stride={stride} limit={upper:#x}")
        return offset

    def unpack(self, fmt, offset):
        self.span(offset, struct.calcsize("<" + fmt))
        return struct.unpack_from("<" + fmt, self.data, offset)

    def u32(self, offset):
        return self.unpack("I", offset)[0]

    def string(self, index):
        require(0 <= index < len(self.strings), f"invalid string index {index}")
        return self.strings[index]

    def indexed(self, name, index):
        count, offset = self.tables[name]
        require(0 <= index < count, f"invalid {name} index {index}")
        return self.u32(offset + index * 4)

    def parameter_type(self, value):
        index = value >> 1
        if value & 1:
            require(index < len(BUILTINS), "invalid parameter builtin")
            return BUILTINS[index]
        return self.string(index)

    def parse(self):
        require(self.data[:8] == b"qv4cdata", "invalid magic")
        self.span(0, 248)
        version, qt = self.unpack("II", 8)
        require(version == 0x25 and qt == 0x050e02, "unsupported cache version")
        require(self.u32(24) == self.size, "cache size mismatch")
        flags = self.u32(108)
        require(flags & ~0x3f == 0, "unknown cache flags")
        for index, (name, stride) in enumerate(zip(TABLES, STRIDES)):
            count, offset = self.unpack("II", 112 + index * 8)
            require(offset % (8 if stride == 8 else 4) == 0, "unaligned cache table")
            self.span(offset, count, stride, lower=248)
            self.tables[name] = (count, offset)
        string_records = []
        for index in range(self.tables["string"][0]):
            offset = self.indexed("string", index)
            require(offset % 8 == 0, "unaligned static string")
            ref, length, alloc, offset32, offset64 = self.unpack("iiIIQ", offset)
            require(ref == -1 and length >= 0 and alloc == 0 and offset32 == 24 and offset64 == 24,
                    "invalid static string layout")
            self.span(offset + 24, length + 1, 2)
            raw = self.data[offset + 24:offset + 24 + length * 2]
            require(self.data[offset + 24 + length * 2:offset + 26 + length * 2] == b"\0\0", "missing string terminator")
            value = raw.decode("utf-16-le", errors="strict")
            self.strings.append(value)
            string_records.append({"index": index, "unit_offset": offset, "file_offset": self.base + offset, "value": value})
        source_index, final_index, qml_offset = self.unpack("III", 236)
        constants = []
        count, offset = self.tables["constant"]
        for index in range(count):
            constants.append({"index": index, "unit_offset": offset + index * 8, **number(self.unpack("Q", offset + index * 8)[0])})
        self.constants = constants
        self.lookups = []
        count, offset = self.tables["lookup"]
        for index in range(count):
            packed = self.u32(offset + index * 4)
            require((packed & 0xf) <= 3, "invalid lookup flags")
            self.lookups.append({"index": index, "type": packed & 0xf, "name": self.string(packed >> 4)})
        self.validate_auxiliary_tables()
        for index in range(self.tables["function"][0]):
            self.functions.append(self.function(index))
        imports, objects = self.qml(qml_offset)
        root_function = self.unpack("i", 232)[0]
        require(root_function == -1 or 0 <= root_function < len(self.functions), "invalid root function")
        checksum = self.data[76:92]
        return {
            "source_url": self.string(source_index), "final_url": self.string(final_index),
            "file_offset": self.base, "file_offset_hex": hex(self.base), "unit_size": self.size,
            "format_version": hex(version), "qt_version": "5.14.2", "flags": flags,
            "sha256": hashlib.sha256(self.data).hexdigest(), "source_timestamp": self.unpack("q", 16)[0],
            "library_hash_present": any(self.data[28:76]), "md5_present": any(checksum),
            "dependency_md5_present": any(self.data[92:108]),
            "md5_matches": hashlib.md5(self.data[92:]).digest() == checksum if any(checksum) else None,
            "tables": {key: {"count": value[0], "offset": value[1]} for key, value in self.tables.items()},
            "root_function": root_function, "strings": string_records, "constants": constants,
            "lookups": self.lookups, "imports": imports, "objects": objects, "functions": self.functions,
            "expression_recovery": "Exact bytecode with resolved name references. Original source text remains absent. Simple branch-free expressions are optional inferences.",
        }

    def validate_auxiliary_tables(self):
        count, offset = self.tables["regexp"]
        for index in range(count):
            self.string(self.u32(offset + index * 4) >> 5)
        count, offset = self.tables["translation"]
        for index in range(count):
            string_index, comment, _, _ = self.unpack("IIiI", offset + index * 16)
            self.string(string_index)
            self.string(comment)
        count, offset = self.tables["moduleRequest"]
        for index in range(count):
            self.string(self.u32(offset + index * 4))
        for name in ["localExportEntry", "indirectExportEntry", "starExportEntry", "importEntry"]:
            require(self.tables[name][0] == 0, f"unimplemented nonempty {name} table")
        for name in ["class", "templateObject"]:
            require(self.tables[name][0] == 0, f"unimplemented nonempty {name} table")
        for index in range(self.tables["block"][0]):
            offset = self.indexed("block", index)
            count, local_offset, _, _ = self.unpack("IIHH", offset)
            self.span(offset + local_offset, count, 4)
            for local in range(count):
                self.string(self.u32(offset + local_offset + local * 4))
        for index in range(self.tables["jsClass"][0]):
            offset = self.indexed("jsClass", index)
            count = self.u32(offset)
            self.span(offset + 4, count, 4)
            for member in range(count):
                self.string(self.u32(offset + 4 + member * 4) & 0x7fffffff)

    def bytecode(self, offset, size):
        self.span(offset, size)
        end = offset + size
        cursor = offset
        rows = []
        while cursor < end:
            start = cursor
            opcode = self.data[cursor]
            cursor += 1
            if opcode == 1:
                require(cursor < end, "truncated wide prefix")
                opcode = 0x100 | self.data[cursor]
                cursor += 1
            require(opcode // 2 < len(self.schema), f"unknown opcode {opcode}")
            name, names = self.schema[opcode // 2]
            stride = 4 if opcode & 1 else 1
            self.span(cursor, len(names), stride, upper=end)
            values = self.unpack(("i" if stride == 4 else "b") * len(names), cursor) if names else ()
            cursor += len(names) * stride
            args = dict(zip(names, values))
            row = {"offset": start - offset, "size": cursor - start, "opcode": opcode, "name": name, "args": args}
            refs = {}
            for key, value in args.items():
                if key in {"name", "varName", "property", "stringId"} and name not in {"CallValue", "CallWithReceiver"}:
                    refs[key] = self.string(value)
                if (name in {"LoadGlobalLookup", "LoadQmlContextPropertyLookup", "GetLookup", "SetLookup", "CallGlobalLookup", "CallQmlContextPropertyLookup"} and key == "index") or key == "lookupIndex":
                    require(0 <= value < len(self.lookups), "invalid bytecode lookup index")
                    refs[key] = self.lookups[value]["name"]
                if (name == "LoadConst" and key == "index") or key == "constIndex":
                    require(0 <= value < len(self.constants), "invalid bytecode constant index")
                    refs[key] = self.constants[value]
                if name == "LoadClosure" and key == "value":
                    require(0 <= value < self.tables["function"][0], "invalid closure index")
            if refs:
                row["references"] = refs
            if "offset" in args:
                row["target_offset"] = cursor - offset + args["offset"]
            rows.append(row)
        require(cursor == end, "bytecode end mismatch")
        boundaries = {row["offset"] for row in rows} | {size}
        for row in rows:
            if "target_offset" in row and not (row["name"] == "SetUnwindHandler" and row["args"]["offset"] == 0):
                require(row["target_offset"] in boundaries, "branch destination outside instruction boundaries")
        return rows

    def function(self, index):
        offset = self.indexed("function", index)
        require(offset % 8 == 0, "unaligned function")
        self.span(offset, 56)
        code_offset, code_size, name, length, formals, formal_offset, return_type, locals_offset, locals_count, lines, nested, registers, loc, labels, local_tdz, first_tdz, register_tdz, flags, pad = self.unpack("IIIHHIIIHHIIIIHHHBB", offset)
        self.span(offset + formal_offset, formals, 8)
        self.span(offset + locals_offset, locals_count * 4 + lines * 8 + labels * 4)
        require(nested == 0xffffffff or nested < self.tables["function"][0], "invalid nested function index")
        parameters = []
        for parameter in range(formals):
            pname, ptype = self.unpack("II", offset + formal_offset + parameter * 8)
            parameters.append({"name": self.string(pname), "type": self.parameter_type(ptype)})
        local_names = [self.string(self.u32(offset + locals_offset + local * 4)) for local in range(locals_count)]
        line_table = []
        for line in range(lines):
            code, source_line = self.unpack("II", offset + locals_offset + locals_count * 4 + line * 8)
            require(code <= code_size, "line table outside function code")
            line_table.append({"code_offset": code, "line": source_line})
        bytecode = self.bytecode(offset + code_offset, code_size)
        boundaries = {row["offset"] for row in bytecode} | {code_size}
        require(all(row["code_offset"] in boundaries for row in line_table), "line table points inside bytecode operand")
        result = {"index": index, "name": self.string(name), "unit_offset": offset, "file_offset": self.base + offset,
                "code_unit_offset": offset + code_offset, "code_file_offset": self.base + offset + code_offset,
                "code_size": code_size, "code_sha256": hashlib.sha256(self.data[offset + code_offset:offset + code_offset + code_size]).hexdigest(),
                "length": length, "parameters": parameters, "locals": local_names, "return_type": self.parameter_type(return_type),
                "nested_function_index": nested, "registers": registers, "flags": flags, "location": location(loc),
                "line_table": line_table, "label_count": labels, "bytecode": bytecode}
        expression = infer_expression(result)
        if expression is not None:
            result["inferred_branch_free_expression"] = expression
        return result

    def qml(self, offset):
        import_count, imports_offset, object_count, objects_offset = self.unpack("IIII", offset)
        self.span(offset + imports_offset, import_count, 24)
        self.span(offset + objects_offset, object_count, 4)
        imports = []
        for index in range(import_count):
            kind, uri, qualifier, major, minor, loc = self.unpack("IIIiiI", offset + imports_offset + index * 24)
            require(1 <= kind <= 3, "invalid import type")
            imports.append({"type": kind, "uri": self.string(uri), "qualifier": self.string(qualifier), "major": major, "minor": minor, "location": location(loc)})
        offsets = [offset + self.u32(offset + objects_offset + index * 4) for index in range(object_count)]
        require(offsets == sorted(set(offsets)), "duplicate or unsorted object offsets")
        objects = []
        for index, object_offset in enumerate(offsets):
            upper = offsets[index + 1] if index + 1 < len(offsets) else self.size
            objects.append(self.object(index, object_offset, upper, object_count))
        parents = collections.defaultdict(list)
        for obj in objects:
            for binding in obj["bindings"]:
                if "object_index" in binding:
                    parents[binding["object_index"]].append({"object_index": obj["index"], "property": binding["property"], "binding_type": binding["type"]})
        for obj in objects:
            obj["parents"] = parents[obj["index"]]
        for start in range(object_count):
            stack = [(start, set())]
            while stack:
                node, ancestry = stack.pop()
                require(node not in ancestry, "object graph cycle")
                stack.extend((parent["object_index"], ancestry | {node}) for parent in parents[node])
        return imports, objects

    def object(self, index, offset, upper, object_count):
        self.span(offset, 68, upper=upper)
        inherited, id_name, packed, default_property = self.unpack("IIIi", offset)
        funcs, props = self.unpack("HH", offset + 16)
        func_offset, prop_offset, alias_offset = self.unpack("III", offset + 20)
        aliases, enums = self.unpack("HH", offset + 32)
        enum_offset, signal_offset = self.unpack("II", offset + 36)
        signals, bindings = self.unpack("HH", offset + 44)
        binding_offset, named_count, named_offset, loc, id_loc = self.unpack("IIIII", offset + 48)
        for count, relative, stride in [(funcs, func_offset, 4), (props, prop_offset, 12), (aliases, alias_offset, 20), (enums, enum_offset, 4), (signals, signal_offset, 4), (bindings, binding_offset, 24), (named_count, named_offset, 4)]:
            self.span(offset + relative, count, stride, lower=offset + 68, upper=upper)
        function_indices = [self.u32(offset + func_offset + n * 4) for n in range(funcs)]
        require(all(n < len(self.functions) for n in function_indices), "invalid object function index")
        properties = []
        for n in range(props):
            name, ptype, ploc = self.unpack("III", offset + prop_offset + n * 12)
            raw_type = ptype & 0x1fffffff
            if ptype & (1 << 29):
                require(raw_type < len(BUILTINS), "invalid property builtin")
                type_name = BUILTINS[raw_type]
            else:
                type_name = self.string(raw_type)
            properties.append({"name": self.string(name), "type": type_name, "list": bool(ptype & (1 << 30)), "read_only": bool(ptype & (1 << 31)), "location": location(ploc)})
        alias_rows = []
        for n in range(aliases):
            a, target, prop, aloc, rloc = self.unpack("IIIII", offset + alias_offset + n * 20)
            row = {"name": self.string(a & 0x1fffffff), "flags": a >> 29, "target_raw": target, "property_raw": prop, "location": location(aloc), "reference_location": location(rloc)}
            if not (row["flags"] & 2):
                row.update(target_id=self.string(target), target_property=self.string(prop))
            alias_rows.append(row)
        signal_rows, enum_rows = [], []
        for count, relative, output, enum in [(signals, signal_offset, signal_rows, False), (enums, enum_offset, enum_rows, True)]:
            for n in range(count):
                at = offset + self.u32(offset + relative + n * 4)
                name, entries, sloc = self.unpack("III", at)
                self.span(at + 12, entries, 12 if enum else 8, lower=offset + 68, upper=upper)
                row = {"name": self.string(name), "location": location(sloc)}
                values = []
                for j in range(entries):
                    if enum:
                        ename, value, eloc = self.unpack("IiI", at + 12 + j * 12)
                        values.append({"name": self.string(ename), "value": value, "location": location(eloc)})
                    else:
                        pname, ptype = self.unpack("II", at + 12 + j * 8)
                        values.append({"name": self.string(pname), "type": self.parameter_type(ptype)})
                row["values" if enum else "parameters"] = values
                output.append(row)
        binding_rows = []
        for n in range(bindings):
            at = offset + binding_offset + n * 24
            pname, tag, value, string_index, bloc, vloc = self.unpack("IIIIII", at)
            kind = tag >> 16
            require(kind < len(BIND_TYPES), "unknown binding tag")
            row = {"index": n, "property": self.string(pname), "type": BIND_TYPES[kind], "flags": tag & 0xffff,
                   "unit_offset": at, "file_offset": self.base + at, "location": location(bloc), "value_location": location(vloc)}
            if kind == 1:
                require(value in (0, 1), "invalid Boolean binding")
                row["value"] = bool(value)
            elif kind == 2:
                require(value < len(self.constants), "invalid Number binding index")
                row["constant_index"] = value
                row["value"] = self.constants[value]
            elif kind in (3, 7):
                row["string_index"] = string_index
                row["string"] = self.string(string_index)
                if kind == 7:
                    require(value < len(self.functions), "invalid script function index")
                    row["function_index"] = value
            elif kind in (8, 9, 10):
                require(value < object_count, "invalid object binding index")
                row["object_index"] = value
            elif kind in (5, 6):
                require(value < self.tables["translation"][0], "invalid translation binding index")
                row["translation_index"] = value
            binding_rows.append(row)
        named = [self.u32(offset + named_offset + n * 4) for n in range(named_count)]
        require(all(n < object_count for n in named), "invalid named object index")
        return {"index": index, "unit_offset": offset, "file_offset": self.base + offset, "type": self.string(inherited),
                "id": self.string(id_name), "flags": packed & 0x7fff, "numeric_id": struct.unpack("<h", struct.pack("<H", packed >> 16))[0],
                "default_property_is_alias": bool(packed & 0x8000), "default_property_index": default_property,
                "location": location(loc), "id_location": location(id_loc), "functions": function_indices, "properties": properties,
                "aliases": alias_rows, "signals": signal_rows, "enums": enum_rows, "bindings": binding_rows, "named_objects": named}


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")


def cache_registry(binary):
    """Resolve constructor QString/cache pairs with a bounded AArch64 data-flow pass."""
    machine = capstone.Cs(capstone.CS_ARCH_ARM64, capstone.CS_MODE_ARM)
    machine.detail = True
    registers = {"x29": 0x10000000000000, "sp": 0x10000000000060}
    memory = {}
    pairs = []
    sections = json.loads((BASE / "launcher-static.json").read_text(encoding="utf-8"))["sections"]

    def file_offset(address):
        for section in sections:
            start = int(section["address"], 16)
            if start <= address < start + section["size"] and section["name"] != ".bss":
                return section["file_offset"] + address - start
        raise ValueError(f"registry pointer outside ELF sections: {address:#x}")

    def regname(operand):
        return machine.reg_name(operand.reg).replace("w", "x", 1)

    def value(operand):
        if operand.type == capstone.arm64.ARM64_OP_IMM:
            return operand.imm
        if operand.type == capstone.arm64.ARM64_OP_REG:
            return registers.get(regname(operand))
        return None

    def address(operand):
        base = registers.get(machine.reg_name(operand.mem.base))
        return None if base is None else base + operand.mem.disp

    for ins in machine.disasm(binary[0x2c90:0x6554], 0x402c90):
        operands = ins.operands
        if ins.mnemonic == "adrp":
            registers[regname(operands[0])] = operands[1].imm
        elif ins.mnemonic in {"add", "sub"} and len(operands) == 3:
            left, right = value(operands[1]), value(operands[2])
            registers[regname(operands[0])] = None if left is None or right is None else left + (right if ins.mnemonic == "add" else -right)
        elif ins.mnemonic == "mov":
            registers[regname(operands[0])] = value(operands[1])
        elif ins.mnemonic in {"str", "stp"}:
            at = address(operands[-1])
            if at is not None:
                width = 8 if ins.reg_name(operands[0].reg).startswith("x") else 4
                for index, operand in enumerate(operands[:-1]):
                    memory[at + index * width] = value(operand)
                if ins.writeback:
                    registers[ins.reg_name(operands[-1].mem.base)] = at
        elif ins.mnemonic in {"ldr", "ldp", "ldaxr"}:
            for operand in operands[:-1]:
                registers[regname(operand)] = None
        elif ins.mnemonic == "bl":
            if operands[0].imm == 0x4083c0:
                cache_address = memory.get(0x10000000000048)
                string_address = memory.get(0x10000000000050)
                require(cache_address is not None and string_address is not None, "unresolved registry pair")
                cache_offset, string_offset = file_offset(cache_address), file_offset(string_address)
                data_address, unused1, unused2 = struct.unpack_from("<QQQ", binary, cache_offset)
                require(unused1 == unused2 == 0, "unexpected cached-unit auxiliary pointers")
                ref, length, alloc, delta32, delta64 = struct.unpack_from("<iiIIQ", binary, string_offset)
                require(ref == -1 and length > 0 and alloc == 0 and delta64 == 24, "invalid registry QString")
                path = binary[string_offset + 24:string_offset + 24 + length * 2].decode("utf-16-le", errors="strict")
                require(path.startswith("/") and path.endswith((".qml", ".js")), "invalid registry resource path")
                unit_offset = file_offset(data_address)
                require(binary[unit_offset:unit_offset + 8] == b"qv4cdata", "registry points outside cache")
                pairs.append({"qrc_path": path[1:], "insert_call_va": hex(ins.address), "cache_struct_va": hex(cache_address),
                              "path_qstring_va": hex(string_address), "unit_file_offset": unit_offset, "unused1": None, "unused2": None})
            for index in range(19):
                registers[f"x{index}"] = None
    require(len(pairs) == 198, "registry pair count mismatch")
    require(len({pair["qrc_path"] for pair in pairs}) == 198 and len({pair["unit_file_offset"] for pair in pairs}) == 198,
            "duplicate registry mapping")
    return pairs


def negative_cases(binary, starts, schema, units):
    """Exercise predefined failure cases on copied cache data."""
    original = next(unit for unit in units if unit["qrc_path"] == "main.qml")
    start, size = original["file_offset"], original["unit_size"]
    sample = binary[start:start + size]
    cases = []

    def reject(name, mutate):
        damaged = bytearray(sample)
        mutate(damaged)
        try:
            Decoder(bytes(damaged), start, schema).parse()
        except (ValueError, struct.error, UnicodeError) as error:
            cases.append({"case": name, "result": "rejected", "reason": str(error)})
        else:
            raise ValueError(f"negative case accepted: {name}")

    def replace(offset, fmt, value):
        return lambda data: struct.pack_into("<" + fmt, data, offset, value)

    reject("bad_magic", replace(0, "B", 0))
    reject("unsupported_format", replace(8, "I", 0x26))
    reject("wrong_qt_version", replace(12, "I", 0x050f00))
    reject("wrong_unit_size", replace(24, "I", size + 1))
    reject("truncated_header", lambda data: data.__delitem__(slice(128, None)))
    reject("table_count_overflow", replace(112, "I", 0xffffffff))
    reject("table_offset_outside_unit", replace(116, "I", size + 1))
    text = next(row for row in original["strings"] if row["value"])
    reject("bad_static_string_layout", replace(text["unit_offset"] + 16, "Q", 20))
    reject("string_payload_outside_unit", replace(text["unit_offset"] + 4, "i", size))
    reject("missing_string_terminator", replace(text["unit_offset"] + 24 + len(text["value"].encode("utf-16-le")), "H", 1))
    reject("invalid_utf16", replace(text["unit_offset"] + 24, "H", 0xd800))
    function = original["functions"][0]
    reject("function_code_outside_unit", replace(function["unit_offset"] + 4, "I", size))
    reject("unknown_opcode", lambda data: data.__setitem__(slice(function["code_unit_offset"], function["code_unit_offset"] + 2), b"\x01\xff"))
    script = next(binding for obj in original["objects"] for binding in obj["bindings"] if binding["type"] == "Script")
    reject("binding_tag_unknown", replace(script["unit_offset"] + 4, "I", 0xffff0000))
    reject("binding_function_index_outside_table", replace(script["unit_offset"] + 8, "I", len(original["functions"])))
    reject("binding_string_index_outside_table", replace(script["unit_offset"] + 12, "I", len(original["strings"])))
    numeric = next(binding for obj in original["objects"] for binding in obj["bindings"] if binding["type"] == "Number")
    reject("binding_constant_index_outside_table", replace(numeric["unit_offset"] + 8, "I", len(original["constants"])))
    child = next(binding for obj in original["objects"] for binding in obj["bindings"] if binding["type"] == "Object")
    reject("binding_object_index_outside_table", replace(child["unit_offset"] + 8, "I", len(original["objects"])))
    reject("binding_object_cycle", replace(child["unit_offset"] + 8, "I", 0))
    for func in original["functions"]:
        branch = next((row for row in func["bytecode"] if row["name"] == "JumpFalse"), None)
        if branch:
            boundaries = {row["offset"] for row in func["bytecode"]} | {func["code_size"]}
            delta = next(value for value in range(1, 127) if branch["offset"] + branch["size"] + value not in boundaries)
            reject("branch_destination_inside_operand", replace(func["code_unit_offset"] + branch["offset"] + 1, "b", delta))
            break
    damaged_source = bytearray(binary)
    damaged_source[0] ^= 1
    try:
        verify_identity(damaged_source)
    except ValueError as error:
        cases.append({"case": "source_identity", "result": "rejected", "reason": str(error)})
    else:
        raise ValueError("source identity negative case accepted")
    return cases


def focus_index(units, summary):
    priorities = {"main.qml", "functions.js", "common/Global.qml", "common/VehicleEvent.qml", "Trucks/Dashboard.qml",
                  "Trucks/menu/system/MenuSystemFactory.qml", "Trucks/common/AccLimitedIndicator.qml"}
    priorities.update(f"Trucks/ui{index}/Dashboard.qml" for index in range(1, 7))
    result = []
    by_path = {row["qrc_path"]: row for row in summary}
    for unit in units:
        if unit["qrc_path"] not in priorities:
            continue
        objects = []
        for obj in unit["objects"]:
            bindings = []
            for binding in obj["bindings"]:
                row = {key: binding[key] for key in ["property", "type", "file_offset", "location"]}
                if "function_index" in binding:
                    function = unit["functions"][binding["function_index"]]
                    row.update(function_index=function["index"], code_file_offset=function["code_file_offset"], code_size=function["code_size"])
                    if "inferred_branch_free_expression" in function:
                        row["inferred_branch_free_expression"] = function["inferred_branch_free_expression"]
                else:
                    for key in ["object_index", "value", "string"]:
                        if key in binding:
                            row[key] = binding[key]
                bindings.append(row)
            objects.append({"index": obj["index"], "type": obj["type"], "id": obj["id"], "location": obj["location"],
                            "properties": obj["properties"], "parents": obj["parents"], "bindings": bindings})
        result.append({"qrc_path": unit["qrc_path"], "artifact": by_path[unit["qrc_path"]]["artifact"], "file_offset": unit["file_offset"],
                       "imports": unit["imports"], "objects": objects,
                       "functions": [{key: func[key] for key in ["index", "name", "location", "code_file_offset", "code_size"]} for func in unit["functions"]]})
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=BASE / "extracted/latest/dashboard/usr/bin/Launcher")
    parser.add_argument("--output", type=Path, default=BASE / "analysis/capture-04/qml-cache")
    args = parser.parse_args()
    original = args.source.read_bytes()
    verify_identity(original)
    args.output.mkdir(parents=True, exist_ok=True)
    schema = opcode_schema(args.output / "qv4instr_moth_p.h")
    registry = cache_registry(original)
    write_json(args.output / "registry.json", registry)
    path_by_offset = {row["unit_file_offset"]: row["qrc_path"] for row in registry}
    inventory = json.loads((BASE / "launcher-cache-resource-inventory.json").read_text(encoding="utf-8"))
    expected = {row["path"] for row in inventory["files"]}
    require(len(expected) == len(inventory["files"]) and all(row["stored_size"] == 0 for row in inventory["files"]), "invalid placeholder inventory")
    starts = [m.start() for m in re.finditer(b"qv4cdata", original)]
    require(len(starts) == 198, "unexpected header count")
    summary, errors, units = [], [], []
    for n, start in enumerate(starts):
        try:
            size = struct.unpack_from("<I", original, start + 24)[0]
            require(size >= 248 and start + size <= len(original), "invalid cache span")
            require(n + 1 == len(starts) or start + size <= starts[n + 1], "overlapping cache spans")
            unit = Decoder(original[start:start + size], start, schema).parse()
            source = unit["source_url"]
            path = path_by_offset[start]
            unit["qrc_path"] = path
            unit["qrc_placeholder_match"] = path in expected
            name = f"{n:03d}-" + re.sub(r"[^A-Za-z0-9_.-]", "_", path) + ".json"
            write_json(args.output / name, unit)
            summary.append({key: unit[key] for key in ["source_url", "final_url", "qrc_path", "qrc_placeholder_match", "file_offset", "file_offset_hex", "unit_size", "sha256", "flags", "md5_present", "md5_matches"]} | {
                "artifact": name, "strings": len(unit["strings"]), "imports": len(unit["imports"]), "objects": len(unit["objects"]),
                "bindings": sum(len(o["bindings"]) for o in unit["objects"]), "functions": len(unit["functions"]),
                "bytecode_bytes": sum(f["code_size"] for f in unit["functions"]),
                "instructions": sum(len(f["bytecode"]) for f in unit["functions"]),
                "branch_free_expressions": sum("inferred_branch_free_expression" in f for f in unit["functions"]),
                "script_bindings_with_text": sum(bool(b.get("string")) for o in unit["objects"] for b in o["bindings"] if b["type"] == "Script")})
            units.append(unit)
        except (ValueError, struct.error, UnicodeError) as error:
            errors.append({"file_offset": start, "error": str(error)})
    matched = {u["qrc_path"] for u in units if u["qrc_placeholder_match"]}
    result = {"source": str(args.source), "source_sha256": SHA256, "decoder": str(Path(__file__).resolve()),
              "format_source": "https://raw.githubusercontent.com/qt/qtdeclarative/v5.14.2/src/qml/common/qv4compileddata_p.h",
              "opcode_source": "https://raw.githubusercontent.com/qt/qtdeclarative/v5.14.2/src/qml/compiler/qv4instr_moth_p.h",
              "header_count": len(starts), "decoded_count": len(units), "expected_qrc_count": len(expected), "matched_qrc_count": len(matched),
              "missing_qrc_paths": sorted(expected - matched), "errors": errors, "units": summary,
              "totals": {key: sum(u[key] for u in summary) for key in ["strings", "imports", "objects", "bindings", "functions", "bytecode_bytes", "instructions", "branch_free_expressions", "script_bindings_with_text"]},
              "limitations": ["Original QML formatting, comments, and original expression text are absent unless a script binding explicitly retains text.",
                              "Bytecode names and references describe static data. No target execution occurred.",
                              "Native C++ plugin code remains outside the QML cache decoder.",
                              "Cache changes require matching Qt format, offsets, code operands, loader registration, and any active integrity rules. No edit was attempted."]}
    result["declarations"] = {key: sum(len(obj[key]) for unit in units for obj in unit["objects"]) for key in ["properties", "aliases", "signals", "enums"]}
    result["binding_types"] = dict(collections.Counter(binding["type"] for unit in units for obj in unit["objects"] for binding in obj["bindings"]))
    result["constant_kinds"] = dict(collections.Counter(constant["kind"] for unit in units for constant in unit["constants"]))
    result["unknowns"] = {"rejected_units": len(errors), "original_source_text_available": False,
                          "unsupported_control_flow_functions": sum("inferred_branch_free_expression" not in func for unit in units for func in unit["functions"]),
                          "native_plugin_implementation_decoded": False, "runtime_acceptance_of_cache_changes_tested": False}
    write_json(args.output / "index.json", result)
    if not errors and len(units) == 198:
        checks = negative_cases(original, starts, schema, units)
        write_json(args.output / "verification.json", {"source_sha256_before": SHA256, "source_sha256_after": hashlib.sha256(args.source.read_bytes()).hexdigest(),
                                                     "command": f'py -3.12 "{Path(__file__).resolve()}" --source "{args.source}" --output "{args.output}"',
                                                     "real_binary_status": "198 cache units decoded; 198 qrc paths matched; every function span decoded exactly",
                                                     "negative_cases": checks, "negative_case_count": len(checks),
                                                     "expression_status": "Branch-free expressions are inferred from supported opcodes; complex control flow remains bytecode.",
                                                     "target_execution": False, "binary_modification": False})
        write_json(args.output / "focus.json", focus_index(units, summary))
        write_json(args.output / "feasibility.json", {
            "observed": {"cache_units": len(units), "registry_pairs": len(registry), "native_function_tables": "Qt 5.14.2 defines both auxiliary fields as unused; all values are null.",
                         "source_text": "No original script binding text or source URL survives in the decoded cache fields.",
                         "header_checksums": {key: sum(bool(unit[key]) for unit in units) for key in ["library_hash_present", "md5_present", "dependency_md5_present"]},
                         "source_timestamps_nonzero": sum(unit["source_timestamp"] != 0 for unit in units),
                         "qml_flags": dict(collections.Counter(unit["flags"] for unit in units))},
            "inferred": {"same_size_edits": "Primitive opcode operands and numeric constants can change without moving cache structures. Loader acceptance requires a separate target test.",
                         "whole_unit_replacement": "A replacement needs compatible Qt cache data, valid relative offsets, registry pointers, and the target library hash.",
                         "source_reconstruction": "Object metadata plus bytecode supports semantic reconstruction. Original comments, formatting, and source expressions cannot be reproduced exactly."},
            "primary_source_anchors": ["qqmlprivate.h:302 CachedQmlUnit layout", "generateloader.cpp:357 generated cache initializer",
                                       "qqmlmetatype.cpp:1339 cache hook and header verification", "qv4executablecompilationunit.cpp:835 header checks",
                                       "qqmltypedata.cpp:457 embedded cache to IR", "qqmltypedata.cpp:321 dependency checks for compiled disk cache"],
            "limits": ["No target execution or binary edit occurred.", "Vendor changes to the installed Qt loader were not checked.",
                       "No full JavaScript control-flow decompiler was built.", "Native C++ plugin source remains unrecovered."]})
    require(hashlib.sha256(args.source.read_bytes()).hexdigest() == SHA256, "source changed during analysis")
    print(json.dumps({key: result[key] for key in ["header_count", "decoded_count", "expected_qrc_count", "matched_qrc_count", "totals"]}))
    if errors:
        print(json.dumps({"errors": errors[:10]}))
    require(not errors and len(units) == 198 and len(matched) == len(expected), "incomplete cache coverage")


if __name__ == "__main__":
    main()
