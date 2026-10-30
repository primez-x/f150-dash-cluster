from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import re
import struct
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path


BASE = Path(__file__).resolve().parents[1]
GENERATOR = BASE / "tools" / "prepare_ui_candidate.py"
DECODER_PATH = BASE / "tools" / "decode_qml_units.py"
SOURCE = BASE / "installed" / "capture-04" / "rootfs" / "usr" / "bin" / "Launcher"
OUTPUT_PARENT = BASE / "analysis" / "capture-04"
OUTPUT = OUTPUT_PARENT / "ui-candidate-menu-v1"
RESULT = OUTPUT_PARENT / "ui-loader-replay-results.json"
SCHEMA = BASE / "evidence" / "qt-5.14.2" / "qv4instr_moth_p.h"
EXPECTED_SOURCE_SHA256 = "2451c3fb6f6c1344625aa2882760eaaccd3dc0979ad1296c9028838e77e2823b"
LOADERS = {
    "qrc:/common/VehicleEvent.qml": {
        "file_offset": 46800,
        "replacement": "file:/etc/vnV.qml",
        "unit_qrc_path": "main.qml",
        "source": BASE / "patches" / "capture-04" / "etc" / "common" / "VehicleEvent.qml",
        "destination": "etc/vnV.qml",
    },
    "qrc:/common/Global.qml": {
        "file_offset": 47184,
        "replacement": "file:/etc/vnG.qml",
        "unit_qrc_path": "main.qml",
        "source": BASE / "patches" / "capture-04" / "etc" / "common" / "Global.qml",
        "destination": "etc/vnG.qml",
    },
    "qrc:/Trucks/menu/MenuItemsList.qml": {
        "file_offset": 4002512,
        "replacement": "file:/etc/vnM.qml",
        "unit_qrc_path": "Trucks/menu/MenuPage.qml",
        "source": BASE / "patches" / "capture-04" / "etc" / "vnM.qml",
        "destination": "etc/vnM.qml",
    },
}


# Copied with no cache redirect: vnM hosts vnF, and vnF opens vnB.
COPIES = [
    {"source": BASE / "patches" / "capture-04" / "etc" / "vnF.qml", "destination": "etc/vnF.qml"},
    {"source": BASE / "patches" / "capture-04" / "etc" / "vnB.qml", "destination": "etc/vnB.qml"},
]
MODIFIED_UNITS = ["Trucks/menu/MenuPage.qml", "Trucks/menu/system/MenuSystemFactory.qml", "main.qml"]


class ReplayFailure(Exception):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ReplayFailure(message)


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


def decode_units(decoder, binary: bytes):
    starts = [match.start() for match in re.finditer(b"qv4cdata", binary)]
    require(len(starts) == 198, f"expected 198 cache starts, found {len(starts)}")
    registry = decoder.cache_registry(binary)
    require(len(registry) == 198, f"expected 198 registry rows, found {len(registry)}")
    path_by_offset = {row["unit_file_offset"]: row["qrc_path"] for row in registry}
    require(len(path_by_offset) == 198, "registry offsets are not unique")
    schema = decoder.opcode_schema(SCHEMA)
    units = {}
    spans = {}
    for index, start in enumerate(starts):
        require(start in path_by_offset, f"cache unit {index} has no registry entry")
        size = struct.unpack_from("<I", binary, start + 24)[0]
        require(size >= 248 and start + size <= len(binary), f"cache unit {index} has invalid geometry")
        require(index + 1 == len(starts) or start + size <= starts[index + 1], f"cache unit {index} overlaps the next unit")
        unit = decoder.Decoder(binary[start:start + size], start, schema).parse()
        path = path_by_offset[start]
        unit["qrc_path"] = path
        require(path not in units, f"duplicate qrc path: {path}")
        units[path] = unit
        spans[path] = (start, size)
    require(len(units) == 198, "decoder did not parse all registered units")
    return units, spans, registry


def run_cli(source: Path, output: Path | str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(GENERATOR), "--source", str(source), "--output", str(output)],
        cwd=BASE,
        capture_output=True,
        text=True,
        check=False,
    )


