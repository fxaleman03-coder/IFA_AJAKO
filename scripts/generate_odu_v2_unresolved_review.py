#!/usr/bin/env python3
import csv
import difflib
import json
import re
import unicodedata
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple

ROOT = Path(__file__).resolve().parents[1]
REPORT_CSV = ROOT / "build/odu_v2_missing_compat_report.csv"
COMPAT_MAP = ROOT / "assets/odu_key_compat_map.json"
V2_PATH = ROOT / "assets/odu_content_v2_ready.json"
ACTIVE_CORPUS_PATH = ROOT / "assets/odu_content_patched.json"
EQUIV_PATH = ROOT / "build/odu_name_equivalences.json"

OUT_MD = ROOT / "build/odu_v2_unresolved_review.md"
OUT_JSON = ROOT / "build/odu_v2_unresolved_review.json"

FAMILY_CANON = {
    "OGBE": "OGBE",
    "EJIOGBE": "EJIOGBE",
    "OYEKUN": "OYEKU",
    "OYEKU": "OYEKU",
    "OYECUN": "OYEKU",
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
    "OTURUPON": "OTURUPON",
    "OTRUPON": "OTURUPON",
    "OTURA": "OTURA",
    "IRETE": "IRETE",
    "OSHE": "OSE",
    "OSE": "OSE",
    "OFUN": "OFUN",
}

BIDIR_TOKEN_VARIANTS = {
    "OYEKUN": ["OYEKU"],
    "OYEKU": ["OYEKUN"],
    "OTRUPON": ["OTURUPON"],
    "OTURUPON": ["OTRUPON"],
    "OKANA": ["OKANRAN"],
    "OKANRAN": ["OKANA"],
    "OSHE": ["OSE"],
    "OSE": ["OSHE"],
    "OJUANI": ["OWONRIN"],
    "OWONRIN": ["OJUANI"],
}


