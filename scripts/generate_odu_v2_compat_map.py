#!/usr/bin/env python3
import csv
import json
import re
import unicodedata
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

ROOT = Path(__file__).resolve().parents[1]
OLD_PATH = ROOT / "assets/odu_content_patched.json"
V2_PATH = ROOT / "assets/odu_content_v2_ready.json"
EQUIV_PATH = ROOT / "build/odu_name_equivalences.json"
ALIASES_PATH = ROOT / "assets/aliases.json"
REPO_PATH = ROOT / "lib/odu_content_repository.dart"
OUT_MAP_PATH = ROOT / "assets/odu_key_compat_map.json"
OUT_MD_PATH = ROOT / "build/odu_v2_missing_compat_report.md"
OUT_CSV_PATH = ROOT / "build/odu_v2_missing_compat_report.csv"

GENERIC_FAMILY_MAP = {
    "OJUANI": "OWONRIN",
    "OWONRIN": "OWONRIN",
    "OKANA": "OKANRAN",
    "OKANRAN": "OKANRAN",
    "OSHE": "OSE",
    "OSE": "OSE",
    "OTRUPON": "OTURUPON",
    "OTURUPON": "OTURUPON",
    "OYEKUN": "OYEKU",
    "OYEKU": "OYEKU",
    "OYECUN": "OYEKU",
}

WORD_REPLACEMENTS = {
    "OJUANI": ["OWONRIN"],
    "OWONRIN": ["OJUANI"],
    "OKANA": ["OKANRAN"],
    "OKANRAN": ["OKANA"],
    "OSHE": ["OSE"],
    "OSE": ["OSHE"],
    "OTRUPON": ["OTURUPON"],
    "OTURUPON": ["OTRUPON"],
    "OYEKUN": ["OYEKU"],
    "OYEKU": ["OYEKUN"],
    "OYECUN": ["OYEKUN", "OYEKU"],
}

PHRASE_REPLACEMENTS = {
    "BABA OGBE": ["EJIOGBE", "BABA EJIOGBE", "EJI OGBE", "OGBE MEJI"],
    "BABA EJIOGBE": ["EJIOGBE", "BABA OGBE", "EJI OGBE", "OGBE MEJI"],
    "EJI OGBE": ["EJIOGBE", "BABA OGBE", "BABA EJIOGBE", "OGBE MEJI"],
    "OGBE MEJI": ["EJIOGBE", "BABA OGBE", "BABA EJIOGBE", "EJI OGBE"],
    "BABA ODI MEJI": ["ODI MEJI"],
    "BABA OSHE MEJI": ["OSHE MEJI", "OSE MEJI"],
    "BABA OTURA MEJI": ["OTURA MEJI"],
    "OSHE MEJI": ["BABA OSHE MEJI"],
    "OTURA MEJI": ["BABA OTURA MEJI"],
    "ODI MEJI": ["BABA ODI MEJI"],
}


@dataclass
class Suggestion:
    method: str
    candidate_name: str
    resolved_key: str
    confidence: str