def inspect_candidate(directory: Path, decoder) -> dict[str, object]:
    manifest_path = directory / "manifest.json"
    candidate_path = directory / "Launcher"
    require(manifest_path.is_file(), "candidate manifest missing")
    require(candidate_path.is_file(), "candidate Launcher missing")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    original = SOURCE.read_bytes()
    candidate = candidate_path.read_bytes()
    require(manifest["source"]["sha256"] == EXPECTED_SOURCE_SHA256, "manifest source hash mismatch")
    require(manifest["candidate"]["sha256"] == sha256(candidate), "manifest candidate hash mismatch")
    require(manifest["candidate"]["size"] == len(candidate) == len(original), "candidate size changed")
    require(manifest["status"] == "inactive_unverified_runtime", "candidate status is not inactive")
    require(manifest["runtime_status"] == {
        "candidate_active": False,
        "runtime_verified": False,
        "target_cache_acceptance_verified": False,
        "deployment_performed": False,
    }, "runtime status does not fail closed")

    patches = manifest["patches"]
    require(manifest.get("factory_code_removal", {}).get("records_cleared") == 13,
            "candidate retains vendor factory code records")
    require(len(patches) == len(LOADERS), f"expected {len(LOADERS)} loader patches, found {len(patches)}")
    patch_by_old = {patch["old_string"]: patch for patch in patches}
    require(set(patch_by_old) == set(LOADERS), "manifest loader set mismatch")
    allowed = set()
    for old_string, expected in LOADERS.items():
        patch = patch_by_old[old_string]
        record = expected["file_offset"]
        new_string = expected["replacement"]
        require(patch["record_file_offset"] == record, f"record offset mismatch for {old_string}")
        require(patch["new_string"] == new_string, f"replacement mismatch for {old_string}")
        require(patch["unit_qrc_path"] == expected["unit_qrc_path"], f"unit mismatch for {old_string}")
        require(patch["length_field_range"] == {"start": record + 4, "size": 4}, f"length range mismatch for {old_string}")
        old_length = len(old_string)
        payload_size = (old_length + 1) * 2
        require(patch["payload_range"] == {"start": record + 24, "size": payload_size}, f"payload range mismatch for {old_string}")
        allowed.update(range(record + 4, record + 8))
        allowed.update(range(record + 24, record + 24 + payload_size))
        ref, length, alloc, offset32, offset64 = struct.unpack_from("<iiIIQ", candidate, record)
        require((ref, length, alloc, offset32, offset64) == (-1, len(new_string), 0, 24, 24), f"record header mismatch for {old_string}")
        payload = candidate[record + 24:record + 24 + payload_size]
        encoded = new_string.encode("utf-16-le")
        require(payload[:len(encoded)] == encoded, f"payload mismatch for {old_string}")
        require(payload[len(encoded):] == b"\0" * (payload_size - len(encoded)), f"payload tail is not zero for {old_string}")

    gate = json.loads((BASE/"evidence/fixtures/capture-04/factory-code-records.json").read_text(encoding="utf-8"))
    removed = manifest["factory_code_removal"]
    require(removed["system_login_changes"] is False and removed["unit_qrc_path"] == gate["unit_qrc_path"], "factory removal scope mismatch")
    require(len(removed["records"]) == len(gate["code_records"]) == 13, "factory code removal count mismatch")
    for expected, actual in zip(gate["code_records"], removed["records"]):
        record = expected["file_offset"]
        require(actual == {"string_index":expected["index"],"record_file_offset":record,
            "length_field_range":{"start":record+4,"size":4},"payload_range":{"start":record+24,"size":10}}, "factory cleared-record metadata mismatch")
        require(struct.unpack_from("<iiIIQ", candidate, record) == (-1,0,0,24,24), "factory code length was not cleared")
        require(candidate[record+24:record+34] == bytes(10), "factory code payload remains")
        allowed.update(range(record+4,record+8))
        allowed.update(range(record+24,record+34))
    changed = {index for index, (left, right) in enumerate(zip(original, candidate)) if left != right}
    require(changed and changed <= allowed, "binary changes escaped the loader and factory code records")
    validations = manifest["validation"]
    require(validations["cache_units_before"] == validations["cache_units_after"] == 198, "cache unit count mismatch")
    require(validations["modified_units"] == len(MODIFIED_UNITS), "modified cache unit count mismatch")
    require(validations["modified_unit_paths"] == MODIFIED_UNITS, "modified cache unit path set mismatch")
    require(validations["cache_hash_checked_unit_paths"] == validations["modified_unit_paths"], "cache hash validation path set mismatch")
    require(validations["other_units_unchanged"] == 198 - len(MODIFIED_UNITS), "other cache unit count mismatch")
    for key in (
        "registry_unchanged",
        "binary_size_unchanged",
        "permitted_record_regions_only",
        "target_cache_hash_fields_zero",
        "native_text_unchanged",
        "elf_header_unchanged",
        "elf_program_headers_unchanged",
        "elf_section_headers_unchanged",
        "decoder_success",
    ):
        require(validations[key] is True, f"manifest validation failed: {key}")

    copies = manifest["source_copies"]
    sources = list(LOADERS.values()) + COPIES
    require(set(copies) == {item["destination"] for item in sources}, "source copy set mismatch")
    for expected in sources:
        destination = expected["destination"]
        source_bytes = expected["source"].read_bytes()
        copied = (directory / destination).read_bytes()
        require(copied == source_bytes, f"QML copy differs from current patch: {destination}")
        require(copies[destination]["sha256"] == sha256(source_bytes), f"QML copy hash mismatch: {destination}")

    original_units, original_spans, original_registry = decode_units(decoder, original)
    candidate_units, candidate_spans, candidate_registry = decode_units(decoder, candidate)
    require(original_registry == candidate_registry, "cache registry changed")
    require(original_spans == candidate_spans, "cache unit geometry changed")
    require(set(original_units) == set(candidate_units), "decoded qrc unit set changed")
    modified_units = {item["unit_qrc_path"] for item in LOADERS.values()} | {gate["unit_qrc_path"]}
    for row in gate["code_records"]:
        require(candidate_units[gate["unit_qrc_path"]]["strings"][row["index"]]["value"] == "", "decoded factory code remains")
    for path, (start, size) in original_spans.items():
        if path not in modified_units:
            require(original[start:start + size] == candidate[start:start + size], f"unaffected cache unit changed: {path}")
    for path in modified_units:
        start, size = candidate_spans[path]
        unit = candidate_units[path]
        require(
            unit["library_hash_present"] is False
            and unit["md5_present"] is False
            and unit["dependency_md5_present"] is False
            and candidate[start + 28:start + 108] == b"\0" * 80,
            f"candidate cache hash fields are not zero: {path}",
        )
    for old_string, expected in LOADERS.items():
        unit_path = expected["unit_qrc_path"]
        original_unit = original_units[unit_path]
        candidate_unit = candidate_units[unit_path]
        record = expected["file_offset"]
        before_rows = [row for row in original_unit["strings"] if row["value"] == old_string and row["file_offset"] == record]
        after_rows = [row for row in candidate_unit["strings"] if row["value"] == expected["replacement"] and row["file_offset"] == record]
        require(len(before_rows) == len(after_rows) == 1, f"decoded loader not exact at {record}")
        require(
            original_unit["library_hash_present"] is False
            and original_unit["md5_present"] is False
            and original_unit["dependency_md5_present"] is False,
            f"original cache hash fields are not zero: {unit_path}",
        )
    return {"manifest": manifest, "candidate_sha256": sha256(candidate), "candidate_size": len(candidate)}


