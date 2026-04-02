#!/usr/bin/env python3
import difflib
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
    "/Users/fxaleman03gmail.com/Library/CloudStorage/OneDrive-Personal/3- IFA AYAKO/1-FAMILY EJIOGBE/2- OGBE YEKU.docx"
)
ASSET_PATH = ROOT / "assets/odu_content_patched.json"
BUILD_JSON_PATH = ROOT / "build/odu_content_patched.json"

REPORT_MD = ROOT / "build/ogbe_yeku_rebuild_report.md"
DIFF_MD = ROOT / "build/ogbe_yeku_rebuild_diff.md"
SUMMARY_JSON = ROOT / "build/ogbe_yeku_rebuild_summary.json"

TARGET_KEY = "OGBE YEKU"
EXPECTED_MAIN_NAME = "OGBE YEKU"
EXPECTED_ALIASES = ["EJIOGBE OYEKUN", "OGBE OYEKUN"]

SECTION_LABELS = [
    "REZO",
    "SUYERE",
    "EN ESTE ODU NACE",
    "DESCRIPCIÓN DEL ODU",
    "PREDICCIONES DEL ODU",
    "ESTE ODU PROHIBE",
    "ESTE ODU RECOMIENDA",
    "OBRAS DEL ODU",
    "DICE IFÁ / DICE IFA",
    "EWES DEL ODU",
    "REFRANES DEL ODU",
    "ESHU-ELEGBA DEL ODU",
    "HISTORIAS O PATAKINES DEL ODU",
]

JSON_FIELD_BY_SECTION = {
    "REZO": "rezoYoruba",
    "SUYERE": "suyereYoruba",
    "EN ESTE ODU NACE": "nace",
    "DESCRIPCIÓN DEL ODU": "descripcion",
    "PREDICCIONES DEL ODU": "predicciones",
    "ESTE ODU PROHIBE": "prohibiciones",
    "ESTE ODU RECOMIENDA": "recomendaciones",
    "OBRAS DEL ODU": "obras",
    "DICE IFÁ / DICE IFA": "diceIfa",
    "EWES DEL ODU": "ewes",
    "REFRANES DEL ODU": "refranes",
    "ESHU-ELEGBA DEL ODU": "eshu",
    "HISTORIAS O PATAKINES DEL ODU": "historiasYPatakies",
}

ALL_REBUILT_FIELDS = [
    "rezoYoruba",
    "suyereYoruba",
    "nace",
    "descripcion",
    "predicciones",
    "prohibiciones",
    "recomendaciones",
    "obras",
    "diceIfa",
    "ewes",
    "refranes",
    "eshu",
    "historiasYPatakies",
]

MISSING_REQUIRED_FIELDS = [
    "predicciones",
    "prohibiciones",
    "recomendaciones",
    "obras",
    "diceIfa",
    "ewes",
    "historiasYPatakies",
]


def fold(value: str) -> str:
    text = value or ""
    text = "".join(
        ch
        for ch in unicodedata.normalize("NFD", text)
        if unicodedata.category(ch) != "Mn"
    )
    text = text.upper().strip()
    text = re.sub(r"\s+", " ", text)
    return text


