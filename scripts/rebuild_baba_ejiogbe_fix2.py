#!/usr/bin/env python3
import difflib
import json
import re
import shutil
import subprocess
import unicodedata
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Union

ROOT = Path(__file__).resolve().parents[1]

DOCX_PATH = Path(
    "/Users/fxaleman03gmail.com/Library/CloudStorage/OneDrive-Personal/3- IFA AYAKO/1-BABA EJIOGBE/1- EJIOGBE.dcx.docx"
)
ASSET_PATH = ROOT / "assets/odu_content_patched.json"
BUILD_JSON = ROOT / "build/odu_content_patched.json"

REPORT_MD = ROOT / "build/baba_ejiogbe_rebuild_fix2_report.md"
DIFF_MD = ROOT / "build/baba_ejiogbe_rebuild_fix2_diff.md"
SUMMARY_JSON = ROOT / "build/baba_ejiogbe_rebuild_fix2_summary.json"

TARGET_KEY = "BABA OGBE"

SECTION_TO_FIELD = {
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

REBUILD_FIELDS = [
    "rezoYoruba",
    "suyereYoruba",
    "eshu",
    "descripcion",
    "predicciones",
    "prohibiciones",
    "recomendaciones",
    "historiasYPatakies",
    "nace",
    "obras",
    "diceIfa",
    "ewes",
    "refranes",
]

HEADING_PATTERNS = {
    "EN ESTE ODU NACE": re.compile(r"^\s*EN\s+ESTE\s+ODU\s+NACE\s*:?\s*$", re.I),
    "DESCRIPCIÓN DEL ODU": re.compile(r"^\s*DESCRIPCI[ÓO]N\s+DEL\s+ODU\b.*$", re.I),
    "PREDICCIONES DEL ODU": re.compile(r"^\s*PREDICCIONES\s+DEL\s+ODU\b.*$", re.I),
    "ESTE ODU PROHIBE": re.compile(r"^\s*ESTE\s+ODU\s+PROHIBE\b.*$", re.I),
    "ESTE ODU RECOMIENDA": re.compile(r"^\s*ESTE\s+ODU\s+RECOMIENDA\b.*$", re.I),
    "OBRAS DEL ODU": re.compile(
        r"^\s*(?:RELACI[ÓO]N\s+DE\s+)?OBRAS\s+DEL\s+ODU\b.*$",
        re.I,
    ),
    "DICE IFÁ / DICE IFA": re.compile(r"^\s*DICE\s+IF[ÁA]\.?\s*$", re.I),
    "EWES DEL ODU": re.compile(r"^\s*EWES\s+DEL\s+ODU\s*:?\s*$", re.I),
    "REFRANES DEL ODU": re.compile(r"^\s*REFRANES\s+DEL\s+ODU\s*:?\s*$", re.I),
    "ESHU-ELEGBA DEL ODU": re.compile(
        r"^\s*ESHU[\s\-–—]*ELEGBA\s+DEL\s+ODU\b.*$",
        re.I,
    ),
    "HISTORIAS O PATAKINES DEL ODU": re.compile(
        r"^\s*(?:RELACI[ÓO]N\s+DE\s+)?HISTORIAS\s+O\s+PATAKINES\s+DEL\s+ODU\b.*$",
        re.I,
    ),
}

REZO_HEADING = re.compile(r"^\s*REZO\s*:\s*(.*)$", re.I)
SUYERE_HEADING = re.compile(r"^\s*SUYERE\s*:\s*(.*)$", re.I)


def _fold(text: str) -> str:
    text = text or ""
    text = "".join(
        ch for ch in unicodedata.normalize("NFD", text) if unicodedata.category(ch) != "Mn"
    )
    text = text.upper()
    text = re.sub(r"\s+", " ", text).strip()
    return text


def _contains(haystack: str, needle: str) -> bool:
    return _fold(needle) in _fold(haystack)


def _starts_with(haystack: str, needle: str) -> bool:
    return _fold(haystack).startswith(_fold(needle))


def _extract_text_from_docx(path: Path) -> str:
    if not path.exists():
        raise RuntimeError(f"Source DOCX not found: {path}")
    result = subprocess.run(
        ["textutil", "-convert", "txt", "-stdout", str(path)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(f"textutil failed: {result.stderr.strip()}")
    return result.stdout


def _first_heading_index(lines: List[str], heading: str) -> Optional[int]:
    pat = HEADING_PATTERNS[heading]
    for i, line in enumerate(lines):
        if pat.match(line or ""):
            return i
    return None


def _first_any_section_index(lines: List[str]) -> int:
    for i, line in enumerate(lines):
        if REZO_HEADING.match(line or "") or SUYERE_HEADING.match(line or ""):
            return i
        if _match_major_heading(line or "") is not None:
            return i
    return len(lines)


def _parse_header(lines: List[str], stop_idx: int) -> Dict[str, Union[List[str], str]]:
    pre = [ln.strip() for ln in lines[:stop_idx] if ln.strip()]
    main_name = pre[0] if pre else ""
    aliases = pre[1:] if len(pre) > 1 else []
    return {"main_name": main_name, "aliases": aliases}


def _extract_principal_rezo_suyere(lines: List[str], nace_idx: int) -> Dict[str, List[str]]:
    rezo_blocks: List[str] = []
    suyere_blocks: List[str] = []
    i = 0
    while i < nace_idx:
        line = lines[i]
        m_rezo = REZO_HEADING.match(line or "")
        m_suy = SUYERE_HEADING.match(line or "")
        if not (m_rezo or m_suy):
            i += 1
            continue

        section = "REZO" if m_rezo else "SUYERE"
        inline = (m_rezo.group(1) if m_rezo else m_suy.group(1)).strip()
        block_lines = [inline] if inline else []
        i += 1

        while i < nace_idx:
            nxt = lines[i]
            if REZO_HEADING.match(nxt or "") or SUYERE_HEADING.match(nxt or ""):
                break
            if (nxt or "").strip() == "":
                break
            block_lines.append(nxt.rstrip())
            i += 1

        while i < nace_idx and (lines[i] or "").strip() == "":
            i += 1

        text = "\n".join(block_lines).strip()
        if text:
            if section == "REZO":
                rezo_blocks.append(text)
            else:
                suyere_blocks.append(text)

    return {"REZO": rezo_blocks, "SUYERE": suyere_blocks}


def _match_major_heading(line: str) -> Optional[str]:
    for section, pat in HEADING_PATTERNS.items():
        if pat.match(line or ""):
            return section
    return None


def _extract_sections(lines: List[str], start_idx: int) -> Dict[str, str]:
    sections = {name: "" for name in SECTION_TO_FIELD.keys()}
    current: Optional[str] = None
    buff: List[str] = []

    def flush():
        nonlocal current, buff
        if current is not None:
            sections[current] = "\n".join(buff).strip()
        current = None
        buff = []

    for line in lines[start_idx:]:
        heading = _match_major_heading(line)
        if heading is not None:
            flush()
            current = heading
            buff = []
            continue
        if current is not None:
            buff.append((line or "").rstrip())
    flush()
    return sections


def _safe_preview(text: str, n: int = 800) -> str:
    return (text or "")[:n]


def main() -> None:
    source_text = _extract_text_from_docx(DOCX_PATH)
    lines = source_text.splitlines()

    nace_idx = _first_heading_index(lines, "EN ESTE ODU NACE")
    if nace_idx is None:
        raise RuntimeError("Could not find 'EN ESTE ODU NACE' heading in source DOCX.")

    first_section_idx = _first_any_section_index(lines)
    header = _parse_header(lines, first_section_idx)
    principal = _extract_principal_rezo_suyere(lines, nace_idx)
    extracted_sections = _extract_sections(lines, nace_idx)

    data = json.loads(ASSET_PATH.read_text(encoding="utf-8"))
    odu = data.get("odu")
    if not isinstance(odu, dict) or TARGET_KEY not in odu:
        raise RuntimeError(f"Target odù key not found: {TARGET_KEY}")

    entry = odu[TARGET_KEY]
    if not isinstance(entry, dict):
        raise RuntimeError("Invalid entry format.")
    content = entry.get("content")
    if not isinstance(content, dict):
        raise RuntimeError("Invalid content format.")

    before_all = json.loads(json.dumps(data, ensure_ascii=False))
    before_content = json.loads(json.dumps(content, ensure_ascii=False))

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup = ASSET_PATH.with_name(f"odu_content_patched.json.bak_baba_ejiogbe_fix2_{timestamp}")
    shutil.copy2(ASSET_PATH, backup)

    # Apply rebuild for target fields only.
    content["rezoYoruba"] = "\n\n".join(principal["REZO"]).strip()
    content["suyereYoruba"] = "\n\n".join(principal["SUYERE"]).strip()

    for section, field in SECTION_TO_FIELD.items():
        content[field] = extracted_sections.get(section, "")

    # Keep legacy UI mirrors in sync.
    content["obrasYEbbo"] = content.get("obras", "")
    merged_rezos = "\n\n".join(
        [x for x in [content.get("rezoYoruba", ""), content.get("suyereYoruba", "")] if (x or "").strip()]
    ).strip()
    content["rezosYSuyeres"] = merged_rezos
    if "suyereEspanol" not in content or not isinstance(content.get("suyereEspanol"), str):
        content["suyereEspanol"] = ""

    # Preserve header alias structure.
    content["mainName"] = header["main_name"]
    content["aliases"] = header["aliases"]

    # Safety: only one key changed.
    changed = []
    for key in data.get("odu", {}):
        if before_all["odu"].get(key) != data["odu"].get(key):
            changed.append(key)
    if changed != [TARGET_KEY]:
        raise RuntimeError(f"Safety check failed. Changed keys: {changed}")

    # Write outputs + publish patched asset.
    BUILD_JSON.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    shutil.copy2(BUILD_JSON, ASSET_PATH)

    after_content = content

    # Validation booleans requested by user.
    rezo = after_content.get("rezoYoruba", "")
    suyere = after_content.get("suyereYoruba", "")
    eshu = after_content.get("eshu", "")

    has_main_rezo_1 = _contains(rezo, "BABA EJIOGBE ALALEKUN")
    has_main_rezo_2 = _contains(rezo, "ORUNMILA NI ODI ELESE MESE")
    rezo_has_eshu_local_1 = _contains(rezo, "Oshé bile Eshu-Elegba Obasin-Laye")
    rezo_has_eshu_local_2 = _contains(rezo, "Eshu-Elegba Agbanikue")
    rezo_fixed = has_main_rezo_1 and has_main_rezo_2
    eshu_contamination_removed_from_rezo = (not rezo_has_eshu_local_1) and (not rezo_has_eshu_local_2)

    suyere_fixed = _starts_with(suyere, "ASHINIMA ASHINIMA")

    eshu_has_local_1 = _contains(eshu, "Oshé bile Eshu-Elegba Obasin-Laye")
    eshu_has_local_2 = _contains(eshu, "Eshu-Elegba Agbanikue")
    eshu_local_rezo_preserved = eshu_has_local_1 and eshu_has_local_2

    # Additional cleanup confirmations.
    descripcion = after_content.get("descripcion", "")
    misplaced_out_of_descripcion = not any(
        _contains(descripcion, token)
        for token in ["PREDICCIONES DEL ODU", "ESTE ODU PROHIBE", "ESTE ODU RECOMIENDA"]
    )

    per_section = []
    for field in REBUILD_FIELDS:
        b = before_content.get(field, "")
        a = after_content.get(field, "")
        if not isinstance(b, str):
            b = ""
        if not isinstance(a, str):
            a = ""
        per_section.append(
            {
                "field": field,
                "before_len": len(b),
                "after_len": len(a),
                "changed": b != a,
            }
        )

    summary = {
        "target_odu_key": TARGET_KEY,
        "source_file_used": str(DOCX_PATH),
        "backup_path": str(backup),
        "main_name_extracted": header["main_name"],
        "aliases_extracted": header["aliases"],
        "sections_rebuilt": REBUILD_FIELDS,
        "validations": {
            "rezo_contains_main_1": has_main_rezo_1,
            "rezo_contains_main_2": has_main_rezo_2,
            "rezo_excludes_eshu_local_1": not rezo_has_eshu_local_1,
            "rezo_excludes_eshu_local_2": not rezo_has_eshu_local_2,
            "suyere_begins_ashinima": suyere_fixed,
            "eshu_contains_local_1": eshu_has_local_1,
            "eshu_contains_local_2": eshu_has_local_2,
            "descripcion_no_pred_proh_rec_markers": misplaced_out_of_descripcion,
        },
        "status": {
            "rezo_fixed": rezo_fixed,
            "suyere_fixed": suyere_fixed,
            "eshu_contamination_removed_from_rezo": eshu_contamination_removed_from_rezo,
            "eshu_local_rezo_preserved": eshu_local_rezo_preserved,
        },
        "per_section_lengths": per_section,
    }
    SUMMARY_JSON.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    report_lines = [
        "# Baba Ejiogbe Rebuild Fix2 Report",
        "",
        f"- target odu key: `{TARGET_KEY}`",
        f"- source file used: `{DOCX_PATH}`",
        f"- backup: `{backup}`",
        f"- main_name extracted: `{header['main_name']}`",
        f"- aliases extracted ({len(header['aliases'])}): `{header['aliases']}`",
        "",
        "## Rebuild Status",
        f"- rezo fixed: `{'YES' if rezo_fixed else 'NO'}`",
        f"- suyere fixed: `{'YES' if suyere_fixed else 'NO'}`",
        f"- eshu contamination removed from rezo: `{'YES' if eshu_contamination_removed_from_rezo else 'NO'}`",
        f"- eshu local rezo preserved: `{'YES' if eshu_local_rezo_preserved else 'NO'}`",
        "",
        "## Per-section before/after lengths",
    ]
    for item in per_section:
        report_lines.append(
            f"- {item['field']}: {item['before_len']} -> {item['after_len']} | changed={str(item['changed']).lower()}"
        )
    REPORT_MD.write_text("\n".join(report_lines) + "\n", encoding="utf-8")

    diff_focus = [
        "rezoYoruba",
        "suyereYoruba",
        "eshu",
        "descripcion",
        "predicciones",
        "prohibiciones",
        "recomendaciones",
        "historiasYPatakies",
    ]
    diff_lines = ["# Baba Ejiogbe Rebuild Fix2 Diff", ""]
    for field in diff_focus:
        before = before_content.get(field, "")
        after = after_content.get(field, "")
        if not isinstance(before, str):
            before = ""
        if not isinstance(after, str):
            after = ""
        diff_lines.append(f"## {field}")
        diff_lines.append(f"- before_len={len(before)}")
        diff_lines.append(f"- after_len={len(after)}")
        diff_lines.append("")
        unified = list(
            difflib.unified_diff(
                before.splitlines()[:80],
                after.splitlines()[:80],
                fromfile="before",
                tofile="after",
                lineterm="",
            )
        )
        if unified:
            diff_lines.append("```diff")
            diff_lines.extend(unified[:260])
            diff_lines.append("```")
        else:
            diff_lines.append("_No changes_")
        diff_lines.append("")
        diff_lines.append("Before preview:")
        diff_lines.append("```text")
        diff_lines.append(_safe_preview(before, 900))
        diff_lines.append("```")
        diff_lines.append("After preview:")
        diff_lines.append("```text")
        diff_lines.append(_safe_preview(after, 900))
        diff_lines.append("```")
        diff_lines.append("")
    DIFF_MD.write_text("\n".join(diff_lines), encoding="utf-8")

    print("target odu key:", TARGET_KEY)
    print("rezo fixed =", "YES" if rezo_fixed else "NO")
    print("suyere fixed =", "YES" if suyere_fixed else "NO")
    print(
        "eshu contamination removed from rezo =",
        "YES" if eshu_contamination_removed_from_rezo else "NO",
    )
    print(
        "eshu local rezo preserved =",
        "YES" if eshu_local_rezo_preserved else "NO",
    )


if __name__ == "__main__":
    main()
