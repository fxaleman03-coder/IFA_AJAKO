#!/usr/bin/env python3
import json
import re
import shutil
import subprocess
import unicodedata
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

ROOT = Path(__file__).resolve().parents[1]

DOCX_PATH = Path(
    "/Users/fxaleman03gmail.com/Library/CloudStorage/OneDrive-Personal/3- IFA AYAKO/1-FAMILY EJIOGBE/3- OGBE WEÑE.docx"
)
ASSET_PATH = ROOT / "assets/odu_content_patched.json"
BUILD_JSON_PATH = ROOT / "build/odu_content_patched.json"

REPORT_MD = ROOT / "build/ogbe_wene_template_rebuild_report.md"
SUMMARY_JSON = ROOT / "build/ogbe_wene_template_rebuild_summary.json"

TARGET_KEY = "OGBE WEÑE"

TEMPLATE_ORDER: List[Tuple[str, str]] = [
    ("DESCRIPCIÓN", "descripcion"),
    ("REZO", "rezoYoruba"),
    ("SUYERE", "suyereYoruba"),
    ("EN ESTE ODU NACE", "nace"),
    ("PREDICCIONES", "predicciones"),
    ("PROHIBE", "prohibiciones"),
    ("RECOMIENDA", "recomendaciones"),
    ("OBRAS", "obras"),
    ("DICE IFÁ", "diceIfa"),
    ("EWES", "ewes"),
    ("REFRANES", "refranes"),
    ("ESHU", "eshu"),
    ("HISTORIAS", "historiasYPatakies"),
]

SECTION_KEY_TO_FIELD = {k: v for k, v in TEMPLATE_ORDER}


def fold(text: str) -> str:
    text = text or ""
    text = "".join(
        ch
        for ch in unicodedata.normalize("NFD", text)
        if unicodedata.category(ch) != "Mn"
    )
    text = text.upper().strip()
    text = re.sub(r"\s+", " ", text)
    return text


def detect_heading(raw_line: str) -> Tuple[Optional[str], str]:
    raw = raw_line.strip()
    if not raw:
        return None, ""

    m = re.match(r"^REZO\s*:?\s*(.*)$", raw, re.IGNORECASE)
    if m:
        return "REZO", (m.group(1) or "").strip()

    m = re.match(r"^SUYERE\s*:?\s*(.*)$", raw, re.IGNORECASE)
    if m:
        return "SUYERE", (m.group(1) or "").strip()

    f = fold(raw)
    if re.match(r"^EN ESTE ODU NACE\.?\s*:?.*$", f):
        return "EN ESTE ODU NACE", ""
    if re.match(r"^DESCRIPCION DEL ODU\b.*$", f):
        return "DESCRIPCIÓN", ""
    if re.match(r"^PREDICCIONES DEL ODU\b.*$", f):
        return "PREDICCIONES", ""
    if re.match(r"^ADVERTENCIAS\s*:?.*$", f):
        return "PREDICCIONES", ""
    if re.match(r"^ESTE ODU PROHIBE\b.*$", f) or re.match(
        r"^PROHIBICIONES DEL ODU\b.*$", f
    ):
        return "PROHIBE", ""
    if re.match(r"^ESTE ODU RECOMIENDA\b.*$", f) or re.match(
        r"^RECOMENDACIONES\s*:?.*$", f
    ):
        return "RECOMIENDA", ""
    if re.match(r"^OBRAS DEL ODU\b.*$", f) or re.match(
        r"^RELACION DE OBRAS DEL ODU\b.*$", f
    ) or re.match(r"^RELACION DEL OBRAS DEL ODU\b.*$", f) or re.match(
        r"^OBRAS\s*:\s*$", f
    ):
        return "OBRAS", ""
    if re.match(r"^DICE IFA\s*:?.*$", f):
        # Avoid prose lines such as "DICE IFA QUE ..."
        tail = re.sub(r"^DICE IFA\s*:?", "", f).strip()
        if tail and len(tail.split()) > 2:
            return None, ""
        return "DICE IFÁ", ""
    if re.match(r"^EWES DEL ODU\b.*$", f) or re.match(
        r"^HIERBAS? DEL ODU\s*:?.*$", f
    ):
        return "EWES", ""
    if re.match(r"^REFRANES DEL ODU\b.*$", f) or re.match(r"^REFRANES\s*:?.*$", f):
        return "REFRANES", ""
    if re.match(r"^ESHU[\s\-–—]*ELEGBA DEL ODU\b.*$", f) or re.match(
        r"^ESHU DEL ODU\b.*$", f
    ) or re.match(r"^ESHU DE\b.*$", f):
        return "ESHU", ""
    if re.match(r"^HISTORIAS O PATAKINES DEL ODU\b.*$", f) or re.match(
        r"^RELACION DE ESES O HISTORIAS DEL ODU\b.*$", f
    ) or re.match(r"^RELACION DE ESES O HISTORIAS\b.*$", f):
        return "HISTORIAS", ""
    return None, ""


