#!/usr/bin/env python3
"""Family coverage audit on top of collapsed DOCX import outputs.

Inputs:
- build/odu_content_v2_collapsed.json
- build/odu_import_unmatched.md (informational)
- build/odu_boundary_audit.md

Outputs:
- build/odu_family_coverage_report.md
- build/odu_family_coverage_report.csv
- build/odu_missing_candidates.md

Safety:
- Does NOT modify assets/odu_content.json
- Does NOT modify assets/odu_content_patched.json
"""

from __future__ import annotations

import csv
import json
import re
import unicodedata
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple


ROOT = Path(__file__).resolve().parents[1]
COLLAPSED_JSON = ROOT / "build" / "odu_content_v2_collapsed.json"
BOUNDARY_AUDIT_MD = ROOT / "build" / "odu_boundary_audit.md"
UNMATCHED_MD = ROOT / "build" / "odu_import_unmatched.md"

OUT_REPORT_MD = ROOT / "build" / "odu_family_coverage_report.md"
OUT_REPORT_CSV = ROOT / "build" / "odu_family_coverage_report.csv"
OUT_MISSING_MD = ROOT / "build" / "odu_missing_candidates.md"


FAMILY_ORDER: List[Tuple[str, str]] = [
    ("OGBE", "OGBE"),
    ("OYEKUN", "OYEKUN"),
    ("IWORI", "IWORI"),
    ("ODI", "ODI"),
    ("IROSO", "IROSO"),
    ("OWONRIN", "OJUANI / OWONRIN"),
    ("OBARA", "OBARA"),
    ("OKANRAN", "OKANA / OKANRAN"),
    ("OGUNDA", "OGUNDA"),
    ("OSA", "OSA"),
    ("IKA", "IKA"),
    ("OTURUPON", "OTRUPON / OTURUPON"),
    ("OTURA", "OTURA"),
    ("IRETE", "IRETE"),
    ("OSE", "OSHE / OSE"),
    ("OFUN", "OFUN"),
]


