from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import re
import shutil
import struct
import sys
import tempfile
from pathlib import Path


BASE = Path(__file__).resolve().parents[1]
DECODER_PATH = BASE / "tools" / "decode_qml_units.py"
SOURCE_DEFAULT = BASE / "installed" / "capture-04" / "rootfs" / "usr" / "bin" / "Launcher"
ANALYSIS_ROOT = (BASE / "analysis").resolve()
SCHEMA_PATH = BASE / "evidence" / "qt-5.14.2" / "qv4instr_moth_p.h"
LAYOUT_PATH = BASE / "evidence" / "fixtures" / "capture-04" / "launcher-layout.json"
GATE_FIXTURE = BASE / "evidence/fixtures/capture-04/factory-code-records.json"
PATCHES = (
    {
        "unit_qrc_path": "main.qml",
        "old_string": "qrc:/common/VehicleEvent.qml",
        "new_string": "file:/etc/vnV.qml",
        "record_file_offset": 46800,
        "destination": "etc/vnV.qml",
        "source_path": BASE / "patches" / "capture-04" / "etc" / "common" / "VehicleEvent.qml",
    },
    {
        "unit_qrc_path": "main.qml",
        "old_string": "qrc:/common/Global.qml",
        "new_string": "file:/etc/vnG.qml",
        "record_file_offset": 47184,
        "destination": "etc/vnG.qml",
        "source_path": BASE / "patches" / "capture-04" / "etc" / "common" / "Global.qml",
    },
    {
        # MenuPage (cache 024) Loader mMenuListId. The owned menu vnM replaces the compiled list and every page under the list.
        "unit_qrc_path": "Trucks/menu/MenuPage.qml",
        "old_string": "qrc:/Trucks/menu/MenuItemsList.qml",
        "new_string": "file:/etc/vnM.qml",
        "record_file_offset": 4002512,
        "destination": "etc/vnM.qml",
        "source_path": BASE / "patches" / "capture-04" / "etc" / "vnM.qml",
    },
    {
        # main.qml mDashboard: Ford trucks (mTrucksModel 0 and 1) both read this one record.
        # The owned dashboard shell vnD replaces the compiled Trucks/Dashboard.qml.
        "unit_qrc_path": "main.qml",
        "old_string": "qrc:/Trucks/Dashboard.qml",
        "new_string": "file:/etc/vnD.qml",
        "record_file_offset": 48136,
        "destination": "etc/vnD.qml",
        "source_path": BASE / "patches" / "capture-04" / "etc" / "vnD.qml",
    },
    {
        # Translation (cache 012) fn 392, the mNotifyId Loader source: mGlobalId.item.mRccPrefix + this string.
        # On Linux, Global sets mRccPrefix to "file:///etc/", so the stock URL is file:///etc//common/NotifyTranslation.qml.
        # The fixed notification text table vnN replaces that file; the replacement string has no leading slash.
        "unit_qrc_path": "common/Translation.qml",
        "old_string": "/common/NotifyTranslation.qml",
        "new_string": "vnN.qml",
        "url_prefix": "file:///etc/",
        "record_file_offset": 1487208,
        "destination": "etc/vnN.qml",
        "source_path": BASE / "patches" / "capture-04" / "etc" / "vnN.qml",
    },
)
SOURCE_FILES = {item["destination"]: item["source_path"] for item in PATCHES}
# Global loads the Factory screen grid vnS by file URL.
SOURCE_FILES["etc/vnS.qml"] = BASE / "patches/capture-04/etc/vnS.qml"
# vnD loads the dashboard layouts vnL (Daily A and Towing A) by file URL.
SOURCE_FILES["etc/vnL.qml"] = BASE / "patches/capture-04/etc/vnL.qml"
ELF_HEADER = struct.Struct("<16sHHIQQQIHHHHHH")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_decoder():
    spec = importlib.util.spec_from_file_location("decode_qml_units", DECODER_PATH)
    require(spec is not None and spec.loader is not None, "decoder module load failed")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    write_bytecode = sys.dont_write_bytecode
    sys.dont_write_bytecode = True
    try:
        spec.loader.exec_module(module)
    finally:
        sys.dont_write_bytecode = write_bytecode
    return module


