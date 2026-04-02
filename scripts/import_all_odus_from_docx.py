#!/usr/bin/env python3
"""Import all Odù from family DOCX collection files.

Safety:
- Does NOT modify assets/odu_content.json
- Does NOT modify assets/odu_content_patched.json
- Writes review outputs under build/
"""

from __future__ import annotations

import argparse
import copy
import csv
import datetime as dt
import json
import re
import unicodedata
import zipfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from xml.etree import ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_IMG_DIR = ROOT / "IMG"
DEFAULT_DOCX = ROOT / "sources" / "IFA_MASTER_ODU.docx"
BUILD_JSON = ROOT / "build" / "odu_content_v2_from_docx.json"
BUILD_COLLAPSED_JSON = ROOT / "build" / "odu_content_v2_collapsed.json"
BUILD_REPORT_MD = ROOT / "build" / "odu_import_report.md"
BUILD_REPORT_CSV = ROOT / "build" / "odu_import_report.csv"
BUILD_UNMATCHED_MD = ROOT / "build" / "odu_import_unmatched.md"
BUILD_BOUNDARY_AUDIT_MD = ROOT / "build" / "odu_boundary_audit.md"
BUILD_NAME_EQ_JSON = ROOT / "build" / "odu_name_equivalences.json"
BUILD_NAME_EQ_REPORT_MD = ROOT / "build" / "odu_name_equivalence_report.md"
BUILD_CANONICAL_COLLAPSE_REPORT_MD = ROOT / "build" / "odu_canonical_collapse_report.md"
BUILD_CANONICAL_COLLAPSE_REPORT_CSV = ROOT / "build" / "odu_canonical_collapse_report.csv"
NAME_EQ_DOCX = ROOT / "IMG" / "NOMBRES VIEJOS vs. NUEVOS.docx"

EXCLUDED_IMG_DOCX = {
    "nombres viejos vs. nuevos.docx",
    "suyeres.docx",
}

SECTION_KEYS = {
    "DESCRIPCION": "descripcion",
    "NACE": "nace",
    "REZO": "rezoYoruba",
    "SUYERE": "suyereYoruba",
    "OBRAS": "obras",
    "DICE_IFA": "diceIfa",
    "EWES": "ewes",
    "REFRANES": "refranes",
    "ESHU": "eshu",
    "HISTORIAS": "historiasYPatakies",
    "PREDICCIONES": "predicciones",
    "PROHIBICIONES": "prohibiciones",
    "RECOMENDACIONES": "recomendaciones",
}

ORDERED_SECTIONS = [
    "DESCRIPCION",
    "NACE",
    "REZO",
    "SUYERE",
    "OBRAS",
    "DICE_IFA",
    "EWES",
    "REFRANES",
    "ESHU",
    "HISTORIAS",
    "PREDICCIONES",
    "PROHIBICIONES",
    "RECOMENDACIONES",
]

FAMILY_WORDS = {
    "OGBE",
    "OYEKUN",
    "IWORI",
    "ODI",
    "IROSO",
    "OJUANI",
    "OBARA",
    "OKANA",
    "OGUNDA",
    "OSA",
    "IKA",
    "OTRUPON",
    "OTURA",
    "IRETE",
    "OSHE",
    "OFUN",
    "EJIOGBE",
    "OWONRIN",
    "OKANRAN",
    "OTUURUPON",
    "OSE",
}

CANONICAL_FAMILIES = {
    "OGBE",
    "OYEKUN",
    "IWORI",
    "ODI",
    "IROSO",
    "OWONRIN",
    "OBARA",
    "OKANRAN",
    "OGUNDA",
    "OSA",
    "IKA",
    "OTURUPON",
    "OTURA",
    "IRETE",
    "OSE",
    "OFUN",
}

# Used only for boundary validation, not for rewriting/display names.
FAMILY_NORMALIZATION_MAP = {
    "OGBE": "OGBE",
    "EJIOGBE": "OGBE",
    "OYEKU": "OYEKUN",
    "OYEKUN": "OYEKUN",
    "IWORI": "IWORI",
    "ODI": "ODI",
    "IROSO": "IROSO",
    "IROSUN": "IROSO",
    "OJUANI": "OWONRIN",
    "OWONRIN": "OWONRIN",
    "OBARA": "OBARA",
    "OKANA": "OKANRAN",
    "OKANRAN": "OKANRAN",
    "OGUNDA": "OGUNDA",
    "OSA": "OSA",
    "IKA": "IKA",
    "OTRUPON": "OTURUPON",
    "OTRUPON": "OTURUPON",
    "OTURUPO": "OTURUPON",
    "OTURUPON": "OTURUPON",
    "OTUURUPON": "OTURUPON",
    "OTURA": "OTURA",
    "IRETE": "IRETE",
    "OSHE": "OSE",
    "OSE": "OSE",
    "OFUN": "OFUN",
}

STATE_SUBENTRY_TOKENS = {
    "OSOBO",
    "IRE",
    "IKU",
    "ARUN",
    "OFO",
    "OGU",
    "EYO",
    "AYE",
    "ARIKU",
    "OWO",
    "ONA",
}

OLD_SECOND_TOKENS = [
    "MEJI",
    "EJIOGBE",
    "OYEKUN",
    "IWORI",
    "ODI",
    "IROSO",
    "OJUANI",
    "OBARA",
    "OKANA",
    "OGUNDA",
    "OSA",
    "IKA",
    "OTRUPON",
    "OTURA",
    "IRETE",
    "OSHE",
    "OFUN",
]

HEADING_PATTERNS: List[Tuple[str, re.Pattern[str]]] = [
    (
        "REZO",
        re.compile(r"^\s*REZO\b\s*[:\-–—]?\s*(.*)$", re.IGNORECASE),
    ),
    (
        "SUYERE",
        re.compile(r"^\s*SUYERE\b\s*[:\-–—]?\s*(.*)$", re.IGNORECASE),
    ),
    (
        "NACE",
        re.compile(
            r"^\s*EN\s+ESTE\s+OD(?:U|O|Ù)\s+NACE\b\s*[:\-–—]?\s*(.*)$",
            re.IGNORECASE,
        ),
    ),
    (
        "DESCRIPCION",
        re.compile(
            r"^\s*DESCRIPCI(?:Ó|O)N\s+DEL\s+OD(?:U|O|Ù)\b\s*[:\-–—]?\s*(.*)$",
            re.IGNORECASE,
        ),
    ),
    (
        "PREDICCIONES",
        re.compile(
            r"^\s*PREDICCIONES\s+DEL\s+OD(?:U|O|Ù)\b\s*[:\-–—]?\s*(.*)$",
            re.IGNORECASE,
        ),
    ),
    (
        "PROHIBICIONES",
        re.compile(
            r"^\s*ESTE\s+OD(?:U|O|Ù)\s+PROH(?:I|Í)BE\b\s*[:\-–—]?\s*(.*)$",
            re.IGNORECASE,
        ),
    ),
    (
        "RECOMENDACIONES",
        re.compile(
            r"^\s*ESTE\s+OD(?:U|O|Ù)\s+RECOMIENDA\b\s*[:\-–—]?\s*(.*)$",
            re.IGNORECASE,
        ),
    ),
    (
        "OBRAS",
        re.compile(
            r"^\s*OBRAS\s+DEL\s+OD(?:U|O|Ù)\b\s*[:\-–—]?\s*(.*)$",
            re.IGNORECASE,
        ),
    ),
    (
        "DICE_IFA",
        re.compile(r"^\s*DICE\s+IF(?:Á|A)\b\s*[:\-–—\.]?\s*(.*)$", re.IGNORECASE),
    ),
    (
        "EWES",
        re.compile(
            r"^\s*EWES\s+DEL\s+OD(?:U|O|Ù)\b\s*[:\-–—]?\s*(.*)$",
            re.IGNORECASE,
        ),
    ),
    (
        "REFRANES",
        re.compile(
            r"^\s*REFRANES\s+DEL\s+OD(?:U|O|Ù)\b\s*[:\-–—]?\s*(.*)$",
            re.IGNORECASE,
        ),
    ),
    (
        "ESHU",
        re.compile(
            r"^\s*ESHU[\s\-–—]*ELEGBA\s+DEL\s+OD(?:U|O|Ù)\b\s*[:\-–—]?\s*(.*)$",
            re.IGNORECASE,
        ),
    ),
    (
        "HISTORIAS",
        re.compile(
            r"^\s*HISTORIAS?\s+O\s+PATAK(?:I|Í)N(?:E|É)?S\s+DEL\s+OD(?:U|O|Ù)\b\s*[:\-–—]?\s*(.*)$",
            re.IGNORECASE,
        ),
    ),
    (
        "HISTORIAS",
        re.compile(
            r"^\s*HISTORIAS?\s+DEL\s+OD(?:U|O|Ù)\b\s*[:\-–—]?\s*(.*)$",
            re.IGNORECASE,
        ),
    ),
    (
        "HISTORIAS",
        re.compile(
            r"^\s*PATAK(?:I|Í)N(?:E|É)?S\s+DEL\s+OD(?:U|O|Ù)\b\s*[:\-–—]?\s*(.*)$",
            re.IGNORECASE,
        ),
    ),
]