def detect_section_heading(raw_line: str) -> Tuple[Optional[str], str]:
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

    if re.match(r"^EN ESTE ODU NACE\.?\s*:?\s*$", f):
        return "EN ESTE ODU NACE", ""
    if re.match(r"^DESCRIPCION DEL ODU\b.*$", f):
        return "DESCRIPCIÓN DEL ODU", ""
    if re.match(r"^PREDICCIONES DEL ODU\b.*$", f):
        return "PREDICCIONES DEL ODU", ""
    if re.match(r"^ADVERTENCIAS\s*:?\s*$", f):
        return "PREDICCIONES DEL ODU", ""
    if re.match(r"^ESTE ODU PROHIBE\b.*$", f) or re.match(
        r"^PROHIBICIONES DEL ODU\b.*$", f
    ):
        return "ESTE ODU PROHIBE", ""
    if re.match(r"^ESTE ODU RECOMIENDA\b.*$", f) or re.match(
        r"^RECOMENDACIONES\s*:?\s*$", f
    ):
        return "ESTE ODU RECOMIENDA", ""
    if re.match(r"^OBRAS DEL ODU\b.*$", f) or re.match(r"^OBRAS\s*:\s*$", f) or re.match(
        r"^RELACION DE OBRAS DEL ODU\b.*$", f
    ):
        return "OBRAS DEL ODU", ""
    if re.match(r"^DICE IFA\b.*$", f):
        return "DICE IFÁ / DICE IFA", ""
    if re.match(r"^EWES DEL ODU\b.*$", f) or re.match(r"^HIERBA DEL ODU\b.*$", f):
        return "EWES DEL ODU", ""
    if re.match(r"^REFRANES DEL ODU\b.*$", f) or re.match(
        r"^REFRANES\s*:?\s*$", f
    ):
        return "REFRANES DEL ODU", ""
    if re.match(r"^ESHU[\s\-–—]*ELEGBA DEL ODU\b.*$", f) or re.match(
        r"^ESHU DEL ODU\b.*$", f
    ):
        return "ESHU-ELEGBA DEL ODU", ""
    if re.match(r"^HISTORIAS O PATAKINES DEL ODU\b.*$", f) or re.match(
        r"^RELACION DE ESES O HISTORIAS\b.*$", f
    ):
        return "HISTORIAS O PATAKINES DEL ODU", ""

    return None, ""


def parse_docx_sections(text: str) -> Dict:
    lines = text.splitlines()
    pre_section_header_lines: List[str] = []
    blocks_by_section: Dict[str, List[str]] = {label: [] for label in SECTION_LABELS}

    saw_first_section = False
    histories_started = False
    current_section: Optional[str] = None
    current_lines: List[str] = []

    def flush() -> None:
        nonlocal current_section, current_lines
        if current_section is not None:
            content = "\n".join(current_lines).strip()
            if content:
                blocks_by_section[current_section].append(content)
        current_section = None
        current_lines = []

    for line in lines:
        section, inline = detect_section_heading(line)
        if section is not None:
            # Keep the remainder of the document as historias content once that
            # top-level heading starts, avoiding false positives from story text.
            if histories_started and section != "HISTORIAS O PATAKINES DEL ODU":
                if current_section is not None:
                    current_lines.append(line.rstrip())
                continue

            saw_first_section = True
            flush()
            current_section = section
            current_lines = []
            if inline:
                current_lines.append(inline)
            if section == "HISTORIAS O PATAKINES DEL ODU":
                histories_started = True
            continue

        if not saw_first_section:
            if line.strip():
                pre_section_header_lines.append(line.strip())
            continue

        if current_section is not None:
            current_lines.append(line.rstrip())

    flush()

    main_name = pre_section_header_lines[0] if pre_section_header_lines else ""
    aliases = pre_section_header_lines[1:] if len(pre_section_header_lines) > 1 else []

    combined_by_section = {}
    for section, blocks in blocks_by_section.items():
        combined_by_section[section] = "\n\n".join(blocks).strip() if blocks else ""

    return {
        "main_name": main_name,
        "aliases": aliases,
        "blocks_by_section": blocks_by_section,
        "combined_by_section": combined_by_section,
    }


def read_docx_text(docx_path: Path) -> str:
    if not docx_path.exists():
        raise RuntimeError(f"DOCX not found at fixed path: {docx_path}")
    cmd = ["textutil", "-convert", "txt", "-stdout", str(docx_path)]
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        raise RuntimeError(
            f"textutil failed ({result.returncode}): {result.stderr.strip()}"
        )
    return result.stdout


def ensure_single_target(data: Dict) -> None:
    odu = data.get("odu")
    if not isinstance(odu, dict):
        raise RuntimeError("Invalid schema: missing odu object.")
    if TARGET_KEY not in odu:
        raise RuntimeError(f"Target key not found: {TARGET_KEY}")


def get_text(content: Dict, field: str) -> str:
    value = content.get(field, "")
    return value if isinstance(value, str) else ""


def has_token(text: str, token: str) -> bool:
    return fold(token) in fold(text)