def output_path(value: Path) -> Path:
    require(".." not in value.parts, "output path traversal is not allowed")
    requested = value if value.is_absolute() else BASE / value
    resolved = requested.resolve(strict=False)
    require(resolved != ANALYSIS_ROOT and resolved.is_relative_to(ANALYSIS_ROOT), "output path must stay under project analysis")
    require(resolved.parent.is_dir(), "output parent directory must already exist")
    require(not os.path.lexists(requested) and not os.path.lexists(resolved), "output path already exists")
    return resolved


def decode_binary(decoder, binary: bytes, schema):
    starts = [match.start() for match in re.finditer(b"qv4cdata", binary)]
    require(len(starts) == 198, f"expected 198 cache units, found {len(starts)}")
    registry = decoder.cache_registry(binary)
    require(len(registry) == 198, f"expected 198 registry entries, found {len(registry)}")
    path_by_offset = {row["unit_file_offset"]: row["qrc_path"] for row in registry}
    require(len(path_by_offset) == 198, "registry offsets are not unique")
    units = {}
    spans = {}
    for index, start in enumerate(starts):
        require(start in path_by_offset, f"cache unit {index} has no registry entry")
        size = struct.unpack_from("<I", binary, start + 24)[0]
        require(size >= 248 and start + size <= len(binary), f"cache unit {index} has invalid span")
        require(index + 1 == len(starts) or start + size <= starts[index + 1], f"cache unit {index} overlaps the next unit")
        unit = decoder.Decoder(binary[start:start + size], start, schema).parse()
        path = path_by_offset[start]
        unit["qrc_path"] = path
        require(path not in units, f"duplicate qrc path: {path}")
        units[path] = unit
        spans[path] = (start, size)
    require(len(units) == 198, "decoder did not parse all registry entries")
    return units, spans, registry


def require_hash_fields_zero(unit: dict[str, object], unit_bytes: bytes) -> None:
    path = unit["qrc_path"]
    require(unit["library_hash_present"] is False, f"cache library hash is not zero: {path}")
    require(unit["md5_present"] is False, f"cache MD5 field is not zero: {path}")
    require(unit["dependency_md5_present"] is False, f"cache dependency hash is not zero: {path}")
    require(unit_bytes[28:108] == b"\0" * 80, f"cache hash byte ranges are not zero: {path}")


def patch_strings(binary: bytes, units: dict[str, dict[str, object]]) -> tuple[bytes, list[dict[str, object]], set[int]]:
    candidate = bytearray(binary)
    patch_rows = []
    permitted_offsets: set[int] = set()
    seen_records = set()
    for item in PATCHES:
        unit_path = item["unit_qrc_path"]
        unit = units.get(unit_path)
        require(unit is not None, f"cache unit missing: {unit_path}")
        old_string = item["old_string"]
        new_string = item["new_string"]
        record = item["record_file_offset"]
        matches = [row for row in unit["strings"] if row["file_offset"] == record]
        require(len(matches) == 1 and matches[0]["value"] == old_string, f"unexpected decoded loader at {record}")
        row = matches[0]
        # A row with url_prefix holds the part of the URL after a runtime prefix (Global mRccPrefix).
        prefix = item.get("url_prefix", "")
        require(old_string.endswith(".qml") and (prefix + old_string).startswith(("qrc:/", "file:///etc/")),
                f"loader URI is unexpected at {record}")
        require(prefix + new_string in ("file:/" + item["destination"], "file:///" + item["destination"]),
                f"redirect URL does not name the destination: {prefix + new_string}")
        require(len([value for value in unit["strings"] if value["value"] == old_string]) == 1, f"loader URI is not unique in {unit_path}")
        require(record not in seen_records, f"duplicate loader record: {record}")
        seen_records.add(record)
        ref, old_length, alloc, offset32, offset64 = struct.unpack_from("<iiIIQ", binary, record)
        require((ref, old_length, alloc, offset32, offset64) == (-1, len(old_string), 0, 24, 24), f"unexpected string record: {old_string}")
        old_payload_capacity = (old_length + 1) * 2
        payload_start = record + 24
        old_payload = binary[payload_start:payload_start + old_payload_capacity]
        require(len(old_payload) == old_payload_capacity, f"truncated string allocation: {old_string}")
        require(old_payload == old_string.encode("utf-16-le") + b"\0\0", f"unexpected string allocation: {old_string}")
        new_payload = new_string.encode("utf-16-le")
        require(len(new_string) <= old_length, f"replacement does not fit existing allocation: {new_string}")
        allocation = bytearray(old_payload_capacity)
        allocation[:len(new_payload)] = new_payload
        candidate[record + 4:record + 8] = struct.pack("<i", len(new_string))
        candidate[payload_start:payload_start + old_payload_capacity] = allocation
        permitted_offsets.update(range(record + 4, record + 8))
        permitted_offsets.update(range(payload_start, payload_start + old_payload_capacity))
        patch_rows.append(
            {
                "unit_qrc_path": unit_path,
                "old_string": old_string,
                "new_string": new_string,
                "record_file_offset": record,
                "old_length": old_length,
                "new_length": len(new_string),
                "length_field_range": {"start": record + 4, "size": 4},
                "payload_range": {"start": payload_start, "size": old_payload_capacity},
                "payload_capacity_utf16_code_units": old_length + 1,
            }
        )
    changed = {index for index, (left, right) in enumerate(zip(binary, candidate)) if left != right}
    require(changed and changed <= permitted_offsets, "binary changes escaped the permitted string records")
    return bytes(candidate), patch_rows, permitted_offsets