def read_docx_text(path: Path) -> str:
    if not path.exists():
        raise RuntimeError(f"DOCX not found: {path}")
    result = subprocess.run(
        ["textutil", "-convert", "txt", "-stdout", str(path)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"textutil failed ({result.returncode}): {result.stderr.strip()}"
        )
    return result.stdout


def parse_docx(text: str) -> Dict:
    lines = text.splitlines()
    header_lines: List[str] = []
    blocks: Dict[str, List[str]] = {k: [] for k, _ in TEMPLATE_ORDER}

    saw_first_heading = False
    histories_started = False
    current_section: Optional[str] = None
    current_lines: List[str] = []

    def flush() -> None:
        nonlocal current_section, current_lines
        if current_section is not None:
            content = "\n".join(current_lines).strip()
            if content:
                blocks[current_section].append(content)
        current_section = None
        current_lines = []

    for raw in lines:
        section, inline = detect_heading(raw)
        if section is not None:
            if histories_started and section != "HISTORIAS":
                if current_section is not None:
                    current_lines.append(raw.rstrip())
                continue
            saw_first_heading = True
            flush()
            current_section = section
            current_lines = []
            if inline:
                current_lines.append(inline)
            if section == "HISTORIAS":
                histories_started = True
            continue

        if not saw_first_heading:
            if raw.strip():
                header_lines.append(raw.strip())
            continue

        if current_section is not None:
            current_lines.append(raw.rstrip())

    flush()

    combined = {k: "\n\n".join(v).strip() if v else "" for k, v in blocks.items()}
    main_name = header_lines[0] if header_lines else ""
    aliases = header_lines[1:] if len(header_lines) > 1 else []
    return {
        "main_name": main_name,
        "aliases": aliases,
        "blocks": blocks,
        "combined": combined,
    }


def extract_existing_description_header(existing_descripcion: str) -> str:
    for line in existing_descripcion.splitlines():
        t = line.strip()
        if not t:
            continue
        if re.match(r"^ESTE ES EL ODU # .+ DEL ORDEN SENORIAL DE IFA\.$", fold(t)):
            return t
    return ""


def strip_header_from_description_body(text: str) -> str:
    lines = text.splitlines()
    out = list(lines)
    while out and not out[0].strip():
        out.pop(0)
    if out:
        first = out[0].strip()
        if re.match(r"^ESTE ES EL ODU # .+ DEL ORDEN SENORIAL DE IFA\.$", fold(first)):
            out = out[1:]
            while out and not out[0].strip():
                out.pop(0)
    return "\n".join(out).strip()


def split_prohibiciones_from_nace(nace_text: str) -> Tuple[str, str]:
    if not nace_text.strip():
        return nace_text, ""
    nace_lines = nace_text.splitlines()
    keep: List[str] = []
    prohibe: List[str] = []
    for line in nace_lines:
        f = fold(line.strip())
        if not f:
            if keep and keep[-1] != "":
                keep.append("")
            elif prohibe and prohibe[-1] != "":
                prohibe.append("")
            continue
        if (
            f.startswith("PROHIBE ")
            or f.startswith("PROHIBE")
            or f.startswith("NO SE PUEDE ")
            or f.startswith("NO PUEDE ")
        ):
            prohibe.append(line.rstrip())
        else:
            keep.append(line.rstrip())
    return "\n".join(keep).strip(), "\n".join(prohibe).strip()


def split_dice_ifa_from_recomienda(recomienda_text: str) -> Tuple[str, str]:
    if not recomienda_text.strip():
        return recomienda_text, ""
    lines = recomienda_text.splitlines()
    idx = None
    for i, line in enumerate(lines):
        if fold(line).startswith("DICE IFA"):
            idx = i
            break
    if idx is None:
        return recomienda_text.strip(), ""
    rec = "\n".join(lines[:idx]).strip()
    dice = "\n".join(lines[idx:]).strip()
    return rec, dice


def ensure_one_target_changed(before: Dict, after: Dict) -> None:
    changed = []
    for key in after.get("odu", {}):
        if before.get("odu", {}).get(key) != after.get("odu", {}).get(key):
            changed.append(key)
    if changed != [TARGET_KEY]:
        raise RuntimeError(
            f"Safety check failed. Changed keys={changed}; expected only [{TARGET_KEY}]"
        )


def main() -> None:
    parsed = parse_docx(read_docx_text(DOCX_PATH))

    data = json.loads(ASSET_PATH.read_text(encoding="utf-8"))
    if not isinstance(data.get("odu"), dict) or TARGET_KEY not in data["odu"]:
        raise RuntimeError(f"Target key not found in patched corpus: {TARGET_KEY}")

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = ASSET_PATH.with_name(f"odu_content_patched.json.bak_ogbe_wene_template_rebuild_{ts}")
    shutil.copy2(ASSET_PATH, backup_path)

    entry = data["odu"][TARGET_KEY]
    if not isinstance(entry, dict) or not isinstance(entry.get("content"), dict):
        raise RuntimeError(f"Invalid content entry for {TARGET_KEY}")
    content = entry["content"]
    before_content = json.loads(json.dumps(content, ensure_ascii=False))

    # Parse raw section text first.
    raw_by_field = {field: parsed["combined"].get(sec, "") for sec, field in TEMPLATE_ORDER}

    # Official header preservation for descripcion.
    existing_header = extract_existing_description_header(
        before_content.get("descripcion", "") if isinstance(before_content.get("descripcion"), str) else ""
    )
    if not existing_header:
        # Fallback to current parsed header style if source already contains it.
        existing_header = "ESTE ES EL ODU # X DEL ORDEN SEÑORIAL DE IFÁ."

    desc_body = strip_header_from_description_body(raw_by_field["descripcion"])
    if desc_body:
        descripcion_final = f"{existing_header}\n{desc_body}"
    else:
        descripcion_final = existing_header

    # REZO special rule: principal Odù rezos only (already limited to top-level section);
    # remove obvious Eshu-only block if any.
    rezo_blocks = parsed["blocks"].get("REZO", [])
    rezo_kept = []
    for blk in rezo_blocks:
        fb = fold(blk)
        if "ESHU" in fb and "OGBE" not in fb:
            continue
        rezo_kept.append(blk.strip())
    rezo_final = "\n\n".join([b for b in rezo_kept if b]).strip()

    # SUYERE: keep only explicit suyeres; if none, empty.
    suyere_final = raw_by_field["suyereYoruba"].strip()

    # NACE + PROHIBE cleanup if needed.
    nace_final = raw_by_field["nace"].strip()
    prohibe_final = raw_by_field["prohibiciones"].strip()
    if not prohibe_final:
        nace_final, prohibe_from_nace = split_prohibiciones_from_nace(nace_final)
        prohibe_final = prohibe_from_nace

    pred_final = raw_by_field["predicciones"].strip()
    recomienda_final = raw_by_field["recomendaciones"].strip()
    obras_final = raw_by_field["obras"].strip()
    dice_final = raw_by_field["diceIfa"].strip()

    # If no explicit DICE IFÁ heading, split from RECOMIENDA marker line.
    if not dice_final:
        recomienda_final, dice_from_rec = split_dice_ifa_from_recomienda(recomienda_final)
        dice_final = dice_from_rec

    ewes_final = raw_by_field["ewes"].strip()
    refranes_final = raw_by_field["refranes"].strip()
    eshu_final = raw_by_field["eshu"].strip()
    historias_final = raw_by_field["historiasYPatakies"].strip()

    rebuilt_values = {
        "descripcion": descripcion_final,
        "rezoYoruba": rezo_final,
        "suyereYoruba": suyere_final,
        "nace": nace_final,
        "predicciones": pred_final,
        "prohibiciones": prohibe_final,
        "recomendaciones": recomienda_final,
        "obras": obras_final,
        "diceIfa": dice_final,
        "ewes": ewes_final,
        "refranes": refranes_final,
        "eshu": eshu_final,
        "historiasYPatakies": historias_final,
    }

    rebuilt_fields_in_order: List[str] = []
    for _, field in TEMPLATE_ORDER:
        content[field] = rebuilt_values[field]
        rebuilt_fields_in_order.append(field)

    # Preserve visible display name behavior and store alias structure.
    if "name" not in content or not isinstance(content.get("name"), str):
        content["name"] = TARGET_KEY
    content["mainName"] = parsed["main_name"] if parsed["main_name"] else TARGET_KEY
    content["aliases"] = parsed["aliases"]

    # Keep legacy fields synchronized with current UI usage.
    content["obrasYEbbo"] = content.get("obras", "")
    merged_rezos = "\n\n".join(
        [
            p
            for p in [content.get("rezoYoruba", ""), content.get("suyereYoruba", "")]
            if isinstance(p, str) and p.strip()
        ]
    )
    content["rezosYSuyeres"] = merged_rezos
    if "suyereEspanol" not in content or not isinstance(content.get("suyereEspanol"), str):
        content["suyereEspanol"] = ""

    after_content = json.loads(json.dumps(content, ensure_ascii=False))

    # Safety: exactly one Odù changed.
    original_all = json.loads(backup_path.read_text(encoding="utf-8"))
    ensure_one_target_changed(original_all, data)

    BUILD_JSON_PATH.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    shutil.copy2(BUILD_JSON_PATH, ASSET_PATH)

    header_preserved = after_content.get("descripcion", "").startswith(existing_header)
    alias_stored = bool(after_content.get("mainName")) and isinstance(
        after_content.get("aliases"), list
    )
    template_order_respected = rebuilt_fields_in_order == [f for _, f in TEMPLATE_ORDER]

    per_section_lengths = []
    for _, field in TEMPLATE_ORDER:
        b = before_content.get(field, "")
        a = after_content.get(field, "")
        before_len = len(b) if isinstance(b, str) else 0
        after_len = len(a) if isinstance(a, str) else 0
        per_section_lengths.append(
            {
                "field": field,
                "before_len": before_len,
                "after_len": after_len,
                "changed": before_len != after_len or (b != a),
            }
        )

    summary = {
        "target_odu_key": TARGET_KEY,
        "source_file_used": str(DOCX_PATH),
        "backup_path": str(backup_path),
        "main_name_extracted": parsed["main_name"],
        "aliases_extracted": parsed["aliases"],
        "header_preserved": header_preserved,
        "header_line": existing_header,
        "sections_rebuilt": [f for _, f in TEMPLATE_ORDER],
        "alias_stored": alias_stored,
        "template_order_respected": template_order_respected,
        "per_section_lengths": per_section_lengths,
    }
    SUMMARY_JSON.write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    report_lines = [
        "# OGBE WEÑE Template Rebuild Report",
        "",
        f"- Target odù key: `{TARGET_KEY}`",
        f"- Source file used: `{DOCX_PATH}`",
        f"- Backup created: `{backup_path}`",
        f"- Main name extracted: `{parsed['main_name']}`",
        f"- Aliases extracted: `{parsed['aliases']}`",
        f"- Header preserved: `{'YES' if header_preserved else 'NO'}`",
        f"- Header line: `{existing_header}`",
        f"- Sections rebuilt: `{[f for _, f in TEMPLATE_ORDER]}`",
        f"- Alias stored: `{'YES' if alias_stored else 'NO'}`",
        f"- Template order respected: `{'YES' if template_order_respected else 'NO'}`",
        "",
        "## Per-section lengths (before -> after)",
    ]
    for item in per_section_lengths:
        report_lines.append(
            f"- `{item['field']}`: {item['before_len']} -> {item['after_len']} | changed={str(item['changed']).lower()}"
        )
    REPORT_MD.write_text("\n".join(report_lines) + "\n", encoding="utf-8")

    print("target odu key =", TARGET_KEY)
    print("header preserved =", "YES" if header_preserved else "NO")
    print("sections rebuilt =", [f for _, f in TEMPLATE_ORDER])
    print("alias stored =", "YES" if alias_stored else "NO")
    print("template order respected =", "YES" if template_order_respected else "NO")


if __name__ == "__main__":
    main()