def normalize_key(text: str) -> str:
    text = (text or "").upper().strip()
    text = "".join(
        c for c in unicodedata.normalize("NFD", text) if unicodedata.category(c) != "Mn"
    )
    text = text.replace("_", " ").replace("-", " ")
    text = re.sub(r"[^A-Z0-9 ]+", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def canon_token(token: str) -> str:
    t = normalize_key(token)
    return FAMILY_CANON.get(t, t)


@dataclass
class Candidate:
    key: str
    method: str
    score: int



def load_json(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def load_report_rows() -> Dict[str, dict]:
    if not REPORT_CSV.exists():
        return {}
    with REPORT_CSV.open("r", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    return {row.get("old_key", ""): row for row in rows if row.get("old_key")}


def build_v2_lookup(v2_odu: dict) -> Tuple[Dict[str, str], Dict[str, List[str]]]:
    norm_to_key = {}
    by_family = {}
    for key in sorted(v2_odu.keys()):
        nk = normalize_key(key)
        norm_to_key[nk] = key
        first = nk.split()[0] if nk else ""
        by_family.setdefault(first, []).append(key)
    return norm_to_key, by_family


def build_equiv_new_to_canon() -> Dict[str, str]:
    if not EQUIV_PATH.exists():
        return {}
    data = load_json(EQUIV_PATH)
    records = data.get("records", []) if isinstance(data, dict) else []
    out = {}
    for rec in records:
        if not isinstance(rec, dict):
            continue
        new = rec.get("new_name_guess")
        canon = rec.get("canonical_heading")
        if isinstance(new, str) and isinstance(canon, str) and new.strip() and canon.strip():
            out[normalize_key(new)] = canon
    return out


def candidate_from_tokens(old_norm: str, norm_to_v2: Dict[str, str]) -> List[Candidate]:
    tokens = old_norm.split()
    out: List[Candidate] = []

    def add_if_exists(candidate_norm: str, method: str, score: int):
        key = norm_to_v2.get(normalize_key(candidate_norm))
        if key:
            out.append(Candidate(key=key, method=method, score=score))

    if len(tokens) == 2:
        first = canon_token(tokens[0])
        second = canon_token(tokens[1])

        if tokens[1] == "MEJI":
            add_if_exists(f"{first} MEJI", "meji_direct", 96)
            add_if_exists(f"BABA {first} MEJI", "meji_baba_variant", 95)
        else:
            add_if_exists(f"{first} {second}", "canonical_pair_direct", 98)

        # variant substitutions on second token.
        for alt in BIDIR_TOKEN_VARIANTS.get(tokens[1], []):
            add_if_exists(f"{first} {canon_token(alt)}", "canonical_pair_token_variant", 92)

        # variant substitutions on first token.
        for altf in BIDIR_TOKEN_VARIANTS.get(tokens[0], []):
            add_if_exists(f"{canon_token(altf)} {second}", "canonical_pair_family_variant", 90)

    return out


def nearest_candidates(
    old_norm: str,
    family_guess: str,
    norm_to_v2: Dict[str, str],
    by_family: Dict[str, List[str]],
    max_items: int = 3,
) -> List[Candidate]:
    out: List[Candidate] = []

    # Family-scoped nearest first.
    family_keys = by_family.get(family_guess, [])
    scored = []
    for key in family_keys:
        nkey = normalize_key(key)
        ratio = difflib.SequenceMatcher(None, old_norm, nkey).ratio()
        scored.append((ratio, key))
    scored.sort(reverse=True)
    for ratio, key in scored[:max_items]:
        if ratio >= 0.55:
            out.append(Candidate(key=key, method="nearest_family_similarity", score=int(ratio * 100)))

    # Global fallback if still no suggestions.
    if not out:
        all_scored = []
        for nkey, key in norm_to_v2.items():
            ratio = difflib.SequenceMatcher(None, old_norm, nkey).ratio()
            all_scored.append((ratio, key))
        all_scored.sort(reverse=True)
        for ratio, key in all_scored[:max_items]:
            if ratio >= 0.62:
                out.append(Candidate(key=key, method="nearest_global_similarity", score=int(ratio * 100)))

    return out[:max_items]


def dedupe_candidates(cands: List[Candidate]) -> List[Candidate]:
    best: Dict[str, Candidate] = {}
    for c in cands:
        prev = best.get(c.key)
        if prev is None or c.score > prev.score:
            best[c.key] = c
    return sorted(best.values(), key=lambda c: (-c.score, c.key))


def classify(cands: List[Candidate]) -> Tuple[str, str]:
    if not cands:
        return "NO_MATCH", "LEAVE_UNMAPPED"

    if cands[0].score < 70:
        return "NO_MATCH", "LEAVE_UNMAPPED"

    safe_methods = (
        "canonical_pair_direct",
        "canonical_pair_token_variant",
        "canonical_pair_family_variant",
        "meji_direct",
        "meji_baba_variant",
        "equivalence_canonical:",
    )
    strong = [
        c
        for c in cands
        if c.score >= 95 and any(c.method.startswith(m) for m in safe_methods)
    ]
    if len(strong) == 1:
        return "SAFE_MATCH", "ADD_TO_COMPAT_MAP"

    return "NEEDS_REVIEW", "MANUAL_CONTENT_IMPORT_NEEDED"


def main() -> None:
    report_rows = load_report_rows()
    compat_map = load_json(COMPAT_MAP)
    v2_data = load_json(V2_PATH)
    active_data = load_json(ACTIVE_CORPUS_PATH)
    equiv_new_to_canon = build_equiv_new_to_canon()

    v2_odu = v2_data.get("odu", {}) if isinstance(v2_data, dict) else {}
    active_odu = active_data.get("odu", {}) if isinstance(active_data, dict) else {}

    if not isinstance(v2_odu, dict) or not isinstance(active_odu, dict) or not isinstance(compat_map, dict):
        raise RuntimeError("Invalid schema in inputs.")

    norm_to_v2, by_family = build_v2_lookup(v2_odu)
    resolved_direct = set(norm_to_v2.keys())

    unresolved_keys = []
    for old_key in sorted(k for k in active_odu.keys() if isinstance(k, str)):
        n_old = normalize_key(old_key)
        if n_old in resolved_direct:
            continue
        if old_key in compat_map:
            continue
        unresolved_keys.append(old_key)

    review_entries = []
    family_counter = Counter()

    for old_key in unresolved_keys:
        n_old = normalize_key(old_key)
        tokens = n_old.split()
        family_guess = canon_token(tokens[0]) if tokens else "UNKNOWN"
        family_counter[family_guess] += 1

        candidates: List[Candidate] = []

        # 1) Existing report suggestion (if unresolved row had one).
        row = report_rows.get(old_key)
        if row and row.get("suggested_key"):
            suggested = row["suggested_key"].strip()
            if suggested in v2_odu:
                # Keep report method confidence as medium by default.
                score = 93 if row.get("status") == "NEEDS_REVIEW" else 95
                candidates.append(
                    Candidate(
                        key=suggested,
                        method=f"report_csv:{row.get('method') or 'suggested'}",
                        score=score,
                    )
                )

        # 2) Direct token-canonical rules.
        candidates.extend(candidate_from_tokens(n_old, norm_to_v2))

        # 3) Equivalence new-name to canonical heading, then normalize to existing v2 key.
        eq_canon = equiv_new_to_canon.get(n_old)
        if eq_canon:
            eq_candidates = candidate_from_tokens(normalize_key(eq_canon), norm_to_v2)
            for c in eq_candidates:
                candidates.append(
                    Candidate(
                        key=c.key,
                        method=f"equivalence_canonical:{c.method}",
                        score=max(c.score, 94),
                    )
                )

        # 4) Similarity nearest neighbors.
        candidates.extend(nearest_candidates(n_old, family_guess, norm_to_v2, by_family, max_items=3))

        candidates = dedupe_candidates(candidates)[:3]
        confidence, action = classify(candidates)

        primary_method = candidates[0].method if candidates else "none"
        primary_score = candidates[0].score if candidates else 0

        review_entries.append(
            {
                "old_key": old_key,
                "normalized": n_old,
                "family_guess": family_guess,
                "suggested_nearest_v2_candidates": [
                    {"key": c.key, "method": c.method, "score": c.score} for c in candidates
                ],
                "match_method_used": primary_method,
                "confidence": confidence,
                "recommended_action": action,
                "primary_score": primary_score,
            }
        )

    # Keep most actionable first.
    order = {"SAFE_MATCH": 0, "NEEDS_REVIEW": 1, "NO_MATCH": 2}
    review_entries.sort(key=lambda e: (order[e["confidence"]], -e["primary_score"], e["old_key"]))

    safe_count = sum(1 for e in review_entries if e["confidence"] == "SAFE_MATCH")
    review_count = sum(1 for e in review_entries if e["confidence"] == "NEEDS_REVIEW")
    no_match_count = sum(1 for e in review_entries if e["confidence"] == "NO_MATCH")

    payload = {
        "generated_from": {
            "report_csv": str(REPORT_CSV.relative_to(ROOT)),
            "compat_map": str(COMPAT_MAP.relative_to(ROOT)),
            "v2_corpus": str(V2_PATH.relative_to(ROOT)),
            "active_corpus": str(ACTIVE_CORPUS_PATH.relative_to(ROOT)),
        },
        "summary": {
            "unresolved_total": len(review_entries),
            "safe_additional_matches": safe_count,
            "needs_review_count": review_count,
            "no_match_count": no_match_count,
            "top_families_unresolved": family_counter.most_common(10),
        },
        "entries": review_entries,
    }

    OUT_JSON.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    md_lines = [
        "# Odù v2 Unresolved Compatibility Review",
        "",
        "## Summary",
        f"- unresolved total: **{len(review_entries)}**",
        f"- safe additional matches: **{safe_count}**",
        f"- needs review count: **{review_count}**",
        f"- no match count: **{no_match_count}**",
        "",
        "## Top Families With Unresolved Keys",
    ]
    for fam, cnt in family_counter.most_common(12):
        md_lines.append(f"- `{fam}`: {cnt}")

    md_lines.append("")
    md_lines.append("## Unresolved Entries")

    for entry in review_entries:
        md_lines.extend(
            [
                f"### `{entry['old_key']}`",
                f"- normalized: `{entry['normalized']}`",
                f"- family_guess: `{entry['family_guess']}`",
                f"- confidence: `{entry['confidence']}`",
                f"- match method used: `{entry['match_method_used']}`",
                f"- recommended action: `{entry['recommended_action']}`",
                "- suggested nearest v2 candidates:",
            ]
        )
        if entry["suggested_nearest_v2_candidates"]:
            for cand in entry["suggested_nearest_v2_candidates"]:
                md_lines.append(
                    f"  - `{cand['key']}` ({cand['method']}, score={cand['score']})"
                )
        else:
            md_lines.append("  - (none)")
        md_lines.append("")

    OUT_MD.write_text("\n".join(md_lines), encoding="utf-8")

    print("[unresolved-review] unresolved_total=", len(review_entries))
    print("[unresolved-review] safe_additional_matches=", safe_count)
    print("[unresolved-review] needs_review_count=", review_count)
    print("[unresolved-review] no_match_count=", no_match_count)
    print("[unresolved-review] top_families=", family_counter.most_common(8))
    print("[unresolved-review] md=", OUT_MD)
    print("[unresolved-review] json=", OUT_JSON)


if __name__ == "__main__":
    main()