def clear_factory_codes(binary, units, fixture):
    unit = units[fixture["unit_qrc_path"]]
    require(unit["sha256"] == fixture["compiled_unit_sha256"], "factory gate unit identity mismatch")
    function = unit["functions"][fixture["dispatcher_function_index"]]
    require(function["name"] == "key_enter_hold" and function["code_sha256"] == fixture["dispatcher_code_sha256"],
            "factory dispatcher identity mismatch")
    records = fixture["code_records"]
    indices = {row["index"] for row in records}
    require(len(records) == 13 and indices == set(range(104, 117)), "factory code-record set mismatch")
    uses = [(fn["index"], op["args"]["stringId"]) for fn in unit["functions"] for op in fn["bytecode"]
            if op.get("args", {}).get("stringId") in indices]
    require(sorted(uses) == [(function["index"], index) for index in sorted(indices)],
            "factory code strings have unexpected consumers")
    candidate = bytearray(binary)
    permitted = set()
    rows = []
    for record in records:
        decoded = unit["strings"][record["index"]]
        offset = record["file_offset"]
        value = decoded["value"]
        require(decoded["file_offset"] == offset and re.fullmatch(r"[0-9]{4}", value) is not None,
                "factory code record identity mismatch")
        require(struct.unpack_from("<iiIIQ", binary, offset) == (-1, 4, 0, 24, 24), "factory code allocation mismatch")
        require(binary[offset+24:offset+34] == value.encode("utf-16-le") + b"\0\0", "factory code payload mismatch")
        candidate[offset+4:offset+8] = bytes(4)
        candidate[offset+24:offset+34] = bytes(10)
        permitted.update(range(offset+4, offset+8))
        permitted.update(range(offset+24, offset+34))
        rows.append({"string_index":record["index"], "record_file_offset":offset,
                     "length_field_range":{"start":offset+4,"size":4}, "payload_range":{"start":offset+24,"size":10}})
    return bytes(candidate), rows, permitted


