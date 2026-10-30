"""Export portable dashboard design evidence and labelled geometry schematics."""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import posixpath
import re
import shutil
from pathlib import Path
from xml.etree import ElementTree

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "handoff" / "claude-dashboard"
CACHE = ROOT / "analysis" / "capture-04" / "qml-cache"
ALLOWED = {".png", ".jpg", ".jpeg", ".svg", ".ttf", ".otf"}
BLOCKED = re.compile(r"password|passwd|credential|serial|qrcode|qr_code|private", re.I)


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def plain(value):
    if isinstance(value, dict):
        if "kind" in value and "value" in value:
            return plain(value["value"])
        return {k: plain(v) for k, v in value.items() if k not in {"file_offset", "unit_offset"}}
    if isinstance(value, list):
        return [plain(v) for v in value]
    return value


def binding_value(binding, unit):
    kind = binding["type"]
    if kind == "Script":
        fn = unit["functions"][binding["function_index"]]
        expression = fn.get("inferred_branch_free_expression")
        return {"kind": "expression" if expression else "unresolved_branch",
                "expression": expression, "function": fn["index"]}
    if "object_index" in binding:
        return {"kind": kind, "object": binding["object_index"]}
    return {"kind": "literal", "value": plain(binding.get("string", binding.get("value")))}


def export_unit(unit):
    result = {"component": unit["qrc_path"], "compiled_sha256": unit["sha256"],
              "imports": plain(unit["imports"]), "objects": [], "functions": []}
    for obj in unit["objects"]:
        result["objects"].append({"index": obj["index"], "type": obj["type"], "id": obj["id"],
            "source_line": obj["location"]["line"], "parents": plain(obj["parents"]),
            "properties": plain(obj["properties"]), "aliases": plain(obj["aliases"]),
            "bindings": [{"property": b["property"], "source_line": b["location"]["line"],
                          **binding_value(b, unit)} for b in obj["bindings"]]})
    for fn in unit["functions"]:
        result["functions"].append({"index": fn["index"], "name": fn["name"],
            "source_line": fn["location"]["line"], "parameters": plain(fn["parameters"]),
            "expression_inference": fn.get("inferred_branch_free_expression"),
            "bytecode": plain(fn["bytecode"])})
    return result


def component_candidates(unit, typename):
    base = posixpath.dirname(unit["qrc_path"])
    yield posixpath.join(base, typename + ".qml")
    for imp in unit["imports"]:
        if imp["type"] == 2:
            yield posixpath.normpath(posixpath.join(base, imp["uri"], typename + ".qml"))


def safe_component(path):
    return (path.startswith("Trucks/ui") or path.startswith("Trucks/common/")) and "/update/" not in path


def closure(start, units):
    found, pending = set(), list(start)
    while pending:
        name = pending.pop()
        if name in found or name not in units:
            continue
        found.add(name)
        unit = units[name]
        for obj in unit["objects"]:
            for candidate in component_candidates(unit, obj["type"]):
                if candidate in units and safe_component(candidate):
                    pending.append(candidate)
                    break
        for string in unit["strings"]:
            value = string["value"]
            if value.startswith("qrc:/") and safe_component(value[5:]):
                pending.append(value[5:])
    return sorted(found)


def asset_literals(unit):
    for string in unit["strings"]:
        value = string["value"]
        if "images/" not in value or BLOCKED.search(value):
            continue
        if value.startswith("/images/"):
            yield value, "installed", value[len("/images/"):]
        elif value.startswith("qrc:/Trucks/images/"):
            yield value, "launcher", value[5:]
        elif value.startswith(("../", "./")):
            yield value, "launcher", posixpath.normpath(posixpath.join(posixpath.dirname(unit["qrc_path"]), value))


def asset_matches(relative, inventory):
    exact = [p for p in inventory if p == relative or posixpath.splitext(p)[0] == relative]
    if exact:
        return exact
    # Dynamic image arrays use literal prefixes. Preserve all observed candidate files.
    return [p for p in inventory if p.startswith(relative)]