def write_result(result: dict[str, object]) -> None:
    RESULT.parent.mkdir(parents=True, exist_ok=True)
    temporary = RESULT.with_name(f".{RESULT.name}.{uuid.uuid4().hex}.tmp")
    temporary.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, RESULT)


def main() -> int:
    decoder = load_decoder()
    require(SOURCE.is_file(), f"verified Launcher missing: {SOURCE}")
    source_bytes = SOURCE.read_bytes()
    require(sha256(source_bytes) == EXPECTED_SOURCE_SHA256 == decoder.SHA256, "installed Launcher baseline hash mismatch")
    for config in list(LOADERS.values()) + COPIES:
        require(config["source"].is_file(), f"QML source candidate missing: {config['source']}")
    OUTPUT_PARENT.mkdir(parents=True, exist_ok=True)
    tests: dict[str, dict[str, object]] = {}

    with tempfile.TemporaryDirectory(prefix=".ui-loader-replay-", dir=OUTPUT_PARENT) as area_name:
        area = Path(area_name)
        successful_output = area / "successful-candidate"
        baseline = run_cli(SOURCE, successful_output)
        require(baseline.returncode == 0, f"baseline candidate CLI failed: {baseline.stderr.strip()}")
        successful = inspect_candidate(successful_output, decoder)
        tests["baseline_source"] = {"result": "accepted", "source_sha256": EXPECTED_SOURCE_SHA256}
        tests["exact_loader_redirects"] = {"result": "passed", "records": len(LOADERS),
                                           "units": len({item["unit_qrc_path"] for item in LOADERS.values()})}
        tests["factory_code_removal"] = {"result":"passed", "records":13, "native_text_unchanged":True}
        tests["source_copy_hashes"] = {"result": "passed", "copies": len(LOADERS) + len(COPIES)}
        tests["cache_integrity"] = {
            "result": "passed",
            "decoded_units": 198,
            "modified_units": len(MODIFIED_UNITS),
            "unchanged_other_units": 198 - len(MODIFIED_UNITS),
            "size_unchanged": successful["candidate_size"] == len(source_bytes),
        }

        changed_source = area / "changed-Launcher"
        damaged = bytearray(source_bytes)
        damaged[0] ^= 1
        changed_source.write_bytes(damaged)
        changed_output = area / "changed-source-output"
        changed = run_cli(changed_source, changed_output)
        require(changed.returncode != 0, "changed source was accepted")
        require(not changed_output.exists(), "changed source created output")
        tests["changed_source"] = {"result": "rejected", "output_created": False}

        existing_output = area / "existing-output"
        existing_output.mkdir()
        marker = existing_output / "preserve.txt"
        marker.write_text("preserve\n", encoding="utf-8")
        overwrite = run_cli(SOURCE, existing_output)
        require(overwrite.returncode != 0, "pre-existing output was accepted")
        require(marker.read_text(encoding="utf-8") == "preserve\n", "pre-existing output marker changed")
        require(sorted(path.name for path in existing_output.iterdir()) == ["preserve.txt"], "pre-existing output contents changed")
        tests["preexisting_output"] = {"result": "rejected", "contents_preserved": True}

        traversal_target = OUTPUT_PARENT / ".." / f".ui-loader-traversal-{uuid.uuid4().hex}"
        traversal = run_cli(SOURCE, traversal_target)
        require(traversal.returncode != 0, "traversal output path was accepted")
        require(not traversal_target.exists() and not traversal_target.resolve().exists(), "traversal path created output")
        tests["traversal_output"] = {"result": "rejected", "output_created": False}

        with tempfile.TemporaryDirectory(prefix="ui-loader-outside-") as outside_name:
            outside_output = Path(outside_name) / "candidate"
            outside = run_cli(SOURCE, outside_output)
            require(outside.returncode != 0, "output outside analysis was accepted")
            require(not outside_output.exists(), "outside output path created candidate")
        tests["outside_analysis_output"] = {"result": "rejected", "output_created": False}

        final_candidate = OUTPUT
        if final_candidate.exists() or final_candidate.is_symlink():
            existing = inspect_candidate(final_candidate, decoder)
            require(existing["candidate_sha256"] == successful["candidate_sha256"], "existing candidate differs; candidate preserved")
            tests["final_candidate"] = {"result": "existing_match", "sha256": existing["candidate_sha256"]}
        else:
            final_run = run_cli(SOURCE, final_candidate)
            require(final_run.returncode == 0, f"final candidate CLI failed: {final_run.stderr.strip()}")
            existing = inspect_candidate(final_candidate, decoder)
            require(existing["candidate_sha256"] == successful["candidate_sha256"], "final candidate differs from E2E output")
            tests["final_candidate"] = {"result": "created", "sha256": existing["candidate_sha256"]}

    result = {
        "status": "PASS",
        "source_sha256": EXPECTED_SOURCE_SHA256,
        "candidate_directory": str(OUTPUT.relative_to(BASE)).replace("\\", "/"),
        "candidate_sha256": successful["candidate_sha256"],
        "candidate_size": successful["candidate_size"],
        "tests": tests,
        "runtime_status": "inactive; target runtime and cache acceptance remain unverified",
        "device_execution": False,
    }
    write_result(result)
    print(f"PASS: UI candidate replay completed; 198 units decoded, {len(LOADERS)} loaders redirected in "
          f"{len({item['unit_qrc_path'] for item in LOADERS.values()})} units, thirteen factory codes cleared, {len(LOADERS) + len(COPIES)} QML files copied.")
    print(f"Result: {RESULT}")
    print(f"Candidate: {OUTPUT}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ReplayFailure, OSError, subprocess.SubprocessError, ValueError, struct.error, UnicodeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