def verify_elf_geometry(source: bytes, candidate: bytes, layout: dict[str, object], changed: set[int]) -> dict[str, bool]:
    require(len(source) == len(candidate), "Launcher size changed")
    require(source[:4] == b"\x7fELF", "source is not ELF")
    before = ELF_HEADER.unpack_from(source)
    after = ELF_HEADER.unpack_from(candidate)
    require(before == after, "ELF header changed")
    _, _, machine, _, _, phoff, shoff, _, ehsize, phentsize, phnum, shentsize, shnum, _ = before
    require(machine == 183, "source ELF machine is not AArch64")
    require(ehsize >= ELF_HEADER.size, "ELF header size is invalid")
    ph_end = phoff + phentsize * phnum
    sh_end = shoff + shentsize * shnum
    require(ph_end <= len(source) and sh_end <= len(source), "ELF table geometry is invalid")
    require(source[:ehsize] == candidate[:ehsize], "ELF header bytes changed")
    require(source[phoff:ph_end] == candidate[phoff:ph_end], "ELF program headers changed")
    require(source[shoff:sh_end] == candidate[shoff:sh_end], "ELF section headers changed")
    sections = layout["sections"]
    text_sections = [section for section in sections if section["name"] == ".text"]
    rodata_sections = [section for section in sections if section["name"] == ".rodata"]
    require(len(text_sections) == 1 and len(rodata_sections) == 1, "ELF section map is unexpected")
    text = text_sections[0]
    text_start = text["file_offset"]
    text_end = text_start + text["size"]
    require(source[text_start:text_end] == candidate[text_start:text_end], "native .text bytes changed")
    require(not any(text_start <= offset < text_end for offset in changed), "patch changed native .text")
    rodata = rodata_sections[0]
    rodata_start = rodata["file_offset"]
    rodata_end = rodata_start + rodata["size"]
    require(changed and all(rodata_start <= offset < rodata_end for offset in changed), "patch escaped ELF .rodata")
    return {
        "elf_header_unchanged": True,
        "elf_program_headers_unchanged": True,
        "elf_section_headers_unchanged": True,
        "native_text_unchanged": True,
    }