def export_assets(selected_units):
    sources = {"launcher": ROOT / "recovered-resources" / "latest-Launcher",
               "installed": ROOT / "installed" / "capture-04" / "rootfs" / "etc" / "images"}
    inventory = {k: {p.relative_to(base).as_posix(): p for p in base.rglob("*")
                    if p.is_file() and p.suffix.lower() in ALLOWED and not BLOCKED.search(p.name)}
                 for k, base in sources.items()}
    assets, links, unresolved = {}, {}, []
    for name, unit in selected_units.items():
        links[name] = []
        for literal, origin, relative in asset_literals(unit):
            matches = asset_matches(relative, inventory[origin])
            row = {"source_literal": literal, "local_assets": []}
            for candidate in matches:
                key = f"assets/{origin}/{candidate}"
                path = OUT / key
                if key not in assets:
                    path.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(inventory[origin][candidate], path)
                    width, height = None, None
                    try:
                        with Image.open(path) as image:
                            width, height = image.size
                    except (OSError, ValueError):
                        pass
                    assets[key] = {"path": key, "sha256": digest(path), "width": width, "height": height,
                                   "source": f"{origin}/{candidate}", "selection": "literal or dynamic prefix candidate"}
                row["local_assets"].append(key)
            links[name].append(row)
            if not matches:
                unresolved.append({"component": name, "source_literal": literal,
                                   "reason": "No matching file in recovered resource sets"})
    # The design kit (design/round-02, design/round-03) also draws these launcher images.
    for candidate in ["Trucks/images/common/icon/fuel.png", "Trucks/images/common/turnlight/tsico_left_h.png",
                      "Trucks/images/common/turnlight/tsico_left_n.png", "Trucks/images/common/turnlight/tsico_right_h.png",
                      "Trucks/images/common/turnlight/tsico_right_n.png"]:
        key = "assets/launcher/" + candidate
        if key not in assets:
            path = OUT / key
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(inventory["launcher"][candidate], path)
            with Image.open(path) as image:
                width, height = image.size
            assets[key] = {"path": key, "sha256": digest(path), "width": width, "height": height,
                           "source": "launcher/" + candidate, "selection": "Design kit image"}
    for font_name, family in [("KonexyPersonalUseRegular.ttf", "Konexy Personal Use"),
                              ("BMW.ttf", "BMW Type Global")]:
        source = ROOT / "installed" / "capture-04" / "rootfs" / "usr" / "share" / "fonts" / font_name
        if source.is_file():
            key = "assets/fonts/" + font_name
            target = OUT / key
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            assets[key] = {"path": key, "sha256": digest(target), "family": family,
                           "source": "installed/usr/share/fonts/" + font_name,
                           "selection": "Observed font family binding"}
    return assets, links, unresolved


def simple_values(obj, unit):
    result = {}
    for b in obj["bindings"]:
        value = binding_value(b, unit)
        if value["kind"] == "literal":
            result[b["property"]] = value["value"]
        elif value["kind"] == "expression":
            result[b["property"]] = {"expr": value["expression"]}
        elif value["kind"] == "unresolved_branch":
            result[b["property"]] = {"unresolved_function": value["function"]}
    return result