ORDER_RE = re.compile(
    r"ESTE\s+ES\s+EL\s+OD(?:U|O|Ù)\s*(?:#|NO\.?|N[ÚU]MERO)?\s*(\d{1,3})\s*DEL\s+ORDEN\s+SEÑORIAL\s+DE\s+IF(?:Á|A)",
    re.IGNORECASE,
)


@dataclass
class OduAccumulator:
    odu_key: str
    detected_name: str
    order_number: Optional[int] = None
    blocks: Dict[str, List[List[str]]] = field(
        default_factory=lambda: {k: [] for k in SECTION_KEYS.values()}
    )
    current_section_key: str = "descripcion"

    def start_section(self, key: str, inline_text: str = "") -> None:
        self.current_section_key = key
        self.blocks[key].append([])
        if inline_text.strip():
            self.blocks[key][-1].append(inline_text.rstrip())

    def append_line(self, line: str) -> None:
        if self.current_section_key not in self.blocks:
            self.current_section_key = "descripcion"
        if not self.blocks[self.current_section_key]:
            self.blocks[self.current_section_key].append([])
        self.blocks[self.current_section_key][-1].append(line.rstrip())

    def set_order_if_found(self, line: str) -> None:
        if self.order_number is not None:
            return
        m = ORDER_RE.search(line)
        if m:
            self.order_number = int(m.group(1))

    def to_entry(self) -> Tuple[dict, Dict[str, int]]:
        content = {
            "name": self.detected_name,
            "orderNumber": self.order_number,
            "descripcion": "",
            "nace": "",
            "rezoYoruba": "",
            "suyereYoruba": "",
            "obras": "",
            "diceIfa": "",
            "ewes": "",
            "refranes": "",
            "eshu": "",
            "historiasYPatakies": "",
            "predicciones": "",
            "prohibiciones": "",
            "recomendaciones": "",
        }

        repeat_counts: Dict[str, int] = {}
        for key in content.keys():
            if key in {"name", "orderNumber"}:
                continue
            raw_blocks = self.blocks.get(key, [])
            cleaned_blocks: List[str] = []
            for block in raw_blocks:
                b = trim_block(block)
                if b:
                    cleaned_blocks.append(b)
            if cleaned_blocks:
                content[key] = "\n\n".join(cleaned_blocks).rstrip()
            repeat_counts[key] = len(cleaned_blocks)

        return {"odu_key": self.odu_key, "content": content}, repeat_counts