FAMILY_MAP: Dict[str, str] = {
    "OGBE": "OGBE",
    "EJIOGBE": "OGBE",
    "OYEKUN": "OYEKUN",
    "OYEKU": "OYEKUN",
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


STATE_TOKENS = {
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


CANONICAL_FAMILIES = {x[0] for x in FAMILY_ORDER}


def normalize_upper(text: str) -> str:
    s = unicodedata.normalize("NFD", text or "")
    s = "".join(ch for ch in s if unicodedata.category(ch) != "Mn")
    s = s.upper()
    s = re.sub(r"[_\-]", " ", s)
    s = re.sub(r"[^A-Z0-9\s/]", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def family_from_heading(heading: str) -> Optional[str]:
    toks = normalize_upper(heading).split()
    for tok in toks:
        fam = FAMILY_MAP.get(tok)
        if fam:
            return fam
    return None


def family_from_source_file(source_file: str) -> Optional[str]:
    upper = normalize_upper(source_file)
    for raw, fam in FAMILY_MAP.items():
        if raw in upper:
            return fam
    return None


def split_canonical_key_family(canonical_key: str) -> Optional[str]:
    toks = normalize_upper(canonical_key).split()
    if not toks:
        return None
    return FAMILY_MAP.get(toks[0])


def heading_tokens(heading: str) -> List[str]:
    toks = normalize_upper(heading).split()
    if toks and toks[0] == "BABA":
        toks = toks[1:]
    return toks


def mapped_family_tokens(tokens: List[str]) -> List[str]:
    mapped: List[str] = []
    for t in tokens:
        fam = FAMILY_MAP.get(t)
        if fam:
            mapped.append(fam)
    return mapped


def has_repeated_family(tokens: List[str]) -> bool:
    seen: set[str] = set()
    for fam in mapped_family_tokens(tokens):
        if fam in seen:
            return True
        seen.add(fam)
    return False


def looks_like_odu_x_odu_y_pattern(tokens: List[str]) -> bool:
    # Pattern: <ODU> <X> <ODU> <Y>
    if len(tokens) < 4:
        return False
    return FAMILY_MAP.get(tokens[0]) is not None and FAMILY_MAP.get(tokens[2]) is not None


def matches_canonical_meji_or_pair(tokens: List[str]) -> bool:
    if not tokens:
        return False
    if len(tokens) == 1 and tokens[0] == "EJIOGBE":
        return True
    if len(tokens) == 2 and tokens[1] == "MEJI":
        return FAMILY_MAP.get(tokens[0]) in CANONICAL_FAMILIES
    if len(tokens) == 2:
        f1 = FAMILY_MAP.get(tokens[0])
        f2 = FAMILY_MAP.get(tokens[1])
        if f1 in CANONICAL_FAMILIES and f2 in CANONICAL_FAMILIES:
            return True
    return False


@dataclass
class BoundaryHeadingRecord:
    source_file: str
    heading: str
    reason: str
    family: str
    raw_line: str


def parse_boundary_audit(path: Path) -> Dict[str, List[BoundaryHeadingRecord]]:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()

    section: Optional[str] = None
    out: Dict[str, List[BoundaryHeadingRecord]] = {
        "accepted": [],
        "rejected": [],
        "ambiguous": [],
    }

    for line in lines:
        t = line.strip()
        if t == "## Accepted As Canonical Odù":
            section = "accepted"
            continue
        if t == "## Rejected As Subentry/State":
            section = "rejected"
            continue
        if t == "## Ambiguous Headings":
            section = "ambiguous"
            continue
        if not section or not t.startswith("- "):
            continue
        if t == "- None":
            continue

        m = re.match(r"^- (.+?) :: (.+?) \[(.+)\]$", t)
        if not m:
            continue

        source_file = m.group(1).strip()
        heading = m.group(2).strip()
        reason = m.group(3).strip()
        family = family_from_heading(heading) or family_from_source_file(source_file) or "UNKNOWN"

        out[section].append(
            BoundaryHeadingRecord(
                source_file=source_file,
                heading=heading,
                reason=reason,
                family=family,
                raw_line=t,
            )
        )
    return out


def score_candidate(rec: BoundaryHeadingRecord) -> int:
    toks = normalize_upper(rec.heading).split()
    score = 0
    if "canonical_prefix_with_extra_tokens" in rec.reason:
        score += 4
    if "single_family_without_meji" in rec.reason:
        score += 3
    if "canonical_prefix_noncanonical_second" in rec.reason:
        score += 3
    if "accepted_but_no_nearby_section" in rec.reason:
        score += 2
    if len(toks) <= 4:
        score += 2
    fam_tokens = sum(1 for tk in toks if FAMILY_MAP.get(tk))
    if fam_tokens >= 2:
        score += 2
    if len(toks) >= 8:
        score -= 2
    return score


def classify_recoverable(
    rec: BoundaryHeadingRecord,
) -> Tuple[Optional[str], str]:
    """Returns (bucket, reason):
    - recoverable_canonical
    - recoverable_alias_or_subtitle
    - None
    """
    toks = heading_tokens(rec.heading)
    tok_set = set(toks)

    if rec.family == "UNKNOWN":
        return None, "unknown_family"
    if tok_set & STATE_TOKENS:
        return None, "contains_state_token"
    if not toks:
        return None, "empty_tokens"

    token_count = len(toks)
    repeated_family = has_repeated_family(toks)
    odu_x_odu_y = looks_like_odu_x_odu_y_pattern(toks)
    canonical_shape = matches_canonical_meji_or_pair(toks)

    # Rule 1: canonical recoverable.
    if (
        canonical_shape
        and token_count <= 3
        and not repeated_family
        and not odu_x_odu_y
    ):
        return "recoverable_canonical", "canonical_meji_or_pair"

    # Rule 2/3/4: alias/subtitle recoverable.
    if repeated_family:
        return "recoverable_alias_or_subtitle", "repeated_family_name"
    if token_count > 3:
        return "recoverable_alias_or_subtitle", "token_count_gt_3"
    if odu_x_odu_y:
        return "recoverable_alias_or_subtitle", "odu_x_odu_y_pattern"

    return None, "not_canonical_or_alias"


def main() -> None:
    if not COLLAPSED_JSON.exists():
        raise SystemExit(f"Missing input: {COLLAPSED_JSON}")
    if not BOUNDARY_AUDIT_MD.exists():
        raise SystemExit(f"Missing input: {BOUNDARY_AUDIT_MD}")
    if not UNMATCHED_MD.exists():
        raise SystemExit(f"Missing input: {UNMATCHED_MD}")

    collapsed = json.loads(COLLAPSED_JSON.read_text(encoding="utf-8"))
    odus: List[dict] = collapsed.get("odus", [])

    parsed = parse_boundary_audit(BOUNDARY_AUDIT_MD)
    rejected = parsed["rejected"]
    ambiguous = parsed["ambiguous"]

    by_family_count: Dict[str, int] = defaultdict(int)
    for entry in odus:
        canonical_key = str(entry.get("canonical_key", "") or entry.get("odu_key", ""))
        fam = split_canonical_key_family(canonical_key) or "UNKNOWN"
        by_family_count[fam] += 1

    ambiguous_by_family: Dict[str, List[BoundaryHeadingRecord]] = defaultdict(list)
    for rec in ambiguous:
        ambiguous_by_family[rec.family].append(rec)

    rejected_by_family: Dict[str, List[BoundaryHeadingRecord]] = defaultdict(list)
    for rec in rejected:
        rejected_by_family[rec.family].append(rec)

    recoverable_canonical: List[BoundaryHeadingRecord] = []
    recoverable_alias: List[BoundaryHeadingRecord] = []
    classified_reasons: Dict[str, str] = {}

    for rec in ambiguous:
        bucket, reason = classify_recoverable(rec)
        classified_reasons[rec.raw_line] = reason
        if bucket == "recoverable_canonical":
            recoverable_canonical.append(rec)
        elif bucket == "recoverable_alias_or_subtitle":
            recoverable_alias.append(rec)

    recoverable_canonical_by_family: Dict[str, List[BoundaryHeadingRecord]] = defaultdict(list)
    recoverable_alias_by_family: Dict[str, List[BoundaryHeadingRecord]] = defaultdict(list)
    for rec in recoverable_canonical:
        recoverable_canonical_by_family[rec.family].append(rec)
    for rec in recoverable_alias:
        recoverable_alias_by_family[rec.family].append(rec)

    recoverable_canonical_sorted = sorted(
        recoverable_canonical,
        key=lambda r: (-score_candidate(r), r.family, len(normalize_upper(r.heading)), r.heading),
    )
    recoverable_alias_sorted = sorted(
        recoverable_alias,
        key=lambda r: (-score_candidate(r), r.family, len(normalize_upper(r.heading)), r.heading),
    )

    rows: List[dict] = []
    for fam_key, fam_label in FAMILY_ORDER:
        amb = ambiguous_by_family.get(fam_key, [])
        rej = rejected_by_family.get(fam_key, [])
        rec_can = recoverable_canonical_by_family.get(fam_key, [])
        rec_alias = recoverable_alias_by_family.get(fam_key, [])

        rows.append(
            {
                "family_key": fam_key,
                "family_label": fam_label,
                "canonical_entries_count": by_family_count.get(fam_key, 0),
                "ambiguous_headings_count": len(amb),
                "rejected_subentries_count": len(rej),
                "recoverable_canonical_count": len(rec_can),
                "recoverable_alias_or_subtitle_count": len(rec_alias),
                "ambiguous_sample": " | ".join(x.heading for x in amb[:5]),
                "rejected_sample": " | ".join(x.heading for x in rej[:5]),
                "recoverable_canonical_sample": " | ".join(x.heading for x in rec_can[:5]),
                "recoverable_alias_or_subtitle_sample": " | ".join(
                    x.heading for x in rec_alias[:5]
                ),
            }
        )

    with OUT_REPORT_CSV.open("w", newline="", encoding="utf-8") as f:
        fields = [
            "family_key",
            "family_label",
            "canonical_entries_count",
            "ambiguous_headings_count",
            "rejected_subentries_count",
            "recoverable_canonical_count",
            "recoverable_alias_or_subtitle_count",
            "ambiguous_sample",
            "rejected_sample",
            "recoverable_canonical_sample",
            "recoverable_alias_or_subtitle_sample",
        ]
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)

    family_counts_sorted = sorted(
        [(label, by_family_count.get(key, 0)) for key, label in FAMILY_ORDER],
        key=lambda x: (x[1], x[0]),
    )

    md_lines: List[str] = [
        "# Odù Family Coverage Report",
        "",
        f"- Input collapsed JSON: `{COLLAPSED_JSON}`",
        f"- Input unmatched report: `{UNMATCHED_MD}`",
        f"- Input boundary audit: `{BOUNDARY_AUDIT_MD}`",
        f"- Total collapsed canonical odù: **{len(odus)}**",
        f"- Total ambiguous remaining: **{len(ambiguous)}**",
        f"- recoverable_canonical: **{len(recoverable_canonical)}**",
        f"- recoverable_alias_or_subtitle: **{len(recoverable_alias)}**",
        "",
        "## Family Counts (Ascending)",
        "",
    ]
    for label, count in family_counts_sorted:
        md_lines.append(f"- {label}: {count}")

    md_lines.extend(
        [
            "",
            "## Coverage by Family",
            "",
            "| Family | Canonical entries | Ambiguous | Rejected subentries | recoverable_canonical | recoverable_alias_or_subtitle |",
            "|---|---:|---:|---:|---:|---:|",
        ]
    )

    for row in rows:
        md_lines.append(
            f"| {row['family_label']} | {row['canonical_entries_count']} | {row['ambiguous_headings_count']} | {row['rejected_subentries_count']} | {row['recoverable_canonical_count']} | {row['recoverable_alias_or_subtitle_count']} |"
        )

    md_lines.extend(["", "## Top 20 Canonical Recoverables", ""])
    if recoverable_canonical_sorted:
        for rec in recoverable_canonical_sorted[:20]:
            md_lines.append(
                f"- [{rec.family}] `{rec.heading}` ({rec.source_file}) reason=`{rec.reason}` score={score_candidate(rec)}"
            )
    else:
        md_lines.append("- None")

    md_lines.extend(["", "## Top 20 Alias/Subtitle Recoverables", ""])
    if recoverable_alias_sorted:
        for rec in recoverable_alias_sorted[:20]:
            md_lines.append(
                f"- [{rec.family}] `{rec.heading}` ({rec.source_file}) reason=`{rec.reason}` score={score_candidate(rec)}"
            )
    else:
        md_lines.append("- None")

    OUT_REPORT_MD.write_text("\n".join(md_lines).rstrip() + "\n", encoding="utf-8")

    missing_lines: List[str] = [
        "# Odù Missing Candidates (Recoverable)",
        "",
        f"- Generated from ambiguous headings in `{BOUNDARY_AUDIT_MD}`",
        f"- Total ambiguous remaining: **{len(ambiguous)}**",
        f"- recoverable_canonical: **{len(recoverable_canonical)}**",
        f"- recoverable_alias_or_subtitle: **{len(recoverable_alias)}**",
        "",
    ]

    for fam_key, fam_label in FAMILY_ORDER:
        fam_recoverable_canonical = sorted(
            recoverable_canonical_by_family.get(fam_key, []),
            key=lambda r: (-score_candidate(r), len(normalize_upper(r.heading)), r.heading),
        )
        fam_recoverable_alias = sorted(
            recoverable_alias_by_family.get(fam_key, []),
            key=lambda r: (-score_candidate(r), len(normalize_upper(r.heading)), r.heading),
        )
        missing_lines.append(f"## {fam_label}")
        missing_lines.append("")
        missing_lines.append("### recoverable_canonical")
        missing_lines.append("")
        if fam_recoverable_canonical:
            for rec in fam_recoverable_canonical:
                missing_lines.append(
                    f"- `{rec.heading}` | source: `{rec.source_file}` | reason: `{rec.reason}` | score: {score_candidate(rec)}"
                )
        else:
            missing_lines.append("- None")
        missing_lines.append("")
        missing_lines.append("### recoverable_alias_or_subtitle")
        missing_lines.append("")
        if fam_recoverable_alias:
            for rec in fam_recoverable_alias:
                reason = classified_reasons.get(rec.raw_line, "")
                missing_lines.append(
                    f"- `{rec.heading}` | source: `{rec.source_file}` | reason: `{rec.reason}` | alias_reason: `{reason}` | score: {score_candidate(rec)}"
                )
        else:
            missing_lines.append("- None")
        missing_lines.append("")

    OUT_MISSING_MD.write_text("\n".join(missing_lines).rstrip() + "\n", encoding="utf-8")

    print(f"Total collapsed canonical odù: {len(odus)}")
    print("Family counts sorted ascending:")
    for label, count in family_counts_sorted:
        print(f"- {label}: {count}")
    print("Top 20 canonical recoverables:")
    for rec in recoverable_canonical_sorted[:20]:
        print(
            f"- [{rec.family}] {rec.heading} | {rec.source_file} | reason={rec.reason} | score={score_candidate(rec)}"
        )
    print("Top 20 alias/subtitle recoverables:")
    for rec in recoverable_alias_sorted[:20]:
        print(
            f"- [{rec.family}] {rec.heading} | {rec.source_file} | reason={rec.reason} | score={score_candidate(rec)}"
        )
    print(f"Total ambiguous remaining: {len(ambiguous)}")
    print(f"recoverable_canonical count: {len(recoverable_canonical)}")
    print(f"recoverable_alias_or_subtitle count: {len(recoverable_alias)}")
    print(f"Wrote: {OUT_REPORT_MD}")
    print(f"Wrote: {OUT_REPORT_CSV}")
    print(f"Wrote: {OUT_MISSING_MD}")


if __name__ == "__main__":
    main()