def static_geometry(unit, units, assets, links):
    """Resolve constant dimensions and parent anchors; leave runtime branches unresolved."""
    objects = unit["objects"]
    values = {o["index"]: simple_values(o, unit) for o in objects}
    boxes = {0: [0, 0, values[0].get("width", 1920), values[0].get("height", 932)]}
    notes = []
    for obj in objects[1:]:
        if not obj["type"] or obj["type"] in {"Behavior", "NumberAnimation", "OpacityAnimator", "ScaleAnimator", "Timer", "SpringAnimation"}:
            continue
        value = values[obj["index"]].copy()
        children = [objects[b["object_index"]] for b in obj["bindings"]
                    if b["type"] == "GroupProperty" and "object_index" in b]
        anchors = {}
        for child in children:
            property_name = next((b["property"] for b in obj["bindings"] if b.get("object_index") == child["index"]), "")
            if property_name == "anchors":
                anchors.update(values[child["index"]])
        source = value.get("source")
        target = None
        if isinstance(source, str) and source.startswith("qrc:/"):
            target = units.get(source[5:])
        if target is None:
            target = next((units[c] for c in component_candidates(unit, obj["type"]) if c in units), None)
        defaults = simple_values(target["objects"][0], target) if target else {}
        width, height = value.get("width", defaults.get("width")), value.get("height", defaults.get("height"))
        if isinstance(source, str) and not source.startswith("qrc:/"):
            row = next((r for r in links.get(unit["qrc_path"], []) if r["source_literal"] == source), None)
            if row and len(row["local_assets"]) == 1:
                asset = assets[row["local_assets"][0]]
                width = width if width is not None else asset["width"]
                height = height if height is not None else asset["height"]
        parent_index = next((p["object_index"] for p in obj["parents"] if p["binding_type"] == "Object"), 0)
        parent = boxes.get(parent_index)
        if not parent:
            notes.append({"object": obj["index"], "reason": "Parent geometry unresolved"})
            continue
        px, py, pw, ph = parent
        x, y = value.get("x", 0), value.get("y", 0)
        if anchors.get("fill") == {"expr": "parent"}:
            x, y, width, height = 0, 0, pw, ph
        if not all(isinstance(v, (int, float)) for v in (width, height, x, y)):
            notes.append({"object": obj["index"], "reason": "Runtime or implicit bounds unresolved"})
            continue
        if anchors.get("horizontalCenter") == {"expr": "parent.horizontalCenter"}:
            x = (pw - width) / 2 + anchors.get("horizontalCenterOffset", 0)
        if anchors.get("verticalCenter") == {"expr": "parent.verticalCenter"}:
            y = (ph - height) / 2 + anchors.get("verticalCenterOffset", 0)
        for axis, edge, margin in [("x", "left", "leftMargin"), ("y", "top", "topMargin")]:
            if anchors.get(edge) == {"expr": f"parent.{edge}"}:
                offset = anchors.get(margin, 0)
                if not isinstance(offset, (int, float)):
                    if axis == "x":
                        x = None
                    else:
                        y = None
                    break
                if axis == "x":
                    x = offset
                else:
                    y = offset
        if anchors.get("right") == {"expr": "parent.right"}:
            margin = anchors.get("rightMargin", 0)
            x = pw - width - margin if isinstance(margin, (int, float)) else None
        if anchors.get("bottom") == {"expr": "parent.bottom"}:
            margin = anchors.get("bottomMargin", 0)
            y = ph - height - margin if isinstance(margin, (int, float)) else None
        if not isinstance(x, (int, float)) or not isinstance(y, (int, float)):
            notes.append({"object": obj["index"], "reason": "Runtime anchor margin unresolved"})
            continue
        boxes[obj["index"]] = [px + x, py + y, width, height]
    result = []
    for index, box in boxes.items():
        obj = objects[index]
        if index and box[2] > 0 and box[3] > 0:
            result.append({"object": index, "label": obj["id"] or obj["type"],
                           "type": obj["type"], "bounds": box,
                           "source_line": obj["location"]["line"],
                           "status": "constant bounds; visibility and animation unresolved"})
    return result, notes


# Visible screen area, measured on the truck on 2026-10-30 from two photos of Factory > Screen grid (driver eye height and
# a lower camera through the wheel). The window is 1920 x 932 and main.qml draws the dashboard at scale 1, rotation 0,
# top 0 for truck model 1. The bezel opening has an arched top edge; the steering column shroud covers the bottom center.
# The hidden areas are the union of both views. A lower driver eye position hides more at the bottom center.
def bezel_top(x):
    return round((x - 960) ** 2 / 9300)


BEZEL_TOP = [[x, bezel_top(x)] for x in range(0, 1921, 80)]
SHROUD = [[210, 932], [300, 854], [460, 797], [572, 776], [1348, 776], [1460, 797], [1620, 854], [1710, 932]]
HIDDEN = {"bezel_top": [[0, 0], [1920, 0]] + BEZEL_TOP[::-1], "steering_column": SHROUD}
VISIBLE_AREA = {
    "measured": "2026-10-30 on the truck, Factory > Screen grid, two photos (driver eye height and a lower camera)",
    "screen": [1920, 932], "dashboard_transform": {"scale": 1, "rotation": 0, "top_margin": 0, "truck_model": 1},
    "bezel_top": {"rule": "Rows above y = (x - 960)^2 / 9300 are behind the arched bezel: 0 px at the center, 10 px at x 652/1268, "
                          "40 px at x 344/1576, 70 px at x 156/1764, 99 px at the side edges.", "points": BEZEL_TOP},
    "steering_column": {"rule": "The steering column shroud hides the bottom center. The polygon is the hidden area.", "points": SHROUD,
                        "driver_eye_height": "From the driver eye height the shroud top is near y 818 instead of y 776."},
    "sides": "Columns x 0 and x 1919 are visible from below the bezel arch to y 931.",
    "bezel_lamps": "Physical check engine (left) and tire pressure (right) lamps sit on the bezel outside the screen, near y 450.",
    "steering_wheel": "From the driver eye height the wheel rim passes close to the top corners. Keep critical content off the top corners.",
    "hidden_polygons": HIDDEN}