def normalize_key(text: str) -> str:
    text = text or ""
    text = text.upper().strip()
    text = "".join(
        c
        for c in unicodedata.normalize("NFD", text)
        if unicodedata.category(c) != "Mn"
    )
    text = text.replace("_", " ").replace("-", " ")
    text = re.sub(r"[^A-Z0-9 ]+", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def parse_legacy_aliases() -> Dict[str, str]:
    text = REPO_PATH.read_text(encoding="utf-8")
    block_match = re.search(
        r"const\s+Map<String,\s*String>\s+_legacyOduAliases\s*=\s*<String,\s*String>\{([\s\S]*?)\};",
        text,
    )
    if not block_match:
        return {}
    block = block_match.group(1)
    pairs = re.findall(r"'([^']+)'\s*:\s*'([^']+)'", block)
    return {normalize_key(a): b for a, b in pairs}


def build_v2_lookup(v2_odu: dict) -> Tuple[Dict[str, Set[str]], Dict[str, str]]:
    lookup: Dict[str, Set[str]] = defaultdict(set)
    key_to_display: Dict[str, str] = {}
    for key, payload in v2_odu.items():
        if not isinstance(key, str):
            continue
        key_to_display[key] = key
        norm_key = normalize_key(key)
        lookup[norm_key].add(key)
        content = payload.get("content") if isinstance(payload, dict) else None
        if isinstance(content, dict):
            name = content.get("name")
            if isinstance(name, str) and name.strip():
                lookup[normalize_key(name)].add(key)
    return lookup, key_to_display


def generate_name_variants(name: str) -> Set[str]:
    start = normalize_key(name)
    if not start:
        return set()
    variants = {start}

    if start.startswith("BABA "):
        variants.add(start.replace("BABA ", "", 1).strip())

    # Phrase-level variants for known Meji naming differences.
    for base in list(variants):
        for alt in PHRASE_REPLACEMENTS.get(base, []):
            variants.add(normalize_key(alt))

    # Token-level substitutions (single pass per token, bounded).
    expanded = set(variants)
    for value in list(variants):
        tokens = value.split()
        for i, tok in enumerate(tokens):
            if tok not in WORD_REPLACEMENTS:
                continue
            for repl in WORD_REPLACEMENTS[tok]:
                cloned = list(tokens)
                cloned[i] = repl
                expanded.add(" ".join(cloned))

    # Phrase variants after token expansion too.
    for value in list(expanded):
        for alt in PHRASE_REPLACEMENTS.get(value, []):
            expanded.add(normalize_key(alt))

    return {v for v in expanded if v}


def resolve_to_v2_keys(candidate_name: str, v2_lookup: Dict[str, Set[str]]) -> Set[str]:
    resolved: Set[str] = set()
    for variant in generate_name_variants(candidate_name):
        resolved.update(v2_lookup.get(variant, set()))
    return resolved


def pick_unique_resolved(candidate_name: str, v2_lookup: Dict[str, Set[str]]) -> Tuple[Optional[str], Set[str]]:
    resolved = resolve_to_v2_keys(candidate_name, v2_lookup)
    if len(resolved) == 1:
        return next(iter(resolved)), resolved
    return None, resolved


def build_equivalence_maps(records: List[dict]) -> Tuple[Dict[str, str], Dict[str, str], Dict[str, str]]:
    old_to_canonical: Dict[str, str] = {}
    new_to_canonical: Dict[str, str] = {}
    old_to_new: Dict[str, str] = {}
    for rec in records:
        old_name = rec.get("old_name")
        canonical = rec.get("canonical_heading")
        new_name = rec.get("new_name_guess")
        if isinstance(old_name, str) and old_name.strip():
            n_old = normalize_key(old_name)
            if isinstance(canonical, str) and canonical.strip() and n_old not in old_to_canonical:
                old_to_canonical[n_old] = canonical
            if isinstance(new_name, str) and new_name.strip() and n_old not in old_to_new:
                old_to_new[n_old] = new_name
        if isinstance(new_name, str) and new_name.strip() and isinstance(canonical, str) and canonical.strip():
            n_new = normalize_key(new_name)
            if n_new not in new_to_canonical:
                new_to_canonical[n_new] = canonical
    return old_to_canonical, new_to_canonical, old_to_new


def build_alias_reverse_maps(aliases: dict) -> Tuple[Dict[str, str], Dict[str, str]]:
    entry_aliases = aliases.get("entryAliases", {}) if isinstance(aliases, dict) else {}
    family_aliases = aliases.get("familyAliases", {}) if isinstance(aliases, dict) else {}

    alias_to_entry: Dict[str, str] = {}
    if isinstance(entry_aliases, dict):
        for canonical, alias_list in entry_aliases.items():
            if not isinstance(canonical, str):
                continue
            alias_to_entry[normalize_key(canonical)] = canonical
            if isinstance(alias_list, list):
                for alias in alias_list:
                    if isinstance(alias, str):
                        alias_to_entry[normalize_key(alias)] = canonical

    family_to_canonical: Dict[str, str] = {}
    if isinstance(family_aliases, dict):
        for canonical_family, alias_list in family_aliases.items():
            if not isinstance(canonical_family, str):
                continue
            family_to_canonical[normalize_key(canonical_family)] = normalize_key(canonical_family)
            if isinstance(alias_list, list):
                for alias in alias_list:
                    if isinstance(alias, str):
                        family_to_canonical[normalize_key(alias)] = normalize_key(canonical_family)

    for k, v in GENERIC_FAMILY_MAP.items():
        family_to_canonical[normalize_key(k)] = normalize_key(v)

    return alias_to_entry, family_to_canonical


def suggest_with_family_pair(old_key: str, family_map: Dict[str, str]) -> Optional[str]:
    norm = normalize_key(old_key)
    tokens = norm.split()
    if len(tokens) < 2:
        return None

    # Keep "... MEJI" form when second token is MEJI.
    if len(tokens) == 2 and tokens[1] == "MEJI":
        base = family_map.get(tokens[0], tokens[0])
        return f"{base} MEJI"

    first = family_map.get(tokens[0])
    second = family_map.get(tokens[1])
    if first and second:
        return f"{first} {second}"
    return None


def generate_reports_and_map() -> None:
    old_data = load_json(OLD_PATH)
    v2_data = load_json(V2_PATH)
    eq_data = load_json(EQUIV_PATH)
    aliases_data = load_json(ALIASES_PATH)

    old_odu = old_data.get("odu", {}) if isinstance(old_data, dict) else {}
    v2_odu = v2_data.get("odu", {}) if isinstance(v2_data, dict) else {}
    if not isinstance(old_odu, dict) or not isinstance(v2_odu, dict):
        raise RuntimeError("Invalid corpus schema for old/v2 datasets.")

    v2_lookup, _ = build_v2_lookup(v2_odu)
    old_to_canonical, new_to_canonical, old_to_new = build_equivalence_maps(
        eq_data.get("records", []) if isinstance(eq_data, dict) else []
    )
    alias_to_entry, family_map = build_alias_reverse_maps(aliases_data)
    legacy_aliases = parse_legacy_aliases()

    missing_keys: List[str] = []
    for old_key in old_odu.keys():
        if not isinstance(old_key, str):
            continue
        if normalize_key(old_key) not in v2_lookup:
            missing_keys.append(old_key)
    missing_keys.sort()

    rows = []
    compat_map: Dict[str, str] = {}

    for old_key in missing_keys:
        n_old = normalize_key(old_key)
        suggestions: List[Suggestion] = []

        def try_add(method: str, candidate_name: str, confidence: str) -> None:
            if not candidate_name:
                return
            resolved, all_resolved = pick_unique_resolved(candidate_name, v2_lookup)
            if resolved:
                suggestions.append(
                    Suggestion(
                        method=method,
                        candidate_name=candidate_name,
                        resolved_key=resolved,
                        confidence=confidence,
                    )
                )
            elif all_resolved:
                suggestions.append(
                    Suggestion(
                        method=f"{method}_ambiguous",
                        candidate_name=candidate_name,
                        resolved_key="|".join(sorted(all_resolved)),
                        confidence="LOW",
                    )
                )

        # 1) Exact equivalence from "new name" => canonical heading.
        canonical_from_new = new_to_canonical.get(n_old)
        if canonical_from_new:
            try_add("equivalence_new", canonical_from_new, "HIGH")

        # 2) Exact equivalence from "old name" => canonical heading.
        canonical_from_old = old_to_canonical.get(n_old)
        if canonical_from_old:
            try_add("equivalence_old", canonical_from_old, "HIGH")
            old_to_new_name = old_to_new.get(n_old)
            if old_to_new_name:
                try_add("equivalence_old_newname", old_to_new_name, "MED")

        # 3) Entry alias map.
        canonical_from_alias = alias_to_entry.get(n_old)
        if canonical_from_alias:
            try_add("entry_alias", canonical_from_alias, "HIGH")

        # 4) Legacy hardcoded alias map from repository.
        legacy_target = legacy_aliases.get(n_old)
        if legacy_target:
            try_add("legacy_alias", legacy_target, "MED")

        # 5) Family pair normalization heuristic.
        family_candidate = suggest_with_family_pair(old_key, family_map)
        if family_candidate:
            try_add("family_pair", family_candidate, "MED")

        # 6) Explicit Baba Ejiogbe family fallback.
        if n_old in {"BABA OGBE", "BABA EJIOGBE", "OGBE MEJI", "EJI OGBE"}:
            try_add("baba_ejiogbe", "EJIOGBE", "HIGH")

        unique_targets = sorted({s.resolved_key for s in suggestions if "|" not in s.resolved_key})

        status = "NO_MATCH"
        chosen: Suggestion | None = None
        notes = ""

        if unique_targets:
            if len(unique_targets) == 1:
                # Prefer highest-confidence method.
                ranked = sorted(
                    [s for s in suggestions if s.resolved_key == unique_targets[0]],
                    key=lambda s: (0 if s.confidence == "HIGH" else 1, s.method),
                )
                chosen = ranked[0]
                status = "SAFE_MATCH" if chosen.confidence == "HIGH" else "NEEDS_REVIEW"
                notes = (
                    "single_resolved_target"
                    if status == "SAFE_MATCH"
                    else "single_target_but_medium_confidence"
                )
            else:
                status = "NEEDS_REVIEW"
                notes = f"multiple_targets:{'|'.join(unique_targets)}"
        elif suggestions:
            status = "NEEDS_REVIEW"
            notes = "ambiguous_or_unresolved_candidates"

        suggested_key = chosen.resolved_key if chosen else ""
        method = chosen.method if chosen else ""
        confidence = chosen.confidence if chosen else ""
        candidate_name = chosen.candidate_name if chosen else ""

        if status == "SAFE_MATCH" and suggested_key:
            compat_map[old_key] = suggested_key

        rows.append(
            {
                "old_key": old_key,
                "status": status,
                "suggested_key": suggested_key,
                "method": method,
                "confidence": confidence,
                "candidate_name": candidate_name,
                "notes": notes,
                "all_unique_targets": "|".join(unique_targets),
            }
        )

    rows.sort(key=lambda r: (r["status"], r["old_key"]))

    safe_count = sum(1 for r in rows if r["status"] == "SAFE_MATCH")
    review_count = sum(1 for r in rows if r["status"] == "NEEDS_REVIEW")
    no_match_count = sum(1 for r in rows if r["status"] == "NO_MATCH")

    # Write compatibility map (safe-only).
    with OUT_MAP_PATH.open("w", encoding="utf-8") as f:
        json.dump(dict(sorted(compat_map.items())), f, ensure_ascii=False, indent=2)
        f.write("\n")

    # CSV report.
    with OUT_CSV_PATH.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "old_key",
                "status",
                "suggested_key",
                "method",
                "confidence",
                "candidate_name",
                "all_unique_targets",
                "notes",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)

    safe_rows = [r for r in rows if r["status"] == "SAFE_MATCH"]
    review_rows = [r for r in rows if r["status"] == "NEEDS_REVIEW"]
    no_rows = [r for r in rows if r["status"] == "NO_MATCH"]

    md_lines = [
        "# Odù v2 Compatibility Missing-Key Report",
        "",
        f"- Source old corpus: `{OLD_PATH.relative_to(ROOT)}`",
        f"- Source v2 corpus: `{V2_PATH.relative_to(ROOT)}`",
        f"- Generated compat map: `{OUT_MAP_PATH.relative_to(ROOT)}`",
        "",
        "## Summary",
        f"- Total old keys missing in v2: **{len(rows)}**",
        f"- SAFE_MATCH: **{safe_count}**",
        f"- NEEDS_REVIEW: **{review_count}**",
        f"- NO_MATCH: **{no_match_count}**",
        "",
        "## SAFE_MATCH (top 80)",
    ]
    for row in safe_rows[:80]:
        md_lines.append(
            f"- `{row['old_key']}` -> `{row['suggested_key']}` ({row['method']})"
        )

    md_lines.extend(["", "## NEEDS_REVIEW (top 120)"])
    for row in review_rows[:120]:
        extra = row["all_unique_targets"] or row["notes"]
        md_lines.append(
            f"- `{row['old_key']}` -> `{row['suggested_key'] or 'N/A'}` ({row['method'] or 'N/A'}) | {extra}"
        )

    md_lines.extend(["", "## NO_MATCH (top 120)"])
    for row in no_rows[:120]:
        md_lines.append(f"- `{row['old_key']}`")

    OUT_MD_PATH.write_text("\n".join(md_lines) + "\n", encoding="utf-8")

    print("[compat] missing_old_keys=", len(rows))
    print("[compat] safe_matches=", safe_count)
    print("[compat] needs_review=", review_count)
    print("[compat] no_match=", no_match_count)
    print("[compat] map_written=", OUT_MAP_PATH)
    print("[compat] csv_written=", OUT_CSV_PATH)
    print("[compat] md_written=", OUT_MD_PATH)


if __name__ == "__main__":
    generate_reports_and_map()