def build_candidate(source: Path, output: Path) -> dict[str, object]:
    decoder = load_decoder()
    source_bytes = source.read_bytes()
    decoder.verify_identity(source_bytes)
    require(sha256(source_bytes) == decoder.SHA256, "source SHA-256 differs from decoder baseline")
    schema = decoder.opcode_schema(SCHEMA_PATH)
    before_units, before_spans, before_registry = decode_binary(decoder, source_bytes, schema)
    gate = json.loads(GATE_FIXTURE.read_text(encoding="utf-8"))
    modified_units = {item["unit_qrc_path"] for item in PATCHES} | {gate["unit_qrc_path"]}
    require(modified_units == {"main.qml", "Trucks/menu/MenuPage.qml", "Trucks/menu/system/MenuSystemFactory.qml",
                               "common/Translation.qml"},
            "unexpected affected cache unit set")
    for path in modified_units:
        require(path in before_units, f"affected cache unit missing: {path}")
        start, size = before_spans[path]
        require_hash_fields_zero(before_units[path], source_bytes[start:start + size])

    candidate_bytes, patch_rows, permitted_offsets = patch_strings(source_bytes, before_units)
    candidate_bytes, code_rows, code_offsets = clear_factory_codes(candidate_bytes, before_units, gate)
    permitted_offsets.update(code_offsets)
    after_units, after_spans, after_registry = decode_binary(decoder, candidate_bytes, schema)
    require(before_registry == after_registry, "cache registry changed")
    require(before_spans == after_spans, "cache unit geometry changed")
    require(set(before_units) == set(after_units), "decoded qrc unit set changed")
    changed_units = set()
    for path, (start, size) in before_spans.items():
        if source_bytes[start:start + size] != candidate_bytes[start:start + size]:
            changed_units.add(path)
        if path not in modified_units:
            require(source_bytes[start:start + size] == candidate_bytes[start:start + size], f"non-main unit changed: {path}")
    require(changed_units == modified_units, "unexpected changed cache unit set")
    for path in modified_units:
        start, size = after_spans[path]
        require_hash_fields_zero(after_units[path], candidate_bytes[start:start + size])
        before_strings = before_units[path]["strings"]
        after_strings = after_units[path]["strings"]
        expected_strings = [row["value"] for row in before_strings]
        if path == gate["unit_qrc_path"]:
            for row in gate["code_records"]:
                expected_strings[row["index"]] = ""
        for item in PATCHES:
            if item["unit_qrc_path"] != path:
                continue
            indices = [index for index, row in enumerate(before_strings) if row["file_offset"] == item["record_file_offset"]]
            require(len(indices) == 1 and expected_strings[indices[0]] == item["old_string"], f"unexpected loader string at {item['record_file_offset']}")
            expected_strings[indices[0]] = item["new_string"]
        require([row["value"] for row in after_strings] == expected_strings, f"unexpected string table changes: {path}")
    changed_offsets = {index for index, (left, right) in enumerate(zip(source_bytes, candidate_bytes)) if left != right}
    require(changed_offsets and changed_offsets <= permitted_offsets, "unexpected binary byte changes")

    layout = json.loads(LAYOUT_PATH.read_text(encoding="utf-8"))
    elf_checks = verify_elf_geometry(source_bytes, candidate_bytes, layout, changed_offsets)
    copy_rows = {}
    copy_bytes = {}
    for destination, source_path in SOURCE_FILES.items():
        qml_bytes = source_path.read_bytes()
        copy_bytes[destination] = qml_bytes
        copy_rows[destination] = {
            "source_path": source_path.relative_to(BASE).as_posix(),
            "size": len(qml_bytes),
            "sha256": sha256(qml_bytes),
        }

    source_relative = source.resolve().relative_to(BASE).as_posix()
    validation = {
        "source_identity_verified": True,
        "cache_units_before": len(before_units),
        "cache_units_after": len(after_units),
        "registry_unchanged": before_registry == after_registry,
        "modified_units": len(changed_units),
        "modified_unit_paths": sorted(changed_units),
        "other_units_unchanged": len(before_units) - len(changed_units),
        "binary_size_unchanged": len(source_bytes) == len(candidate_bytes),
        "permitted_record_regions_only": changed_offsets <= permitted_offsets,
        "target_cache_hash_fields_zero": True,
        "cache_hash_checked_unit_paths": sorted(modified_units),
        "decoder_success": len(before_units) == len(after_units) == 198,
        **elf_checks,
    }
    require(all(value is True for key, value in validation.items() if isinstance(value, bool)), "candidate validation failed")
    require(source.read_bytes() == source_bytes, "source changed during candidate preparation")
    for destination, source_path in SOURCE_FILES.items():
        require(source_path.read_bytes() == copy_bytes[destination], f"QML source changed during preparation: {destination}")
    manifest = {
        "schema_version": 1,
        "status": "inactive_unverified_runtime",
        "source": {"path": source_relative, "sha256": sha256(source_bytes), "size": len(source_bytes)},
        "candidate": {"launcher": "Launcher", "sha256": sha256(candidate_bytes), "size": len(candidate_bytes)},
        "source_copies": copy_rows,
        "patches": patch_rows,
        "factory_code_removal": {"unit_qrc_path":gate["unit_qrc_path"],"records_cleared":len(code_rows),
                                 "records":code_rows,"system_login_changes":False},
        "validation": validation,
        "runtime_status": {
            "candidate_active": False,
            "runtime_verified": False,
            "target_cache_acceptance_verified": False,
            "deployment_performed": False,
        },
    }
    write_staged_output(output, source, candidate_bytes, copy_bytes, manifest)
    return manifest


def write_staged_output(output: Path, source: Path, candidate_bytes: bytes, copy_bytes: dict[str, bytes], manifest: dict[str, object]) -> None:
    require(not os.path.lexists(output), "output path already exists")
    with tempfile.TemporaryDirectory(prefix=".ui-candidate-stage-", dir=output.parent) as temporary:
        stage = Path(temporary)
        (stage / "Launcher").write_bytes(candidate_bytes)
        shutil.copystat(source, stage / "Launcher")
        for relative, contents in copy_bytes.items():
            target = stage / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(contents)
        (stage / "manifest.json").write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        require(not os.path.lexists(output), "output path appeared during candidate preparation")
        os.rename(stage, output)


def main() -> int:
    parser = argparse.ArgumentParser(description="Prepare a PC-only Launcher cache candidate without target execution.")
    parser.add_argument("--source", type=Path, default=SOURCE_DEFAULT)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    target = output_path(args.output)
    require(args.source.is_file(), "source Launcher is missing")
    manifest = build_candidate(args.source, target)
    print(
        json.dumps(
            {
                "status": manifest["status"],
                "candidate": str(target),
                "sha256": manifest["candidate"]["sha256"],
                "size": manifest["candidate"]["size"],
                "decoded_units": manifest["validation"]["cache_units_after"],
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, struct.error, UnicodeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