def schematic(layout, boxes, cruise):
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1040" viewBox="0 0 1920 1040">',
           '<rect width="1920" height="1040" fill="#111820"/>',
           '<rect x="1" y="1" width="1918" height="930" fill="#080c11" stroke="#738699"/>',
           f'<text x="24" y="975" fill="white" font-family="sans-serif" font-size="25">UI{layout} — labelled reconstruction; declared 1920 × 932 coordinates</text>',
           '<text x="24" y="1014" fill="#b6c4d1" font-family="sans-serif" font-size="20">Constant component bounds only. Runtime geometry, gauges, visibility, and vehicle branches remain in JSON.</text>',
           '<defs><clipPath id="canvas"><rect width="1920" height="932"/></clipPath></defs><g clip-path="url(#canvas)">']
    canvas = Image.new("RGB", (1920, 1040), "#111820")
    scene = Image.new("RGB", (1920,932), "#080c11")
    draw = ImageDraw.Draw(scene)
    draw.rectangle((1, 1, 1918, 931), fill="#080c11", outline="#738699", width=2)
    font = ImageFont.load_default(size=22)
    small = ImageFont.load_default(size=18)
    for count, row in enumerate(boxes):
        x, y, w, h = row["bounds"]
        if w > 1850 and h > 800 or x + w < 0 or y + h < 0 or x > 1920 or y > 932:
            continue
        color = ["#5bb4d6", "#8fc87e", "#d0a36c", "#ad9cdb"][count % 4]
        label = f'{row["label"]} [{row["object"]}]'
        svg += [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="none" stroke="{color}" stroke-width="2"/>',
                f'<text x="{x+5}" y="{y+24}" fill="{color}" font-family="sans-serif" font-size="20">{html.escape(label)}</text>']
        draw.rectangle((x, y, x + w, y + h), outline=color, width=2)
        draw.text((x + 5, y + 3), label, fill=color, font=small)
    if "x" in cruise:
        x, y = cruise["x"], cruise["y"]
        label = "ACC / LIM 90x50"
    else:
        x, y = 465, 670
        label = "ACC / LIM Ford branch 90x50"
    svg += [f'<rect x="{x}" y="{y}" width="90" height="50" fill="none" stroke="#ffe184" stroke-width="3"/>',
            f'<text x="{x}" y="{y-10}" fill="#ffe184" font-family="sans-serif" font-size="20">{label}</text>']
    draw.rectangle((x, y, x + 90, y + 50), outline="#ffe184", width=3)
    draw.text((x, y - 24), label, fill="#ffe184", font=small)
    # Areas the truck hides: shaded red with an outline.
    shade = Image.new("RGBA", (1920, 932), (0, 0, 0, 0))
    shade_draw = ImageDraw.Draw(shade)
    for points in HIDDEN.values():
        shade_draw.polygon([tuple(p) for p in points], fill=(255, 59, 48, 90), outline=(255, 59, 48, 255), width=3)
        svg.append(f'<polygon points="{" ".join(f"{a},{b}" for a, b in points)}" fill="#ff3b30" fill-opacity="0.35" stroke="#ff3b30" stroke-width="3"/>')
    svg.append('<text x="960" y="900" fill="#ff8a80" font-family="sans-serif" font-size="22" text-anchor="middle">Hidden by the steering column</text></g></svg>')
    scene = Image.alpha_composite(scene.convert("RGBA"), shade).convert("RGB")
    ImageDraw.Draw(scene).text((960, 888), "Hidden by the steering column", fill="#ff8a80", font=small, anchor="mm")
    canvas.paste(scene, (0,0))
    draw = ImageDraw.Draw(canvas)
    draw.text((24, 957), f"UI{layout} - labelled reconstruction; declared 1920 x 932 coordinates", fill="white", font=font)
    draw.text((24, 1000), "Constant component bounds only. Runtime details remain in JSON.", fill="#b6c4d1", font=small)
    (OUT / f"ui{layout}.svg").write_text("\n".join(svg), encoding="utf-8")
    canvas.save(OUT / f"ui{layout}.png")
    return canvas


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    index = read_json(CACHE / "index.json")
    units = {r["qrc_path"]: read_json(CACHE / r["artifact"]) for r in index["units"]}
    audit = read_json(ROOT / "analysis" / "capture-04" / "settings-cruise-audit.json")
    cruises = audit["cruise"]["sibling_layout_sweep"]
    assist = sorted(n for n in units if n.startswith("Trucks/menu/assist/"))
    sets = {i: closure([f"Trucks/ui{i}/Dashboard.qml", *assist], units) for i in range(1, 7)}
    selected = {n: units[n] for n in sorted(set().union(*sets.values()))}
    assets, links, unresolved = export_assets(selected)
    contracts = {
        "format": "dashboard-design-evidence-v1", "purpose": "Design new styles from recovered compiled UI evidence",
        "evidence": "Shipped compiled QML; branch-free expressions are decoder inferences, bytecode preserves unresolved branches",
        "measurement": {"design_canvas": [1920, 932], "physical_display": [1920, 932],
            "physical_display_source": "Measured on the truck (Factory > Screen grid). QT_QPA_EGLFS_PHYSICAL_WIDTH/HEIGHT 1920/720 in qtenv.sh are millimetres, not pixels.",
            "visible_area": VISIBLE_AREA,
            "warning": "Keep content out of the hidden polygons. Main uses uniform model-dependent scale, rotation, and margins; truck model 1 draws 1:1.",
            "main_loader": {"scale": "mSacel[Number(mTrucksModel)]", "rotation": "mRotation[Number(mTrucksModel)]",
                "top_margin": "mTopMargin[Number(mTrucksModel)]", "origin": "Item.Top",
                "model_index_0_scale": "mGlobalHeight === 720 ? 0.7752 : 1",
                "model_index_0_rotation": 0, "model_index_0_top_margin": 0,
                "model_index_0_left_margin": 0,
                "model_index_0_transform": "At 1920x720: x_screen = 960 + 0.7752 * (x_design - 960); y_screen = 0.7752 * y_design",
                "model_index_0_extent": [1488.384, 722.4864],
                "limit": "Model index 0 applies only on a 720-pixel-high window. The truck window is 932 pixels high."},
            "main_geometry_evidence": {"component": "main.qml", "functions": [plain(f) for f in units["main.qml"]["functions"] if f["index"] in [2,3,4,6,7,8,19]]}},
        "fonts": {"default_family": "Konexy Personal Use", "authority": "Installed common/Translation.qml:22",
                  "alternate_observed_family": "BMW Type Global", "assets": [r for r in assets.values() if "family" in r]},
        "navigation": {"layout_selection": "Trucks/Dashboard.qml mDashboard[mGlobalId.item.dashboard]; indexes 0–5 select ui1–ui6",
            "menu": "Shared menu Loader: center X; top 220; scale 0.85; active menuBarIndex; 100 ms scale animation",
            "vehicle_state": "Public visual bindings use mGlobalId.item fields. Preserve field names in each component specification.",
            "controls": "Dashboard key_back, key_ok, key_left, key_right, key_up, and key_down functions preserve recovered bytecode where present.",
            "scope": "Public dashboard, common visual components, and assist widgets. Factory, update, credential, and private configuration components excluded."},
        "cruise_contract": {"acc_component": "Trucks/common/AccLimitedIndicator.qml", "bounds": [90,50],
            "generic_alarm": "AlarmIndicator mIndex 31 uses alarmTable[31] > 0",
            "acc_visibility": "cruiseState; SET uses cruiseSpeedSet; ACC car branch uses cruiseAccInterfaceState",
            "limiter": "getCruiseLimSpeed() and getCruiseLimSpeedColor(); limiter and cruise use separate state fields",
            "design_requirement": "Use one shared cruise region across all six styles. Preserve available, engaged, set-speed, ACC, and LIM meanings. Consolidate alarm 31 after the vehicle-state mapping is verified.",
            "uncertainty": "Native numeric enum meanings and live CAN transitions remain unproved."},
        "unit_preferences": {
            "status": "PC source candidate; active loader and vehicle verification remain pending",
            "speed_distance": {"value_field": "metricSystem", "choices": {"0": "MPH / mi", "1": "km/h / km"},
                               "override_field": "speedUnitOverride", "native_setter_type": 2},
            "temperature": {"value_field": "temperatureUnit", "choices": {"0": "Fahrenheit", "1": "Celsius"},
                            "override_field": "tempUnitOverride", "native_setter_type": 1},
            "manual_selection": "Assign the selected Global value, then call mEventHandleId.item.setUnit2(type, value). Preserve the other unit preference.",
            "mode_display": "Show Manual when the corresponding override flag equals 1. Show Follow vehicle when the flag equals 0.",
            "reset_action": "Expose mEventHandleId.item.followVehicleUnits() in the ordinary Units menu. The action clears both overrides and adopts cached vehicle units.",
            "clock": "Retain native RTC unit follow. Unit selection must preserve unrelated settings.",
            "acceptance": ["Fahrenheit plus MPH", "Fahrenheit plus km/h", "Celsius plus MPH", "Celsius plus km/h",
                           "Both selection orders", "Restart persistence", "Explicit return to vehicle follow", "Unavailable temperature states"]},
        "settings_navigation": {
            "requirement": "Expose supported settings through ordinary menu navigation without credential gates.",
            "groups": ["Display", "Gauges and units", "Vehicle configuration", "Driver assistance", "Clock", "Connectivity", "Diagnostics", "Advanced settings"],
            "factory_inventory": "factory-settings.json contains all 19 recovered configuration rows.",
            "unsupported_features": "Keep unsupported entries visible with a clear reason. Never fabricate vehicle data or enable an unverified protocol.",
            "integration_status": "Navigation requirements; the source candidate does not replace the compiled factory menu."},
        "design_contract": ["Preserve speed, unit, gear, alarm, cruise/limiter, and vehicle data semantics across all styles.",
            "Use genuine assets through the local manifest. Keep alarm colors and active/inactive distinctions from binding evidence.",
            "Keep hidden states quiet. Reserve visual emphasis for active warnings.",
            "Do not infer gauge sweep, tick marks, maximum values, or native enum meanings from schematic rectangles.",
            "Treat every model branch, visible condition, animation, unit conversion, and menu state as a separate visual acceptance case."],
        "render_limits": ["Schematics show constant bounds, not actual screenshots.",
            "No vehicle sample data or invented gauge geometry appears in the schematics.",
            "Runtime branches, native custom types, implicit text metrics, loaded data, and state-dependent transforms need reconstruction.",
            "Asset prefix matches are candidate sets, not proof that every candidate appears simultaneously."],
    }
    write_json(OUT / "shared-contracts.json", contracts)
    write_json(OUT / "factory-settings.json", {
        "status": "Recovered configuration inventory; live capability checks remain required",
        "settings": [{key: row[key] for key in ["index", "key", "behavior", "persistence"]} for row in audit["factory_rows"]],
        "credential_values": "Excluded"})
    write_json(OUT / "asset-manifest.json", {"assets": list(assets.values()), "unresolved": unresolved})
    pages, sheets = [], []
    for i in range(1, 7):
        name = f"Trucks/ui{i}/Dashboard.qml"
        geometry, omitted = static_geometry(units[name], units, assets, links)
        cruise = cruises[i - 1]
        clean_cruise = {k: v for k, v in cruise.items() if k not in {"dashboard", "alarm"}}
        names = sets[i]
        palette = sorted({b["string"] for n in names for o in units[n]["objects"] for b in o["bindings"]
                          if isinstance(b.get("string"), str) and re.fullmatch(r"#[0-9A-Fa-f]{6,8}", b["string"])})
        root_bindings = {b["property"]: binding_value(b, units[name]) for b in units[name]["objects"][0]["bindings"]
                         if b["property"] in {"mWallpaper", "mLogo", "mSprite"}}
        spec = {"schema": "dashboard-layout-v1", "layout": f"ui{i}", "canvas": [1920,932],
            "shared_contracts": contracts, "cruise_placement": clean_cruise,
            "components": [export_unit(units[n]) for n in names],
            "asset_dependencies": {n: links[n] for n in names},
            "assets": [assets[k] for k in sorted({p for n in names for r in links[n] for p in r["local_assets"]}
                                                | {k for k in assets if k.startswith("assets/fonts/")})],
            "schematic_bounds": geometry, "unresolved_schematic_bounds": omitted,
            "literal_color_palette": palette, "style_selectors": root_bindings,
            "uncertainties": contracts["render_limits"],
            "public_vehicle_widgets": assist}
        write_json(OUT / f"ui{i}.json", spec)
        png = schematic(i, geometry, cruise)
        sheets.append(png.resize((768,416)))
        lines = [f"# UI{i} design specification", "", "Labelled reconstruction from compiled QML. No actual screen capture.", "",
                 f"- Entry component: `{name}`", f"- Canvas: 1920 × 932, drawn 1:1 on the truck screen. Red areas in the schematic are hidden by the bezel or the steering column (`visible_area` in the shared measurement contract).",
                 f"- Alarm component: `{cruise['alarm_path']}`. UI3–UI6 share the UI3 alarm component.",
                 f"- Component definitions: {len(names)}. Public assist widget definitions: {len(assist)}.",
                 f"- Constant schematic bounds: {len(geometry)}. Unresolved bounds: {len(omitted)}.",
                 "", f"Open [the schematic](ui{i}.svg) and [the full JSON specification](ui{i}.json).", "",
                 "## Component hierarchy", "", "| Object | Type | ID | Parent | Source line |", "|---|---|---|---|---|"]
        for obj in units[name]["objects"]:
            if obj["type"]:
                parent = ", ".join(str(p["object_index"]) for p in obj["parents"])
                lines.append(f"| {obj['index']} | {obj['type']} | {obj['id']} | {parent} | {obj['location']['line']} |")
        lines += ["", "## Style selectors", "", *[f"- `{key}`: `{json.dumps(value, ensure_ascii=False)}`" for key, value in root_bindings.items()],
                  "", "## Cruise regions", "",
                  f"- ACC/LIM location: X `{cruise.get('x', cruise.get('x_expression'))}`; Y `{cruise.get('y', cruise.get('y_expression'))}`.",
                  "- ACC/LIM component bounds: 90 × 50. Child text and images can extend beyond these bounds.",
                  "- Generic cruise alarm: index 31. The alarm grid and ACC/LIM have separate state predicates.",
                  f"- Alarm grid: `{json.dumps(cruise['alarm_grid'], ensure_ascii=False)}`.", "",
                  "## Constant component bounds", "", "| Component | X | Y | Width | Height |", "|---|---|---|---|---|",
                  *[f"| {row['label']} [{row['object']}] | " + " | ".join(str(v) for v in row["bounds"]) + " |" for row in geometry], "",
                  "## Exact evidence", "", "Each JSON object preserves anchors, geometry, colors, fonts, property bindings, and source lines.",
                  "Each function preserves resolved bytecode. Branch-free expressions remain marked as inferences.",
                  "The asset manifest maps original literals to local files with dimensions and SHA-256 hashes.",
                  "Public assist widgets cover trip, fuel, TPMS, battery, oil life, runtime, off-road, pitch, roll, and G-force data.", "",
                  "## Reconstruction limits", "", *[f"- {v}" for v in contracts["render_limits"]], ""]
        (OUT / f"ui{i}.md").write_text("\n".join(lines), encoding="utf-8")
        pages.append(f'<article><h2>UI{i}</h2><a href="ui{i}.svg"><img src="ui{i}.png" alt="UI{i} labelled reconstruction"></a><p><a href="ui{i}.md">Design guide</a> · <a href="ui{i}.json">Full JSON</a></p></article>')
    contact = Image.new("RGB", (1536,1248), "#111820")
    for index_number, image in enumerate(sheets):
        contact.paste(image, ((index_number % 2) * 768, (index_number // 2) * 416))
    contact.save(OUT / "contact-sheet.png")
    (OUT / "index.html").write_text('<!doctype html><html lang="en"><meta charset="utf-8"><title>Six dashboard layouts</title><style>body{background:#111820;color:#e3eaf2;font:16px system-ui;margin:32px}a{color:#7fc9f3}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:24px}img{width:100%;border:1px solid #64748b}article{min-width:0}@media(max-width:800px){.grid{grid-template-columns:1fr}}</style><h1>Six dashboard layout design references</h1><p>Labelled reconstructions from compiled QML. Constant bounds only; no actual screenshots.</p><p><a href="START-HERE.md">Handoff guide</a> · <a href="shared-contracts.json">Shared contracts</a> · <a href="asset-manifest.json">Asset manifest</a></p><main class="grid">' + ''.join(pages) + '</main></html>', encoding="utf-8")
    (OUT / "START-HERE.md").write_text("""# Dashboard design handoff

Open `index.html` directly. No server or dependency install required.

- Six layouts: `ui1` through `ui6`.
- Each layout has a concise Markdown guide, a self-contained JSON specification, an SVG schematic, and a PNG schematic.
- `contact-sheet.png` compares all six schematics.
- `shared-contracts.json` defines navigation, data semantics, measurement rules, and reconstruction limits.
- `factory-settings.json` lists all 19 recovered configuration rows without credential values.
- `asset-manifest.json` lists genuine local assets, dimensions, hashes, and unresolved source literals.
- `verification.json` records the generator checks.

## Use with Claude

Provide this whole folder. Start from a selected layout JSON and the shared contracts.
Design a new visual style while preserving the public data, alarm, cruise, limiter, unit, and navigation behavior.
Read every unresolved function before assigning a fixed shape, state, position, or value.
Use the local asset paths. Preserve original asset names and case.
Use one cruise region across all six styles. Preserve distinct available, engaged, set-speed, ACC, and LIM meanings.
Read the unit-preference contract before designing the Units menu. Show manual/follow state and expose the vehicle-follow action.
Expose supported advanced settings through ordinary menu navigation. Keep unsupported entries visible with a clear reason.
Compare all six layouts before consolidating shared visual components.

## Evidence model

Literal values and object hierarchy come from compiled QML.
Branch-free expression text comes from decoder inference.
Resolved bytecode preserves the branch evidence where source reconstruction remains incomplete.
Source line numbers refer to original QML source locations embedded in compiled units.
Component paths identify source evidence, not files that Claude must load from an external device.
Relative asset literals can contain parent segments as historical evidence. Exported asset paths remain inside this folder.

## Measurement

Use declared 1920 × 932 layout coordinates for redesign.
The truck screen measures 1920 × 932, and main.qml draws the dashboard at scale 1, rotation 0, and top 0 (truck model 1, measured 2026-10-30).
The bezel opening has an arched top edge: 0 px hidden at the center, 40 px at x 344 and x 1576, and 99 px at the side edges.
The steering column shroud hides the bottom center: from y 776 between x 572 and x 1348, widening to x 210–1710 at the bottom row.
Schematics shade both hidden areas red. `shared-contracts.json` → `measurement.visible_area` holds the exact points.
Physical check engine and tire pressure lamps sit on the bezel outside the screen. Do not draw duplicates for them.

## Visual limits

Schematics show constant component bounds and labels. Schematics are not actual screenshots.
Runtime branches, native custom controls, loaded image metrics, and live vehicle state remain unresolved where marked.
No gauge sweep or sample vehicle value was invented.
Asset candidates from a dynamic prefix do not imply simultaneous visibility.
Factory, credential, update, private configuration, serial, QR, database, raw capture, and executable files are excluded.
""", encoding="utf-8")
    failures = []
    spec_paths = sorted(OUT.glob("ui[1-6].json"))
    if len(spec_paths) != 6:
        failures.append("Expected six layout JSON files")
    component_count_by_layout = {}
    for path in spec_paths:
        spec = read_json(path)
        component_count_by_layout[spec["layout"]] = len(spec["components"])
        known_assets = {r["path"] for r in spec["assets"]}
        for component_name, rows in spec["asset_dependencies"].items():
            for row in rows:
                for local_path in row["local_assets"]:
                    if local_path not in known_assets or not (OUT / local_path).is_file():
                        failures.append(f"Missing asset reference: {component_name}: {local_path}")
        for component in spec["components"]:
            object_indexes = {o["index"] for o in component["objects"]}
            function_indexes = {f["index"] for f in component["functions"]}
            for obj in component["objects"]:
                for binding in obj["bindings"]:
                    if "object" in binding and binding["object"] not in object_indexes:
                        failures.append("Invalid child object: " + component["component"])
                    if "function" in binding and binding["function"] not in function_indexes:
                        failures.append("Invalid binding function: " + component["component"])
    for path in OUT.glob("*.json"):
        if path.name != "verification.json":
            read_json(path)
    for path in OUT.glob("*.svg"):
        ElementTree.parse(path)
    for row in assets.values():
        path = OUT / row["path"]
        if ".." in Path(row["path"]).parts or not path.resolve().is_relative_to(OUT.resolve()) or not path.is_file() or digest(path) != row["sha256"]:
            failures.append("Invalid asset: " + row["path"])
    for path in OUT.rglob("*"):
        if path.is_file() and path.suffix in {".json", ".md", ".svg", ".html"}:
            text = path.read_text(encoding="utf-8")
            if re.search(r"(?<![A-Za-z])[A-Za-z]:[\\/]|/home/|/Users/|/root/|/mnt/|/media/", text):
                failures.append("Machine path: " + path.relative_to(OUT).as_posix())
            if path.suffix == ".html":
                for link in re.findall(r'(?:src|href)="([^"]+)"', text):
                    target = OUT / link
                    if ".." in Path(link).parts or not target.resolve().is_relative_to(OUT.resolve()) or not target.is_file():
                        failures.append("Invalid gallery link: " + link)
    unexpected_assets = [p.relative_to(OUT).as_posix() for p in (OUT / "assets").rglob("*")
                         if p.is_file() and p.relative_to(OUT).as_posix() not in assets]
    if unexpected_assets:
        failures.append("Untracked asset files: " + str(len(unexpected_assets)))
    verification = {"status": "pass" if not failures else "fail", "command": "python tools/export_layouts.py",
        "layouts": 6, "json_specs": 6, "svg_schematics": 6, "png_schematics": 6,
        "component_definitions": len(selected), "included_assets": len(assets),
        "components_per_layout": component_count_by_layout,
        "unresolved_asset_literals": len(unresolved),
        "checks": ["Six self-contained layout specifications", "JSON parse", "SVG XML parse", "Asset containment and SHA-256",
                   "All per-layout asset references included", "All child objects and binding functions valid",
                   "Gallery links local and valid", "No asset traversal", "No untracked assets",
                   "No machine paths in text exports", "Allowlisted public visual components and image extensions"],
        "failures": failures}
    write_json(OUT / "verification.json", verification)
    print(json.dumps(verification, indent=2))
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