def make_reports(
    backup_path: Path,
    before_content: Dict,
    after_content: Dict,
    parsed: Dict,
) -> Dict:
    per_section = []
    for section in SECTION_LABELS:
        field = JSON_FIELD_BY_SECTION[section]
        before_text = get_text(before_content, field)
        after_text = get_text(after_content, field)
        per_section.append(
            {
                "section": section,
                "field": field,
                "before_len": len(before_text),
                "after_len": len(after_text),
                "changed": before_text != after_text,
                "docx_block_count": len(parsed["blocks_by_section"].get(section, [])),
                "docx_present": bool(parsed["blocks_by_section"].get(section, [])),
            }
        )

    changed_sections = [item["field"] for item in per_section if item["changed"]]
    alias_stored = bool(get_text(after_content, "mainName")) and isinstance(
        after_content.get("aliases"), list
    )

    # "Added" means the fields are now guaranteed as explicit template fields.
    missing_sections_added = all(field in after_content for field in MISSING_REQUIRED_FIELDS)
    missing_sections_non_empty = all(
        bool(get_text(after_content, field).strip()) for field in MISSING_REQUIRED_FIELDS
    )

    nace_text = get_text(after_content, "nace")
    refranes_text = get_text(after_content, "refranes")
    obras_text = get_text(after_content, "obras")
    obras_legacy = get_text(after_content, "obrasYEbbo")

    nace_clean = all(
        not has_token(nace_text, token)
        for token in ["PROHIBICIONES DEL ODU", "RECOMENDACIONES", "ADVERTENCIAS"]
    )
    refranes_clean = all(
        not has_token(refranes_text, token)
        for token in ["HIERBA DEL ODU", "OBRAS:", "RELACION DE OBRAS DEL ODU"]
    )
    legacy_obras_clean = obras_legacy == obras_text
    misplaced_cleaned = nace_clean and refranes_clean and legacy_obras_clean

    summary = {
        "target_odu_key": TARGET_KEY,
        "source_file_used": str(DOCX_PATH),
        "backup_path": str(backup_path),
        "main_name_extracted": parsed["main_name"],
        "aliases_extracted": parsed["aliases"],
        "main_name_stored": EXPECTED_MAIN_NAME,
        "aliases_stored": EXPECTED_ALIASES,
        "sections_rebuilt": ALL_REBUILT_FIELDS,
        "changed_sections": changed_sections,
        "alias_structure_stored": alias_stored,
        "alias_storage_details": {
            "main_name_field": "content.mainName" if alias_stored else None,
            "aliases_field": "content.aliases" if alias_stored else None,
            "name_field_preserved": "content.name",
        },
        "missing_sections_required": MISSING_REQUIRED_FIELDS,
        "missing_sections_added": missing_sections_added,
        "missing_sections_non_empty": missing_sections_non_empty,
        "misplaced_content_cleaned": misplaced_cleaned,
        "misplaced_clean_checks": {
            "nace_has_no_prohibiciones_recomendaciones_advertencias": nace_clean,
            "refranes_has_no_ewes_or_obras": refranes_clean,
            "legacy_obrasYEbbo_synced_to_obras": legacy_obras_clean,
        },
        "per_section_lengths": per_section,
    }
    SUMMARY_JSON.write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    report_lines = [
        "# OGBE YEKU Rebuild Report",
        "",
        f"- Target odù key: `{TARGET_KEY}`",
        f"- Source file used: `{DOCX_PATH}`",
        f"- Backup created: `{backup_path}`",
        f"- Main name extracted: `{parsed['main_name']}`",
        f"- Aliases extracted: `{parsed['aliases']}`",
        f"- Main name stored: `{EXPECTED_MAIN_NAME}`",
        f"- Aliases stored: `{EXPECTED_ALIASES}`",
        f"- Sections rebuilt: `{ALL_REBUILT_FIELDS}`",
        f"- Alias structure stored: `{'YES' if alias_stored else 'NO'}`",
        "- Alias storage method: `content.mainName` + `content.aliases` (with `content.name` preserved for UI behavior)",
        "- Missing sections required: "
        f"`{MISSING_REQUIRED_FIELDS}`",
        f"- Missing sections added (fields present): `{'YES' if missing_sections_added else 'NO'}`",
        f"- Missing sections non-empty: `{'YES' if missing_sections_non_empty else 'NO'}`",
        f"- Misplaced content cleaned: `{'YES' if misplaced_cleaned else 'NO'}`",
        "",
        "## Per-Section Lengths",
    ]
    for item in per_section:
        report_lines.append(
            f"- {item['section']} ({item['field']}): {item['before_len']} -> {item['after_len']} | changed={str(item['changed']).lower()} | docx_blocks={item['docx_block_count']}"
        )
    REPORT_MD.write_text("\n".join(report_lines) + "\n", encoding="utf-8")

    diff_lines = [
        "# OGBE YEKU Rebuild Diff (before/after snippets)",
        "",
    ]
    for section in SECTION_LABELS:
        field = JSON_FIELD_BY_SECTION[section]
        before_text = get_text(before_content, field)
        after_text = get_text(after_content, field)
        diff_lines.append(f"## {section} (`{field}`)")
        diff_lines.append(f"- before_len={len(before_text)}")
        diff_lines.append(f"- after_len={len(after_text)}")
        diff_lines.append("")
        before_lines = before_text.splitlines()[:80]
        after_lines = after_text.splitlines()[:80]
        unified = list(
            difflib.unified_diff(
                before_lines,
                after_lines,
                fromfile="before",
                tofile="after",
                lineterm="",
            )
        )
        if not unified:
            diff_lines.append("_No changes_")
        else:
            diff_lines.append("```diff")
            diff_lines.extend(unified[:260])
            diff_lines.append("```")
        diff_lines.append("")
    DIFF_MD.write_text("\n".join(diff_lines), encoding="utf-8")

    return summary