def normalize_upper_header(text: str) -> str:
    s = unicodedata.normalize("NFD", text)
    s = "".join(ch for ch in s if unicodedata.category(ch) != "Mn")
    s = s.upper().strip()
    s = re.sub(r"[_\-\.,;:()\[\]{}!¡¿?\"'`´]+", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def normalize_compact(text: str) -> str:
    s = unicodedata.normalize("NFD", text)
    s = "".join(ch for ch in s if unicodedata.category(ch) != "Mn")
    s = s.upper().strip()
    s = re.sub(r"[^A-Z0-9]+", "", s)
    return s


def list_available_docx() -> List[str]:
    return sorted(str(p.relative_to(ROOT)) for p in ROOT.rglob("*.docx"))


def canonicalize_old_pair(first: str, second: str) -> Optional[str]:
    first_can = map_family_token(first)
    if first_can is None:
        return None
    if second == "MEJI":
        return f"{first_can} MEJI"
    second_can = map_family_token(second)
    if second_can is None:
        return None
    return f"{first_can} {second_can}"


def parse_family_from_header(line: str) -> Optional[str]:
    n = normalize_upper_header(line)
    m = re.match(r"^FAMILIA\s+([A-ZÁÉÍÓÚÜÑ]+)\b", n)
    if not m:
        return None
    fam = m.group(1)
    if fam == "OGUNGA":
        fam = "OGUNDA"
    if fam == "OYEKU":
        fam = "OYEKUN"
    return fam


def parse_equivalence_docx(docx_path: Path) -> Dict[str, object]:
    paragraphs = load_docx_paragraphs(docx_path)
    current_family: Optional[str] = None

    # alias_compact -> list of records
    alias_lookup: Dict[str, List[dict]] = {}
    records: List[dict] = []
    unresolved_lines: List[str] = []
    parse_conflicts: List[str] = []

    # Candidate families for fallback if family header is noisy.
    fallback_families = sorted(
        {k for k in FAMILY_NORMALIZATION_MAP.keys() if k in FAMILY_WORDS or k in CANONICAL_FAMILIES}
    )

    for raw in paragraphs:
        line = raw.replace("\u00A0", " ").strip()
        if not line:
            continue

        fam = parse_family_from_header(line)
        if fam:
            current_family = fam
            continue

        if "NOMBRE VIEJO" in normalize_upper_header(line):
            continue

        compact = normalize_compact(line)
        if not compact:
            continue

        family_candidates: List[str] = []
        if current_family:
            family_candidates.append(current_family)
        family_candidates.extend([f for f in fallback_families if f not in family_candidates])

        prefix_matches: List[Tuple[int, str, str, str]] = []
        # (prefix_len, old_first, old_second, old_raw)
        for fam_cand in family_candidates:
            fam_cand_comp = normalize_compact(fam_cand)
            for second in OLD_SECOND_TOKENS:
                old_raw = f"{fam_cand} {second}"
                old_comp = normalize_compact(old_raw)
                if compact.startswith(old_comp):
                    prefix_matches.append((len(old_comp), fam_cand, second, old_raw))

                # Some lines are missing spaces or have tiny typos in family token.
                # Try canonical-family normalization fallback for first token.
                first_can = map_family_token(fam_cand)
                if first_can and first_can != fam_cand:
                    alt_old_raw = f"{first_can} {second}"
                    alt_old_comp = normalize_compact(alt_old_raw)
                    if compact.startswith(alt_old_comp):
                        prefix_matches.append((len(alt_old_comp), first_can, second, alt_old_raw))

            # Family-only prefix variant for lines like OGUNGA MEJI OGUNDA MEJI
            if compact.startswith(fam_cand_comp + "MEJI"):
                prefix_matches.append((len(fam_cand_comp + "MEJI"), fam_cand, "MEJI", f"{fam_cand} MEJI"))

        if not prefix_matches:
            unresolved_lines.append(line)
            continue

        prefix_matches.sort(key=lambda x: x[0], reverse=True)
        best_len = prefix_matches[0][0]
        best = [m for m in prefix_matches if m[0] == best_len]

        unique_old = {(b[1], b[2]) for b in best}
        if len(unique_old) != 1:
            parse_conflicts.append(line)
            continue

        _, old_first, old_second, old_raw = best[0]
        old_comp = normalize_compact(old_raw)
        new_comp = compact[len(old_comp) :]
        if not new_comp:
            unresolved_lines.append(line)
            continue

        canonical_heading = canonicalize_old_pair(old_first, old_second)
        if not canonical_heading:
            unresolved_lines.append(line)
            continue

        status, _ = classify_odu_boundary_heading(canonical_heading)
        if status != "accepted":
            unresolved_lines.append(line)
            continue

        # Recover a best-effort display new name from raw line.
        raw_upper = normalize_upper_header(line)
        old_disp = normalize_upper_header(old_raw)
        new_display_guess = ""
        if raw_upper.startswith(old_disp):
            new_display_guess = line[len(old_raw) :].strip()

        rec = {
            "source_line": line,
            "old_name": old_raw,
            "new_name_guess": new_display_guess,
            "old_compact": old_comp,
            "new_compact": new_comp,
            "canonical_heading": canonical_heading,
            "family_context": current_family or "",
        }
        records.append(rec)

        for alias_key in {old_comp, new_comp}:
            alias_lookup.setdefault(alias_key, []).append(rec)

    # Build conflicts where one alias maps to multiple canonical headings.
    alias_conflicts: List[dict] = []
    for alias_key, items in alias_lookup.items():
        targets = sorted({x["canonical_heading"] for x in items})
        if len(targets) > 1:
            alias_conflicts.append(
                {
                    "alias_compact": alias_key,
                    "canonical_targets": targets,
                    "sources": [x["source_line"] for x in items],
                }
            )

    payload = {
        "source_docx": str(docx_path),
        "generatedAtUtc": dt.datetime.utcnow().replace(microsecond=0).isoformat() + "Z",
        "total_alias_records": len(records),
        "total_alias_keys": len(alias_lookup),
        "alias_conflicts_count": len(alias_conflicts),
        "records": records,
        "alias_conflicts": alias_conflicts,
        "unresolved_lines_count": len(unresolved_lines),
        "unresolved_lines": unresolved_lines,
        "parse_conflicts_count": len(parse_conflicts),
        "parse_conflicts": parse_conflicts,
    }
    BUILD_NAME_EQ_JSON.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    runtime_payload = dict(payload)
    runtime_payload["_lookup"] = alias_lookup
    return runtime_payload


def resolve_heading_via_equivalence(
    heading_line: str,
    eq_payload: Optional[Dict[str, object]],
) -> Tuple[Optional[str], str, Optional[dict]]:
    if not eq_payload:
        return None, "equivalence_not_enabled", None

    lookup = eq_payload.get("_lookup")
    if not isinstance(lookup, dict):
        return None, "equivalence_records_missing", None

    key = normalize_compact(heading_line)
    items = lookup.get(key, []) if isinstance(key, str) else []
    if not items:
        return None, "equivalence_no_match", None

    targets = sorted({str(it.get("canonical_heading", "")) for it in items if it.get("canonical_heading")})
    if len(targets) != 1:
        return None, "equivalence_conflict_multiple_targets", {"targets": targets}

    candidate = targets[0]
    status, reason = classify_odu_boundary_heading(candidate)
    if status != "accepted":
        return None, f"equivalence_mapped_noncanonical:{reason}", {"candidate": candidate}

    return candidate, "equivalence_resolved", items[0]


def load_docx_paragraphs(path: Path) -> List[str]:
    try:
        from docx import Document  # type: ignore

        doc = Document(str(path))
        return [(p.text or "").replace("\u00A0", " ").rstrip() for p in doc.paragraphs]
    except Exception:
        with zipfile.ZipFile(path) as zf:
            xml = zf.read("word/document.xml")
        root = ET.fromstring(xml)
        ns = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
        out: List[str] = []
        for p in root.findall(".//w:p", ns):
            txt = "".join((t.text or "") for t in p.findall(".//w:t", ns))
            out.append(txt.replace("\u00A0", " ").rstrip())
        return out


def trim_block(lines: List[str]) -> str:
    out = list(lines)
    while out and not out[0].strip():
        out.pop(0)
    while out and not out[-1].strip():
        out.pop()
    return "\n".join(out).rstrip()


def detect_section_heading(line: str) -> Optional[Tuple[str, str, str]]:
    for sec, pattern in HEADING_PATTERNS:
        m = pattern.match(line or "")
        if m:
            inline = (m.group(1) or "").strip()
            return sec, SECTION_KEYS[sec], inline
    return None


def is_all_caps_like(line: str) -> bool:
    letters = [ch for ch in line if ch.isalpha()]
    if not letters:
        return False
    caps = sum(1 for ch in letters if ch.isupper())
    return caps / len(letters) >= 0.92


def map_family_token(token: str) -> Optional[str]:
    return FAMILY_NORMALIZATION_MAP.get(token)


def classify_odu_boundary_heading(line: str) -> Tuple[str, str]:
    """Return (status, reason): accepted|rejected|ambiguous|not_candidate."""
    s = (line or "").strip()
    if not s:
        return ("not_candidate", "empty")
    if len(s) > 90:
        return ("not_candidate", "too_long")
    if detect_section_heading(s):
        return ("not_candidate", "section_heading")
    if s.endswith(":"):
        return ("not_candidate", "ends_with_colon")
    if not is_all_caps_like(s):
        return ("not_candidate", "not_caps_like")

    normalized = normalize_upper_header(s)
    if not normalized:
        return ("not_candidate", "empty_normalized")

    toks = normalized.split()
    if len(toks) > 8:
        return ("not_candidate", "too_many_tokens")
    if toks and toks[0] == "BABA":
        toks = toks[1:]
    if not toks:
        return ("not_candidate", "no_tokens_after_baba")

    mapped = [map_family_token(t) for t in toks]
    has_family = any(m is not None for m in mapped)
    if not has_family:
        return ("not_candidate", "no_family_token")

    if not re.match(r"^(?:BABA\s+)?[A-ZÁÉÍÓÚÜÑ\s\-]+$", s):
        return ("not_candidate", "invalid_shape")

    # Rule 1A: canonical meji/family heads
    if toks == ["EJIOGBE"]:
        return ("accepted", "canonical_meji_head_ejiogbe")
    if len(toks) == 2 and toks[1] == "MEJI" and mapped[0] in CANONICAL_FAMILIES:
        return ("accepted", "canonical_family_meji")

    # Rule 1B: canonical pair combinations
    if len(toks) == 2 and mapped[0] in CANONICAL_FAMILIES and mapped[1] in CANONICAL_FAMILIES:
        return ("accepted", "canonical_pair")

    # Rule 2: reject state/subentry tokens unless exactly canonical pair
    state_hits = [t for t in toks if t in STATE_SUBENTRY_TOKENS]
    if state_hits:
        return ("rejected", f"contains_state_tokens:{','.join(state_hits)}")

    # Rule 3: canonical prefix with extra trailing tokens is usually an alias candidate
    # unless state tokens were detected above.
    if mapped[0] in CANONICAL_FAMILIES:
        if len(toks) > 2:
            return ("ambiguous", "canonical_prefix_with_extra_tokens")
        if len(toks) == 2 and mapped[1] not in CANONICAL_FAMILIES and toks[1] != "MEJI":
            return ("ambiguous", "canonical_prefix_noncanonical_second")
        if len(toks) == 1:
            return ("ambiguous", "single_family_without_meji")

    return ("ambiguous", "heading_like_but_not_canonical")


def has_nearby_section_heading(
    paragraphs: List[str],
    start_idx: int,
    *,
    max_lookahead: int = 120,
) -> bool:
    end = min(len(paragraphs), start_idx + max_lookahead + 1)
    for idx in range(start_idx + 1, end):
        line = paragraphs[idx].replace("\u00A0", " ").rstrip()
        if detect_section_heading(line):
            return True
    return False


def looks_like_odu_heading(line: str) -> bool:
    status, _ = classify_odu_boundary_heading(line)
    return status in {"accepted", "rejected", "ambiguous"}


def canonical_odu_key(line: str) -> str:
    return normalize_upper_header(line)


def dedupe_keep_order(items: List[str]) -> List[str]:
    seen = set()
    out = []
    for it in items:
        if it in seen:
            continue
        seen.add(it)
        out.append(it)
    return out


def canonicalize_heading_for_grouping(line: str) -> Optional[str]:
    normalized = normalize_upper_header(line)
    if not normalized:
        return None
    toks = normalized.split()
    if toks and toks[0] == "BABA":
        toks = toks[1:]
    if not toks:
        return None

    mapped = [map_family_token(t) for t in toks]
    first = mapped[0] if mapped else None
    second = mapped[1] if len(mapped) > 1 else None

    if toks == ["EJIOGBE"]:
        return "OGBE MEJI"
    if len(toks) == 2 and toks[1] == "MEJI" and first in CANONICAL_FAMILIES:
        return f"{first} MEJI"
    if len(toks) == 2 and first in CANONICAL_FAMILIES and second in CANONICAL_FAMILIES:
        return f"{first} {second}"
    if len(toks) == 1 and first in CANONICAL_FAMILIES:
        return f"{first} MEJI"
    return None


def resolve_entry_canonical_key(
    entry: dict,
    *,
    eq_payload: Optional[Dict[str, object]] = None,
) -> Tuple[str, str, str]:
    content = entry.get("content", {})
    raw_candidates = [
        str(entry.get("odu_key", "") or "").strip(),
        str(content.get("name", "") or "").strip(),
    ]

    seen: set[str] = set()
    for raw in raw_candidates:
        if not raw:
            continue
        folded = normalize_upper_header(raw)
        if not folded or folded in seen:
            continue
        seen.add(folded)

        status, _ = classify_odu_boundary_heading(raw)
        if status == "accepted":
            key = canonicalize_heading_for_grouping(raw)
            if key:
                return key, "accepted_boundary", raw

        resolved_heading, reason, _ = resolve_heading_via_equivalence(raw, eq_payload)
        if resolved_heading:
            key = canonicalize_heading_for_grouping(resolved_heading)
            if key:
                return key, f"equivalence:{reason}", raw

        key = canonicalize_heading_for_grouping(raw)
        if key:
            return key, "family_normalization_fallback", raw

    unresolved = normalize_upper_header(raw_candidates[0] or raw_candidates[1] or "")
    unresolved = unresolved or "UNKNOWN"
    return f"UNRESOLVED::{unresolved}", "unresolved", unresolved


def _content_text(entry: dict, key: str) -> str:
    return str(entry.get("content", {}).get(key, "") or "")


def _has_value_text(entry: dict, key: str) -> bool:
    return bool(_content_text(entry, key).strip())


def _entry_quality(entry: dict) -> Tuple[int, int, int, int]:
    section_count = sum(1 for field in SECTION_KEYS.values() if _has_value_text(entry, field))
    has_order = 1 if str(entry.get("content", {}).get("orderNumber", "") or "").strip() else 0
    descripcion_len = len(_content_text(entry, "descripcion").strip())
    total_text_len = sum(len(_content_text(entry, field).strip()) for field in SECTION_KEYS.values())
    return section_count, has_order, descripcion_len, total_text_len


def collapse_entries_by_canonical_key(
    entries: List[dict],
    *,
    eq_payload: Optional[Dict[str, object]] = None,
) -> Tuple[List[dict], Dict[str, object]]:
    working_entries = [copy.deepcopy(e) for e in entries]

    grouped: Dict[str, List[dict]] = {}
    for entry in working_entries:
        canonical_key, method, matched_from = resolve_entry_canonical_key(entry, eq_payload=eq_payload)
        entry["canonical_key"] = canonical_key
        entry["canonical_resolution_method"] = method
        entry["canonical_resolution_input"] = matched_from
        grouped.setdefault(canonical_key, []).append(entry)

    collapsed: List[dict] = []
    collapse_groups: List[dict] = []
    member_rows: List[dict] = []
    total_secondary_entries_removed = 0
    total_sections_merged = 0

    for canonical_key, members in grouped.items():
        ranked = sorted(
            members,
            key=lambda e: (
                -_entry_quality(e)[0],
                -_entry_quality(e)[1],
                -_entry_quality(e)[2],
                -_entry_quality(e)[3],
                str(e.get("source_file", "")),
                str(e.get("odu_key", "")),
            ),
        )
        primary = ranked[0]
        primary_key = str(primary.get("odu_key", ""))
        sections_merged: List[str] = []
        merged_from_secondaries: List[dict] = []

        member_rows.append(
            {
                "canonical_key": canonical_key,
                "member_odu_key": primary_key,
                "is_primary": True,
                "source_file": str(primary.get("source_file", "")),
                "resolution_method": str(primary.get("canonical_resolution_method", "")),
                "populated_sections": _entry_quality(primary)[0],
                "has_order_number": bool(str(primary.get("content", {}).get("orderNumber", "") or "").strip()),
                "descripcion_len": _entry_quality(primary)[2],
                "total_text_len": _entry_quality(primary)[3],
                "sections_merged_into_primary": "",
            }
        )

        if len(ranked) > 1:
            total_secondary_entries_removed += len(ranked) - 1
            for secondary in ranked[1:]:
                merged_fields_for_secondary: List[str] = []
                for field in SECTION_KEYS.values():
                    if not _has_value_text(primary, field) and _has_value_text(secondary, field):
                        primary["content"][field] = _content_text(secondary, field)
                        sections_merged.append(field)
                        merged_fields_for_secondary.append(field)
                        total_sections_merged += 1

                if (
                    not str(primary.get("content", {}).get("orderNumber", "") or "").strip()
                    and str(secondary.get("content", {}).get("orderNumber", "") or "").strip()
                ):
                    primary["content"]["orderNumber"] = secondary["content"]["orderNumber"]

                merged_from_secondaries.append(
                    {
                        "odu_key": str(secondary.get("odu_key", "")),
                        "source_file": str(secondary.get("source_file", "")),
                        "sections_merged": merged_fields_for_secondary,
                    }
                )

                member_rows.append(
                    {
                        "canonical_key": canonical_key,
                        "member_odu_key": str(secondary.get("odu_key", "")),
                        "is_primary": False,
                        "source_file": str(secondary.get("source_file", "")),
                        "resolution_method": str(secondary.get("canonical_resolution_method", "")),
                        "populated_sections": _entry_quality(secondary)[0],
                        "has_order_number": bool(
                            str(secondary.get("content", {}).get("orderNumber", "") or "").strip()
                        ),
                        "descripcion_len": _entry_quality(secondary)[2],
                        "total_text_len": _entry_quality(secondary)[3],
                        "sections_merged_into_primary": ",".join(merged_fields_for_secondary),
                    }
                )

        collapse_groups.append(
            {
                "canonical_key": canonical_key,
                "member_keys": [str(m.get("odu_key", "")) for m in ranked],
                "member_count": len(ranked),
                "primary_odu_key": primary_key,
                "primary_source_file": str(primary.get("source_file", "")),
                "sections_merged": sorted(set(sections_merged)),
                "merged_from_secondaries": merged_from_secondaries,
            }
        )
        collapsed.append(primary)

    collapse_groups_with_multiple = [g for g in collapse_groups if int(g.get("member_count", 0) or 0) > 1]

    meta: Dict[str, object] = {
        "canonical_before_collapse": len(entries),
        "canonical_after_collapse": len(collapsed),
        "collapse_groups_total": len(collapse_groups_with_multiple),
        "total_secondary_entries_removed": total_secondary_entries_removed,
        "total_sections_merged_from_secondaries": total_sections_merged,
        "collapse_groups": collapse_groups,
        "collapse_groups_with_multiple": collapse_groups_with_multiple,
        "member_rows": member_rows,
    }
    return collapsed, meta


def write_canonical_collapse_outputs(
    *,
    collapsed_entries: List[dict],
    collapse_meta: Dict[str, object],
    source_files: List[str],
    import_meta: Dict[str, object],
) -> None:
    BUILD_COLLAPSED_JSON.parent.mkdir(parents=True, exist_ok=True)

    payload = {
        "sourceMode": "family_collection_img",
        "sourceFiles": source_files,
        "generatedAtUtc": dt.datetime.utcnow().replace(microsecond=0).isoformat() + "Z",
        "canonicalBeforeCollapse": int(collapse_meta.get("canonical_before_collapse", 0) or 0),
        "canonicalAfterCollapse": int(collapse_meta.get("canonical_after_collapse", 0) or 0),
        "collapseGroupsTotal": int(collapse_meta.get("collapse_groups_total", 0) or 0),
        "totalSecondaryEntriesRemoved": int(
            collapse_meta.get("total_secondary_entries_removed", 0) or 0
        ),
        "totalSectionsMergedFromSecondaries": int(
            collapse_meta.get("total_sections_merged_from_secondaries", 0) or 0
        ),
        "totalDetectedBeforeCanonicalFilter": int(
            import_meta.get("boundary_candidates_total", 0) or 0
        ),
        "rejectedSubentriesTotal": int(import_meta.get("rejected_subentries_total", 0) or 0),
        "ambiguousRemainingCount": int(import_meta.get("ambiguous_remaining_count", 0) or 0),
        "odus": collapsed_entries,
        "collapseGroups": collapse_meta.get("collapse_groups_with_multiple", []),
    }
    BUILD_COLLAPSED_JSON.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    member_rows: List[dict] = collapse_meta.get("member_rows", [])  # type: ignore[assignment]
    with BUILD_CANONICAL_COLLAPSE_REPORT_CSV.open("w", newline="", encoding="utf-8") as f:
        fields = [
            "canonical_key",
            "member_odu_key",
            "is_primary",
            "source_file",
            "resolution_method",
            "populated_sections",
            "has_order_number",
            "descripcion_len",
            "total_text_len",
            "sections_merged_into_primary",
        ]
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        for row in member_rows:
            writer.writerow(row)

    groups_multi: List[dict] = collapse_meta.get("collapse_groups_with_multiple", [])  # type: ignore[assignment]
    sorted_groups = sorted(
        groups_multi,
        key=lambda g: (
            -int(g.get("member_count", 0) or 0),
            -len(g.get("sections_merged", []) if isinstance(g.get("sections_merged", []), list) else []),
            str(g.get("canonical_key", "")),
        ),
    )

    md_lines: List[str] = [
        "# Canonical Collapse Report",
        "",
        f"- Generated UTC: `{payload['generatedAtUtc']}`",
        f"- Source entries before collapse: **{payload['canonicalBeforeCollapse']}**",
        f"- Canonical entries after collapse: **{payload['canonicalAfterCollapse']}**",
        f"- Groups with >1 entry: **{payload['collapseGroupsTotal']}**",
        f"- Total merged secondaries: **{payload['totalSecondaryEntriesRemoved']}**",
        f"- Total sections merged from secondaries: **{payload['totalSectionsMergedFromSecondaries']}**",
        "",
        "## Top Collapsed Groups",
        "",
    ]

    if sorted_groups:
        for group in sorted_groups[:100]:
            member_keys = group.get("member_keys", [])
            merged_sections = group.get("sections_merged", [])
            md_lines.append(f"- canonical_key: `{group.get('canonical_key','')}`")
            md_lines.append(f"  primary: `{group.get('primary_odu_key','')}`")
            md_lines.append(
                f"  members: {', '.join(f'`{x}`' for x in member_keys) if isinstance(member_keys, list) else member_keys}"
            )
            md_lines.append(
                f"  sections_merged: {', '.join(merged_sections) if isinstance(merged_sections, list) and merged_sections else 'none'}"
            )
            md_lines.append("")
    else:
        md_lines.append("- None")

    BUILD_CANONICAL_COLLAPSE_REPORT_MD.write_text(
        "\n".join(md_lines).rstrip() + "\n", encoding="utf-8"
    )


def family_guess_from_filename(path: Path) -> str:
    n = normalize_upper_header(path.stem)
    m = re.search(r"COLECCION\s+([A-ZÁÉÍÓÚÜÑ]+)", n)
    if m:
        return m.group(1)
    toks = n.split()
    return toks[0] if toks else "UNKNOWN"


def parse_docx_to_entries(
    paragraphs: List[str],
    source_file: str,
    family_guess: str,
    *,
    eq_payload: Optional[Dict[str, object]] = None,
) -> Tuple[List[dict], Dict[str, object]]:
    entries: List[dict] = []
    repeats_by_odu: Dict[str, List[str]] = {}
    ambiguous_headings: List[str] = []
    pre_odu_section_hits: List[str] = []
    accepted_boundary_headings: List[dict] = []
    rejected_boundary_headings: List[dict] = []
    ambiguous_boundary_headings: List[dict] = []
    boundary_candidates_total = 0
    rejected_subentries_total = 0
    resolved_by_equivalence: List[dict] = []
    equivalence_conflicts: List[dict] = []

    current: Optional[OduAccumulator] = None

    for idx, raw in enumerate(paragraphs):
        line = raw.replace("\u00A0", " ").rstrip()

        status, reason = classify_odu_boundary_heading(line)
        if status in {"accepted", "rejected", "ambiguous"}:
            boundary_candidates_total += 1

        if status == "accepted":
            if not has_nearby_section_heading(paragraphs, idx):
                ambiguous_headings.append(line.strip())
                ambiguous_boundary_headings.append(
                    {
                        "line": line.strip(),
                        "reason": "accepted_but_no_nearby_section",
                        "index": idx,
                    }
                )
                continue

            accepted_boundary_headings.append(
                {"line": line.strip(), "reason": reason, "index": idx}
            )

            if current is not None:
                entry, repeat_counts = current.to_entry()
                repeated_sections = [k for k, n in repeat_counts.items() if n > 1]
                if repeated_sections:
                    repeats_by_odu[entry["odu_key"]] = repeated_sections
                entry["source_file"] = source_file
                entry["family_guess"] = family_guess
                entry["_repeated_sections"] = repeated_sections
                entries.append(entry)

            key = canonical_odu_key(line)
            current = OduAccumulator(odu_key=key, detected_name=line.strip())
            current.start_section("descripcion")
            current.set_order_if_found(line)
            continue

        if status == "rejected":
            rejected_subentries_total += 1
            rejected_boundary_headings.append(
                {"line": line.strip(), "reason": reason, "index": idx}
            )
            if current is not None:
                current.append_line(line)
                current.set_order_if_found(line)
            continue

        if status == "ambiguous":
            resolved_heading, eq_reason, eq_meta = resolve_heading_via_equivalence(
                line, eq_payload
            )
            if resolved_heading:
                if has_nearby_section_heading(paragraphs, idx):
                    resolved_by_equivalence.append(
                        {
                            "source_file": source_file,
                            "line": line.strip(),
                            "resolved_to": resolved_heading,
                            "reason": eq_reason,
                        }
                    )
                    accepted_boundary_headings.append(
                        {
                            "line": line.strip(),
                            "reason": f"{reason}+{eq_reason}->{resolved_heading}",
                            "index": idx,
                        }
                    )
                    if current is not None:
                        entry, repeat_counts = current.to_entry()
                        repeated_sections = [k for k, n in repeat_counts.items() if n > 1]
                        if repeated_sections:
                            repeats_by_odu[entry["odu_key"]] = repeated_sections
                        entry["source_file"] = source_file
                        entry["family_guess"] = family_guess
                        entry["_repeated_sections"] = repeated_sections
                        entries.append(entry)

                    key = canonical_odu_key(resolved_heading)
                    current = OduAccumulator(
                        odu_key=key, detected_name=normalize_upper_header(resolved_heading)
                    )
                    current.start_section("descripcion")
                    current.set_order_if_found(line)
                    continue

            if eq_reason == "equivalence_conflict_multiple_targets":
                equivalence_conflicts.append(
                    {
                        "source_file": source_file,
                        "line": line.strip(),
                        "reason": eq_reason,
                        "targets": (eq_meta or {}).get("targets", []),
                    }
                )

            ambiguous_headings.append(line.strip())
            ambiguous_boundary_headings.append(
                {"line": line.strip(), "reason": f"{reason}+{eq_reason}", "index": idx}
            )
            if current is not None:
                current.append_line(line)
                current.set_order_if_found(line)
            continue

        sec = detect_section_heading(line)
        if sec:
            _, sec_key, inline = sec
            if current is None:
                pre_odu_section_hits.append(line.strip())
                continue
            current.start_section(sec_key, inline_text=inline)
            current.set_order_if_found(line)
            continue

        if current is None:
            continue

        current.append_line(line)
        current.set_order_if_found(line)

    if current is not None:
        entry, repeat_counts = current.to_entry()
        repeated_sections = [k for k, n in repeat_counts.items() if n > 1]
        if repeated_sections:
            repeats_by_odu[entry["odu_key"]] = repeated_sections
        entry["source_file"] = source_file
        entry["family_guess"] = family_guess
        entry["_repeated_sections"] = repeated_sections
        entries.append(entry)

    meta: Dict[str, object] = {
        "repeats_by_odu": repeats_by_odu,
        "ambiguous_headings": dedupe_keep_order(ambiguous_headings),
        "pre_odu_section_hits": dedupe_keep_order(pre_odu_section_hits),
        "accepted_boundary_headings": accepted_boundary_headings,
        "rejected_boundary_headings": rejected_boundary_headings,
        "ambiguous_boundary_headings": ambiguous_boundary_headings,
        "boundary_candidates_total": boundary_candidates_total,
        "rejected_subentries_total": rejected_subentries_total,
        "resolved_by_equivalence": resolved_by_equivalence,
        "equivalence_conflicts": equivalence_conflicts,
    }
    return entries, meta


def has_value(entry: dict, key: str) -> bool:
    return bool(str(entry["content"].get(key, "") or "").strip())


def discover_family_docx_files(img_dir: Path) -> List[Path]:
    if not img_dir.exists() or not img_dir.is_dir():
        raise SystemExit(f"IMG directory not found: {img_dir}")

    candidates = [p for p in img_dir.glob("*.docx") if p.is_file()]

    def is_valid(path: Path) -> bool:
        lower = path.name.lower().strip()
        if lower in EXCLUDED_IMG_DOCX:
            return False
        if lower.startswith("~$"):
            return False
        return True

    valid = [p for p in candidates if is_valid(p)]

    if not valid:
        raise SystemExit("No valid family DOCX files found in IMG/")

    def sort_key(path: Path) -> Tuple[int, int, str]:
        m = re.match(r"\s*(\d+)\s*-", path.name)
        if m:
            return (0, int(m.group(1)), path.name.lower())
        return (1, 9999, path.name.lower())

    return sorted(valid, key=sort_key)


def merge_entries_from_files(
    paths: List[Path],
    *,
    eq_payload: Optional[Dict[str, object]] = None,
) -> Tuple[List[dict], Dict[str, object]]:
    merged: List[dict] = []
    seen: Dict[str, dict] = {}
    duplicates: List[dict] = []
    duplicates_cross_file: List[dict] = []
    duplicates_same_file: List[dict] = []
    file_stats: List[dict] = []
    repeats_by_odu: Dict[str, List[str]] = {}
    ambiguous_by_file: List[str] = []
    pre_section_hits_by_file: List[str] = []
    accepted_boundary_audit: List[str] = []
    rejected_boundary_audit: List[str] = []
    ambiguous_boundary_audit: List[str] = []
    resolved_by_equivalence: List[dict] = []
    equivalence_conflicts: List[dict] = []

    total_detected = 0
    boundary_candidates_total = 0
    rejected_subentries_total = 0

    for path in paths:
        source_file = str(path.relative_to(ROOT))
        family_guess = family_guess_from_filename(path)
        paragraphs = load_docx_paragraphs(path)
        entries, meta = parse_docx_to_entries(
            paragraphs, source_file, family_guess, eq_payload=eq_payload
        )

        total_detected += len(entries)
        kept = 0
        dup = 0

        for e in entries:
            key = e["odu_key"]
            repeated_sections = e.pop("_repeated_sections", [])
            if key not in seen:
                seen[key] = e
                merged.append(e)
                kept += 1
                if repeated_sections:
                    repeats_by_odu[key] = repeated_sections
            else:
                dup += 1
                kept_source_file = str(seen[key].get("source_file", ""))
                duplicate_scope = "cross_file" if kept_source_file != source_file else "same_file"
                record = {
                    "odu_key": key,
                    "kept_source_file": kept_source_file,
                    "duplicate_source_file": source_file,
                    "duplicate_detected_name": e.get("content", {}).get("name", ""),
                    "family_guess": family_guess,
                    "duplicate_scope": duplicate_scope,
                }
                duplicates.append(
                    record
                )
                if duplicate_scope == "cross_file":
                    duplicates_cross_file.append(record)
                else:
                    duplicates_same_file.append(record)

        file_stats.append(
            {
                "source_file": source_file,
                "family_guess": family_guess,
                "detected_count": len(entries),
                "kept_count": kept,
                "duplicates_count": dup,
            }
        )

        ambiguous = meta.get("ambiguous_headings", [])
        for h in ambiguous if isinstance(ambiguous, list) else []:
            ambiguous_by_file.append(f"{source_file} :: {h}")

        pre_hits = meta.get("pre_odu_section_hits", [])
        for h in pre_hits if isinstance(pre_hits, list) else []:
            pre_section_hits_by_file.append(f"{source_file} :: {h}")

        boundary_candidates_total += int(meta.get("boundary_candidates_total", 0) or 0)
        rejected_subentries_total += int(meta.get("rejected_subentries_total", 0) or 0)

        for item in meta.get("accepted_boundary_headings", []) if isinstance(meta.get("accepted_boundary_headings", []), list) else []:
            if isinstance(item, dict):
                accepted_boundary_audit.append(
                    f"{source_file} :: {item.get('line','')} [{item.get('reason','')}]"
                )
        for item in meta.get("rejected_boundary_headings", []) if isinstance(meta.get("rejected_boundary_headings", []), list) else []:
            if isinstance(item, dict):
                rejected_boundary_audit.append(
                    f"{source_file} :: {item.get('line','')} [{item.get('reason','')}]"
                )
        for item in meta.get("ambiguous_boundary_headings", []) if isinstance(meta.get("ambiguous_boundary_headings", []), list) else []:
            if isinstance(item, dict):
                ambiguous_boundary_audit.append(
                    f"{source_file} :: {item.get('line','')} [{item.get('reason','')}]"
                )

        for item in meta.get("resolved_by_equivalence", []) if isinstance(meta.get("resolved_by_equivalence", []), list) else []:
            if isinstance(item, dict):
                resolved_by_equivalence.append(item)

        for item in meta.get("equivalence_conflicts", []) if isinstance(meta.get("equivalence_conflicts", []), list) else []:
            if isinstance(item, dict):
                equivalence_conflicts.append(item)

    merge_meta: Dict[str, object] = {
        "total_detected_before_dedup": total_detected,
        "total_unique_after_dedup": len(merged),
        "duplicates": duplicates,
        "duplicates_count": len(duplicates),
        "duplicates_cross_file_count": len(duplicates_cross_file),
        "duplicates_same_file_count": len(duplicates_same_file),
        "duplicates_cross_file": duplicates_cross_file,
        "duplicates_same_file": duplicates_same_file,
        "file_stats": file_stats,
        "repeats_by_odu": repeats_by_odu,
        "ambiguous_by_file": dedupe_keep_order(ambiguous_by_file),
        "pre_section_hits_by_file": dedupe_keep_order(pre_section_hits_by_file),
        "accepted_boundary_audit": dedupe_keep_order(accepted_boundary_audit),
        "rejected_boundary_audit": dedupe_keep_order(rejected_boundary_audit),
        "ambiguous_boundary_audit": dedupe_keep_order(ambiguous_boundary_audit),
        "boundary_candidates_total": boundary_candidates_total,
        "rejected_subentries_total": rejected_subentries_total,
        "ambiguous_remaining_count": len(dedupe_keep_order(ambiguous_boundary_audit)),
        "resolved_by_equivalence_count": len(resolved_by_equivalence),
        "resolved_by_equivalence": resolved_by_equivalence,
        "equivalence_conflicts_count": len(equivalence_conflicts),
        "equivalence_conflicts": equivalence_conflicts,
    }
    return merged, merge_meta


def write_outputs(entries: List[dict], meta: Dict[str, object], source_files: List[str]) -> None:
    BUILD_JSON.parent.mkdir(parents=True, exist_ok=True)

    payload = {
        "sourceMode": "family_collection_img",
        "sourceFiles": source_files,
        "generatedAtUtc": dt.datetime.utcnow().replace(microsecond=0).isoformat() + "Z",
        "count": len(entries),
        "totalDetectedBeforeDedup": meta.get("total_detected_before_dedup", len(entries)),
        "totalDetectedBeforeCanonicalFilter": meta.get("boundary_candidates_total", 0),
        "totalCanonicalAfterFilter": len(entries),
        "rejectedSubentriesTotal": meta.get("rejected_subentries_total", 0),
        "ambiguousRemainingCount": meta.get("ambiguous_remaining_count", 0),
        "resolvedByEquivalenceCount": meta.get("resolved_by_equivalence_count", 0),
        "equivalenceConflictsCount": meta.get("equivalence_conflicts_count", 0),
        "duplicatesCount": meta.get("duplicates_count", 0),
        "duplicatesCrossFileCount": meta.get("duplicates_cross_file_count", 0),
        "duplicatesSameFileCount": meta.get("duplicates_same_file_count", 0),
        "odus": entries,
    }
    BUILD_JSON.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    rows = []
    for e in entries:
        c = e["content"]
        rows.append(
            {
                "source_file": e.get("source_file", ""),
                "odu_key": e["odu_key"],
                "detected_name": c.get("name", ""),
                "family_guess": e.get("family_guess", ""),
                "orderNumber": c.get("orderNumber", ""),
                "has_descripcion": has_value(e, "descripcion"),
                "has_nace": has_value(e, "nace"),
                "has_rezo": has_value(e, "rezoYoruba"),
                "has_suyere": has_value(e, "suyereYoruba"),
                "has_obras": has_value(e, "obras"),
                "has_diceIfa": has_value(e, "diceIfa"),
                "has_ewes": has_value(e, "ewes"),
                "has_refranes": has_value(e, "refranes"),
                "has_eshu": has_value(e, "eshu"),
                "has_historias": has_value(e, "historiasYPatakies"),
                "has_predicciones": has_value(e, "predicciones"),
                "has_prohibiciones": has_value(e, "prohibiciones"),
                "has_recomendaciones": has_value(e, "recomendaciones"),
            }
        )

    with BUILD_REPORT_CSV.open("w", newline="", encoding="utf-8") as f:
        fields = [
            "source_file",
            "odu_key",
            "detected_name",
            "family_guess",
            "orderNumber",
            "has_descripcion",
            "has_nace",
            "has_rezo",
            "has_suyere",
            "has_obras",
            "has_diceIfa",
            "has_ewes",
            "has_refranes",
            "has_eshu",
            "has_historias",
            "has_predicciones",
            "has_prohibiciones",
            "has_recomendaciones",
        ]
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        for r in rows:
            writer.writerow(r)

    def count_has(field: str) -> int:
        return sum(1 for e in entries if has_value(e, field))

    missing_desc = [e["odu_key"] for e in entries if not has_value(e, "descripcion")]
    repeats_by_odu: Dict[str, List[str]] = meta.get("repeats_by_odu", {})  # type: ignore[assignment]
    duplicates: List[dict] = meta.get("duplicates", [])  # type: ignore[assignment]
    duplicates_cross_file: List[dict] = meta.get("duplicates_cross_file", [])  # type: ignore[assignment]
    duplicates_same_file: List[dict] = meta.get("duplicates_same_file", [])  # type: ignore[assignment]
    file_stats: List[dict] = meta.get("file_stats", [])  # type: ignore[assignment]
    ambiguous_by_file: List[str] = meta.get("ambiguous_by_file", [])  # type: ignore[assignment]
    pre_hits_by_file: List[str] = meta.get("pre_section_hits_by_file", [])  # type: ignore[assignment]
    accepted_boundary_audit: List[str] = meta.get("accepted_boundary_audit", [])  # type: ignore[assignment]
    rejected_boundary_audit: List[str] = meta.get("rejected_boundary_audit", [])  # type: ignore[assignment]
    ambiguous_boundary_audit: List[str] = meta.get("ambiguous_boundary_audit", [])  # type: ignore[assignment]
    resolved_by_equivalence: List[dict] = meta.get("resolved_by_equivalence", [])  # type: ignore[assignment]
    equivalence_conflicts: List[dict] = meta.get("equivalence_conflicts", [])  # type: ignore[assignment]

    total_sections_extracted = 0
    for field in SECTION_KEYS.values():
        total_sections_extracted += sum(1 for e in entries if has_value(e, field))

    md_lines = [
        "# Odù Import Report",
        "",
        f"- Source mode: `family_collection_img`",
        f"- Generated UTC: `{payload['generatedAtUtc']}`",
        f"- Total family docs processed: **{len(source_files)}**",
        f"- Total detected before canonical filter: **{meta.get('boundary_candidates_total', 0)}**",
        f"- Total canonical odù after filter: **{len(entries)}**",
        f"- Total rejected subentries: **{meta.get('rejected_subentries_total', 0)}**",
        f"- Total ambiguous remaining: **{meta.get('ambiguous_remaining_count', 0)}**",
        f"- Total resolved by equivalence: **{meta.get('resolved_by_equivalence_count', 0)}**",
        f"- Total equivalence conflicts: **{meta.get('equivalence_conflicts_count', 0)}**",
        f"- Total odù detected (before dedup): **{meta.get('total_detected_before_dedup', len(entries))}**",
        f"- Total odù unique (after dedup): **{len(entries)}**",
        f"- Duplicates count (all): **{meta.get('duplicates_count', 0)}**",
        f"- Duplicates count (cross-file): **{meta.get('duplicates_cross_file_count', 0)}**",
        f"- Duplicates count (same-file): **{meta.get('duplicates_same_file_count', 0)}**",
        f"- Total sections extracted (non-empty fields): **{total_sections_extracted}**",
        "",
        "## Count Per Family File",
        "",
        "| Source file | Family guess | Detected | Kept | Duplicates |",
        "|---|---|---:|---:|---:|",
    ]

    for item in file_stats:
        md_lines.append(
            f"| `{item.get('source_file','')}` | {item.get('family_guess','')} | {item.get('detected_count',0)} | {item.get('kept_count',0)} | {item.get('duplicates_count',0)} |"
        )

    md_lines.extend(
        [
            "",
            "## Section Presence Counts",
            "",
            f"- descripcion: {count_has('descripcion')}",
            f"- nace: {count_has('nace')}",
            f"- rezoYoruba: {count_has('rezoYoruba')}",
            f"- suyereYoruba: {count_has('suyereYoruba')}",
            f"- obras: {count_has('obras')}",
            f"- diceIfa: {count_has('diceIfa')}",
            f"- ewes: {count_has('ewes')}",
            f"- refranes: {count_has('refranes')}",
            f"- eshu: {count_has('eshu')}",
            f"- historiasYPatakies: {count_has('historiasYPatakies')}",
            f"- predicciones: {count_has('predicciones')}",
            f"- prohibiciones: {count_has('prohibiciones')}",
            f"- recomendaciones: {count_has('recomendaciones')}",
            "",
            "## Odù With Missing descripcion",
            "",
        ]
    )

    if missing_desc:
        md_lines.extend([f"- {k}" for k in missing_desc])
    else:
        md_lines.append("- None")

    md_lines.extend(["", "## Odù With Repeated Sections Merged", ""])
    if repeats_by_odu:
        for k, sections in repeats_by_odu.items():
            md_lines.append(f"- {k}: {', '.join(sections)}")
    else:
        md_lines.append("- None")

    md_lines.extend(["", "## Headings Resolved By Equivalence", ""])
    if resolved_by_equivalence:
        for item in resolved_by_equivalence[:300]:
            md_lines.append(
                f"- {item.get('source_file','')} :: {item.get('line','')} -> {item.get('resolved_to','')}"
            )
        if len(resolved_by_equivalence) > 300:
            md_lines.append(f"- ... ({len(resolved_by_equivalence)-300} more)")
    else:
        md_lines.append("- None")

    md_lines.extend(["", "## Ambiguous/Unmatched Odù Blocks", ""])
    if ambiguous_by_file:
        md_lines.extend([f"- {h}" for h in ambiguous_by_file[:500]])
        if len(ambiguous_by_file) > 500:
            md_lines.append(f"- ... ({len(ambiguous_by_file)-500} more)")
    else:
        md_lines.append("- None")

    BUILD_REPORT_MD.write_text("\n".join(md_lines).rstrip() + "\n", encoding="utf-8")

    unmatched_lines = [
        "# Odù Import Unmatched / Ambiguous",
        "",
        f"- Source mode: `family_collection_img`",
        "",
        "## Duplicates Across Family Files (kept first, skipped later ones)",
        "",
    ]
    if duplicates_cross_file:
        for d in duplicates_cross_file:
            unmatched_lines.append(
                f"- {d.get('odu_key','')}: kept `{d.get('kept_source_file','')}`, skipped `{d.get('duplicate_source_file','')}`"
            )
    else:
        unmatched_lines.append("- None")

    unmatched_lines.extend(["", "## Duplicates Within Same File (informational)", ""])
    if duplicates_same_file:
        for d in duplicates_same_file:
            unmatched_lines.append(
                f"- {d.get('odu_key','')}: file `{d.get('duplicate_source_file','')}`"
            )
    else:
        unmatched_lines.append("- None")

    unmatched_lines.extend(["", "## Ambiguous Odù Heading Candidates", ""])
    if ambiguous_by_file:
        unmatched_lines.extend([f"- {h}" for h in ambiguous_by_file])
    else:
        unmatched_lines.append("- None")

    unmatched_lines.extend(["", "## Section Headings Found Before First Odù Boundary", ""])
    if pre_hits_by_file:
        unmatched_lines.extend([f"- {h}" for h in pre_hits_by_file])
    else:
        unmatched_lines.append("- None")

    unmatched_lines.extend(["", "## Equivalence Resolution Conflicts", ""])
    if equivalence_conflicts:
        for c in equivalence_conflicts:
            unmatched_lines.append(
                f"- {c.get('source_file','')} :: {c.get('line','')} -> targets={c.get('targets', [])}"
            )
    else:
        unmatched_lines.append("- None")

    BUILD_UNMATCHED_MD.write_text("\n".join(unmatched_lines).rstrip() + "\n", encoding="utf-8")

    write_boundary_audit(
        source_files=source_files,
        accepted=accepted_boundary_audit,
        rejected=rejected_boundary_audit,
        ambiguous=ambiguous_boundary_audit,
        boundary_candidates_total=int(meta.get("boundary_candidates_total", 0) or 0),
        canonical_after_filter=len(entries),
        rejected_subentries_total=int(meta.get("rejected_subentries_total", 0) or 0),
    )


def write_boundary_audit(
    *,
    source_files: List[str],
    accepted: List[str],
    rejected: List[str],
    ambiguous: List[str],
    boundary_candidates_total: int,
    canonical_after_filter: int,
    rejected_subentries_total: int,
) -> None:
    lines: List[str] = [
        "# Odù Boundary Audit",
        "",
        "- Scope: canonical Odù-boundary pass",
        f"- Source files processed: **{len(source_files)}**",
        f"- Total detected before canonical filter: **{boundary_candidates_total}**",
        f"- Total canonical odù after filter: **{canonical_after_filter}**",
        f"- Total rejected subentries: **{rejected_subentries_total}**",
        f"- Total ambiguous remaining: **{len(ambiguous)}**",
        "",
        "## Accepted As Canonical Odù",
        "",
    ]

    if accepted:
        lines.extend([f"- {x}" for x in accepted])
    else:
        lines.append("- None")

    lines.extend(["", "## Rejected As Subentry/State", ""])
    if rejected:
        lines.extend([f"- {x}" for x in rejected])
    else:
        lines.append("- None")

    lines.extend(["", "## Ambiguous Headings", ""])
    if ambiguous:
        lines.extend([f"- {x}" for x in ambiguous])
    else:
        lines.append("- None")

    BUILD_BOUNDARY_AUDIT_MD.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def write_name_equivalence_report(
    *,
    eq_payload: Dict[str, object],
    meta_before: Dict[str, object],
    meta_after: Dict[str, object],
    canonical_before: int,
    canonical_after: int,
) -> None:
    aliases_parsed = int(eq_payload.get("total_alias_records", 0) or 0)
    resolved = meta_after.get("resolved_by_equivalence", [])
    resolved_list = resolved if isinstance(resolved, list) else []
    conflicts = meta_after.get("equivalence_conflicts", [])
    conflicts_list = conflicts if isinstance(conflicts, list) else []

    ambiguous_before = int(meta_before.get("ambiguous_remaining_count", 0) or 0)
    ambiguous_after = int(meta_after.get("ambiguous_remaining_count", 0) or 0)
    resolved_count = len(resolved_list)

    lines: List[str] = [
        "# Odù Name Equivalence Report",
        "",
        f"- Source equivalence DOCX: `{eq_payload.get('source_docx','')}`",
        f"- Total aliases parsed: **{aliases_parsed}**",
        f"- Aliases actually used in import resolution: **{resolved_count}**",
        f"- Canonical odù before equivalence pass: **{canonical_before}**",
        f"- Canonical odù after equivalence pass: **{canonical_after}**",
        f"- Total ambiguous before: **{ambiguous_before}**",
        f"- Total ambiguous after: **{ambiguous_after}**",
        f"- Total resolved by equivalence: **{resolved_count}**",
        f"- Headings mapped to conflicts: **{len(conflicts_list)}**",
        "",
        "## Ambiguous Headings Resolved By Equivalence",
        "",
    ]

    if resolved_list:
        for item in resolved_list:
            lines.append(
                f"- {item.get('source_file','')} :: {item.get('line','')} -> {item.get('resolved_to','')}"
            )
    else:
        lines.append("- None")

    lines.extend(["", "## Remaining Unresolved Ambiguous Headings", ""])
    remaining_ambiguous = meta_after.get("ambiguous_by_file", [])
    if isinstance(remaining_ambiguous, list) and remaining_ambiguous:
        lines.extend([f"- {x}" for x in remaining_ambiguous[:400]])
        if len(remaining_ambiguous) > 400:
            lines.append(f"- ... ({len(remaining_ambiguous)-400} more)")
    else:
        lines.append("- None")

    lines.extend(["", "## Equivalence Mapping Conflicts", ""])
    if conflicts_list:
        for c in conflicts_list:
            lines.append(
                f"- {c.get('source_file','')} :: {c.get('line','')} -> targets={c.get('targets', [])}"
            )
    else:
        lines.append("- None")

    BUILD_NAME_EQ_REPORT_MD.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def run_single_docx_mode(
    docx_path: Path,
    *,
    eq_payload: Optional[Dict[str, object]] = None,
) -> None:
    if not docx_path.exists():
        available = list_available_docx()
        print(f"ERROR: required source DOCX not found: {docx_path}")
        print("Available .docx files in repo:")
        for p in available:
            print(f"- {p}")
        raise SystemExit(2)

    source_file = str(docx_path.relative_to(ROOT)) if docx_path.is_relative_to(ROOT) else str(docx_path)
    family_guess = family_guess_from_filename(docx_path)
    paragraphs = load_docx_paragraphs(docx_path)
    entries, meta_single = parse_docx_to_entries(
        paragraphs, source_file, family_guess, eq_payload=eq_payload
    )

    # emulate merged meta shape
    repeats_by_odu = {}
    for e in entries:
        rs = e.pop("_repeated_sections", [])
        if rs:
            repeats_by_odu[e["odu_key"]] = rs

    meta = {
        "total_detected_before_dedup": len(entries),
        "total_unique_after_dedup": len(entries),
        "duplicates": [],
        "duplicates_count": 0,
        "duplicates_cross_file_count": 0,
        "duplicates_same_file_count": 0,
        "duplicates_cross_file": [],
        "duplicates_same_file": [],
        "file_stats": [
            {
                "source_file": source_file,
                "family_guess": family_guess,
                "detected_count": len(entries),
                "kept_count": len(entries),
                "duplicates_count": 0,
            }
        ],
        "repeats_by_odu": repeats_by_odu,
        "ambiguous_by_file": [f"{source_file} :: {x}" for x in meta_single.get("ambiguous_headings", [])],
        "pre_section_hits_by_file": [f"{source_file} :: {x}" for x in meta_single.get("pre_odu_section_hits", [])],
        "accepted_boundary_audit": [
            f"{source_file} :: {x.get('line','')} [{x.get('reason','')}]"
            for x in meta_single.get("accepted_boundary_headings", [])
            if isinstance(x, dict)
        ],
        "rejected_boundary_audit": [
            f"{source_file} :: {x.get('line','')} [{x.get('reason','')}]"
            for x in meta_single.get("rejected_boundary_headings", [])
            if isinstance(x, dict)
        ],
        "ambiguous_boundary_audit": [
            f"{source_file} :: {x.get('line','')} [{x.get('reason','')}]"
            for x in meta_single.get("ambiguous_boundary_headings", [])
            if isinstance(x, dict)
        ],
        "boundary_candidates_total": int(meta_single.get("boundary_candidates_total", 0) or 0),
        "rejected_subentries_total": int(meta_single.get("rejected_subentries_total", 0) or 0),
        "ambiguous_remaining_count": len(meta_single.get("ambiguous_boundary_headings", [])),
        "resolved_by_equivalence_count": len(meta_single.get("resolved_by_equivalence", [])),
        "resolved_by_equivalence": meta_single.get("resolved_by_equivalence", []),
        "equivalence_conflicts_count": len(meta_single.get("equivalence_conflicts", [])),
        "equivalence_conflicts": meta_single.get("equivalence_conflicts", []),
    }

    write_outputs(entries, meta, [source_file])
    collapsed_entries, collapse_meta = collapse_entries_by_canonical_key(
        entries, eq_payload=eq_payload
    )
    write_canonical_collapse_outputs(
        collapsed_entries=collapsed_entries,
        collapse_meta=collapse_meta,
        source_files=[source_file],
        import_meta=meta,
    )

    keys = [e["odu_key"] for e in entries]
    boundary_candidates_total = int(meta.get("boundary_candidates_total", 0) or 0)
    rejected_subentries_total = int(meta.get("rejected_subentries_total", 0) or 0)
    ambiguous_remaining = int(meta.get("ambiguous_remaining_count", 0) or 0)
    print(f"Processed files: 1 ({source_file})")
    print(f"Total detected before canonical filter: {boundary_candidates_total}")
    print(f"Total canonical odù after filter: {len(entries)}")
    print(f"Total rejected subentries: {rejected_subentries_total}")
    print(f"Total ambiguous remaining: {ambiguous_remaining}")
    print(f"Total Odù found: {len(entries)}")
    print("First 20 odù keys:")
    for k in keys[:20]:
        print(f"- {k}")
    print("Duplicates found: 0")
    print(f"Ambiguous blocks count: {len(meta['ambiguous_by_file'])}")
    print(f"Wrote: {BUILD_JSON}")
    print(f"Wrote: {BUILD_COLLAPSED_JSON}")
    print(f"Wrote: {BUILD_REPORT_MD}")
    print(f"Wrote: {BUILD_REPORT_CSV}")
    print(f"Wrote: {BUILD_UNMATCHED_MD}")
    print(f"Wrote: {BUILD_BOUNDARY_AUDIT_MD}")
    print(f"Wrote: {BUILD_CANONICAL_COLLAPSE_REPORT_MD}")
    print(f"Wrote: {BUILD_CANONICAL_COLLAPSE_REPORT_CSV}")


def run_family_collection_mode(img_dir: Path) -> None:
    paths = discover_family_docx_files(img_dir)
    if not NAME_EQ_DOCX.exists():
        raise SystemExit(
            f"Missing equivalence source DOCX: {NAME_EQ_DOCX}\n"
            "Required to run equivalence resolution pass."
        )

    eq_payload = parse_equivalence_docx(NAME_EQ_DOCX)

    # Baseline without equivalence pass.
    entries_before, meta_before = merge_entries_from_files(paths, eq_payload=None)
    # Final with equivalence-enabled pass.
    entries, meta = merge_entries_from_files(paths, eq_payload=eq_payload)

    source_files = [str(p.relative_to(ROOT)) for p in paths]
    write_outputs(entries, meta, source_files)
    write_name_equivalence_report(
        eq_payload=eq_payload,
        meta_before=meta_before,
        meta_after=meta,
        canonical_before=len(entries_before),
        canonical_after=len(entries),
    )
    collapsed_entries, collapse_meta = collapse_entries_by_canonical_key(
        entries, eq_payload=eq_payload
    )
    write_canonical_collapse_outputs(
        collapsed_entries=collapsed_entries,
        collapse_meta=collapse_meta,
        source_files=source_files,
        import_meta=meta,
    )

    keys = [e["odu_key"] for e in entries]
    duplicates: List[dict] = meta.get("duplicates", [])  # type: ignore[assignment]
    duplicates_cross_file: List[dict] = meta.get("duplicates_cross_file", [])  # type: ignore[assignment]
    duplicates_same_file: List[dict] = meta.get("duplicates_same_file", [])  # type: ignore[assignment]
    ambiguous: List[str] = meta.get("ambiguous_by_file", [])  # type: ignore[assignment]
    boundary_candidates_total = int(meta.get("boundary_candidates_total", 0) or 0)
    rejected_subentries_total = int(meta.get("rejected_subentries_total", 0) or 0)
    ambiguous_remaining = int(meta.get("ambiguous_remaining_count", 0) or 0)
    canonical_before = len(entries_before)
    ambiguous_before = int(meta_before.get("ambiguous_remaining_count", 0) or 0)
    resolved_by_equivalence = int(meta.get("resolved_by_equivalence_count", 0) or 0)
    canonical_after_collapse = int(collapse_meta.get("canonical_after_collapse", 0) or 0)
    collapse_groups_total = int(collapse_meta.get("collapse_groups_total", 0) or 0)
    total_secondary_removed = int(collapse_meta.get("total_secondary_entries_removed", 0) or 0)
    total_sections_merged = int(
        collapse_meta.get("total_sections_merged_from_secondaries", 0) or 0
    )

    print("Processed files:")
    for sf in source_files:
        print(f"- {sf}")
    print(f"Canonical odù before equivalence pass: {canonical_before}")
    print(f"Canonical odù after equivalence pass: {len(entries)}")
    print(f"Total ambiguous before: {ambiguous_before}")
    print(f"Total ambiguous after: {ambiguous_remaining}")
    print(f"Total resolved by equivalence: {resolved_by_equivalence}")
    print(f"Total detected before canonical filter: {boundary_candidates_total}")
    print(f"Total canonical odù after filter: {len(entries)}")
    print(f"Canonical before collapse: {len(entries)}")
    print(f"Canonical after collapse: {canonical_after_collapse}")
    print(f"Total collapse groups: {collapse_groups_total}")
    print(f"Total secondary entries removed: {total_secondary_removed}")
    print(f"Total sections merged from secondaries: {total_sections_merged}")
    print(f"Total rejected subentries: {rejected_subentries_total}")
    print(f"Total ambiguous remaining: {ambiguous_remaining}")
    print(f"Total Odù found (unique): {len(entries)}")
    print(f"Total Odù detected (before dedup): {meta.get('total_detected_before_dedup', len(entries))}")
    print("First 20 odù keys:")
    for k in keys[:20]:
        print(f"- {k}")
    print(f"Duplicates found (all): {len(duplicates)}")
    print(f"Duplicates found (cross-file): {len(duplicates_cross_file)}")
    print(f"Duplicates found (same-file): {len(duplicates_same_file)}")
    if duplicates_cross_file:
        for d in duplicates_cross_file[:20]:
            print(
                f"- {d.get('odu_key','')}: kept {d.get('kept_source_file','')}, skipped {d.get('duplicate_source_file','')}"
            )
        if len(duplicates_cross_file) > 20:
            print(f"- ... ({len(duplicates_cross_file)-20} more)")
    print(f"Ambiguous blocks count: {len(ambiguous)}")

    print(f"Wrote: {BUILD_JSON}")
    print(f"Wrote: {BUILD_COLLAPSED_JSON}")
    print(f"Wrote: {BUILD_REPORT_MD}")
    print(f"Wrote: {BUILD_REPORT_CSV}")
    print(f"Wrote: {BUILD_UNMATCHED_MD}")
    print(f"Wrote: {BUILD_BOUNDARY_AUDIT_MD}")
    print(f"Wrote: {BUILD_NAME_EQ_JSON}")
    print(f"Wrote: {BUILD_NAME_EQ_REPORT_MD}")
    print(f"Wrote: {BUILD_CANONICAL_COLLAPSE_REPORT_MD}")
    print(f"Wrote: {BUILD_CANONICAL_COLLAPSE_REPORT_CSV}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Import Odù corpus from DOCX files")
    parser.add_argument(
        "--docx",
        default="",
        help="Optional: single DOCX mode (if omitted, processes IMG family collection)",
    )
    parser.add_argument(
        "--img-dir",
        default=str(DEFAULT_IMG_DIR),
        help="Directory containing family collection DOCX files",
    )
    args = parser.parse_args()

    if args.docx.strip():
        run_single_docx_mode(Path(args.docx).expanduser().resolve())
    else:
        run_family_collection_mode(Path(args.img_dir).expanduser().resolve())


if __name__ == "__main__":
    main()