def main() -> None:
    source_text = read_docx_text(DOCX_PATH)
    parsed = parse_docx_sections(source_text)

    data = json.loads(ASSET_PATH.read_text(encoding="utf-8"))
    ensure_single_target(data)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = ASSET_PATH.with_name(
        f"odu_content_patched.json.bak_ogbe_yeku_rebuild_{timestamp}"
    )
    shutil.copy2(ASSET_PATH, backup_path)

    odu = data["odu"]
    entry = odu[TARGET_KEY]
    if not isinstance(entry, dict):
        raise RuntimeError(f"Invalid entry format for {TARGET_KEY}")
    content = entry.get("content")
    if not isinstance(content, dict):
        raise RuntimeError(f"Invalid content format for {TARGET_KEY}")

    before_content = json.loads(json.dumps(content, ensure_ascii=False))

    for section, field in JSON_FIELD_BY_SECTION.items():
        content[field] = parsed["combined_by_section"].get(section, "")

    # Keep visible display name behavior unchanged.
    if "name" not in content or not isinstance(content.get("name"), str):
        content["name"] = TARGET_KEY
    content["mainName"] = EXPECTED_MAIN_NAME
    content["aliases"] = EXPECTED_ALIASES

    # Keep legacy fields in sync with rebuilt sections used by current UI.
    content["obrasYEbbo"] = get_text(content, "obras")
    merged_rezos = "\n\n".join(
        [part for part in [get_text(content, "rezoYoruba"), get_text(content, "suyereYoruba")] if part.strip()]
    )
    content["rezosYSuyeres"] = merged_rezos
    if "suyereEspanol" not in content or not isinstance(content.get("suyereEspanol"), str):
        content["suyereEspanol"] = ""

    after_content = json.loads(json.dumps(content, ensure_ascii=False))

    # Guardrail: exactly one odù entry changed.
    original_all = json.loads(backup_path.read_text(encoding="utf-8"))
    changed_keys = []
    for key in data.get("odu", {}):
        before = original_all.get("odu", {}).get(key)
        after = data.get("odu", {}).get(key)
        if before != after:
            changed_keys.append(key)
    if changed_keys != [TARGET_KEY]:
        raise RuntimeError(
            f"Safety check failed: changed keys={changed_keys}, expected only [{TARGET_KEY}]"
        )

    BUILD_JSON_PATH.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    shutil.copy2(BUILD_JSON_PATH, ASSET_PATH)

    summary = make_reports(
        backup_path=backup_path,
        before_content=before_content,
        after_content=after_content,
        parsed=parsed,
    )

    print("target_odu_key:", summary["target_odu_key"])
    print("sections_rebuilt:", summary["sections_rebuilt"])
    print("alias_stored:", "YES" if summary["alias_structure_stored"] else "NO")
    print(
        "missing_sections_added:",
        "YES" if summary["missing_sections_added"] else "NO",
    )
    print(
        "misplaced_content_cleaned:",
        "YES" if summary["misplaced_content_cleaned"] else "NO",
    )


if __name__ == "__main__":
    main()
