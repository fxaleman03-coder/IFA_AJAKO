#!/usr/bin/env python3
import argparse
import json
import re
import unicodedata
from pathlib import Path
from typing import Dict, List, Tuple

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = ROOT / "assets/odu_content_patched.json"
DEFAULT_KEY = "OGBE YEKU"

SECTIONS = [
    "descripcion",
    "predicciones",
    "prohibiciones",
    "recomendaciones",
    "nace",
    "obras",
    "diceIfa",
    "ewes",
    "refranes",
    "eshu",
    "historiasYPatakies",
    "rezoYoruba",
    "suyereYoruba",
]

SECTION_HEADINGS = {
    "descripcion": [r"^DESCRIPCION(\s+DEL\s+ODU)?\b"],
    "predicciones": [r"^PREDICCIONES(\s+DEL\s+ODU)?\b", r"^ADVERTENCIAS\b"],
    "prohibiciones": [r"^PROHIBICIONES(\s+DEL\s+ODU)?\b", r"^ESTE ODU PROHIBE\b"],
    "recomendaciones": [r"^RECOMENDACIONES\b", r"^ESTE ODU RECOMIENDA\b"],
    "nace": [r"^EN ESTE ODU NACE\b"],
    "obras": [r"^OBRAS(\s+DEL\s+ODU)?\b", r"^RELACION DE OBRAS\b", r"^RELACION DEL OBRAS\b"],
    "diceIfa": [r"^DICE IFA\b"],
    "ewes": [r"^EWES(\s+DEL\s+ODU)?\b", r"^HIERBA(S)? DEL ODU\b"],
    "refranes": [r"^REFRAN(ES)?(\s+DEL\s+ODU)?\b"],
    "eshu": [r"^ESHU\b", r"^ESHU[\s\-]*ELEGBA\b"],
    "historiasYPatakies": [r"^HISTORIA(S)?\b", r"^RELACION DE ESES\b", r"^\d+\s*[-–]"],
    "rezoYoruba": [r"^REZO\b"],
    "suyereYoruba": [r"^SUYERE\b"],
}

SECTION_CUES = {
    "descripcion": [
        "ESTE ES EL ODU",
        "ORDEN SENORIAL",
        "SIGNIFICA",
        "REPRESENTA",
        "CARACTER",
        "TENDENCIAS",
        "GENERAL",
        "EXPLICA",
    ],
    "predicciones": [
        "CUIDADO CON",
        "PUEDE",
        "MARCA",
        "HABLA DE",
        "SE LE ACONSEJA",
        "PUEDE HABER",
        "ADVERTENCIA",
    ],
    "prohibiciones": [
        "NO SE PUEDE",
        "NO DEBE",
        "PROHIBE",
        "NO ",
    ],
    "recomendaciones": [
        "DEBE",
        "SE RECOMIENDA",
        "ATIENDA",
        "TENGA",
        "HAGA",
        "SE DEBE",
    ],
    "nace": [
        "EN ESTE ODU NACE",
        "NACE",
        "NACIO",
    ],
    "obras": [
        "EBO",
        "OBRA",
        "PROCEDIMIENTO",
        "PARALDO",
        "INGREDIENT",
        "SE HACE",
        "SE LE DA",
        "JUTIA",
        "PESCADO AHUMADO",
    ],
    "diceIfa": [
        "DICE IFA",
    ],
    "ewes": [
        "EWES",
        "HIERBA",
        "HOJAS",
        "RAIZ",
        "PLANTA",
        "ARBOL",
        "ZAPOTE",
        "SAUCO",
        "BEJUCO",
    ],
    "refranes": [
        "REFRAN",
    ],
    "eshu": [
        "ESHU",
        "ELEGBA",
        "CARGA",
        "INSHE",
        "CAMINO",
    ],
    "historiasYPatakies": [
        "HISTORIA",
        "ADIVINO PARA",
        "CANTO",
        "ERA UNA VEZ",
        "CUANDO",
    ],
    "rezoYoruba": [
        "ADIFAFUN",
        "ORUNMILA",
        "BABA",
        "OGBE",
        "EBO",
    ],
    "suyereYoruba": [
        "SUYERE",
        "CANTO",
    ],
}

# Tokens that strongly indicate wrong placement and likely destination.
HARD_TOKENS = {
    "prohibiciones": ["PROHIBICIONES", "ESTE ODU PROHIBE", "NO SE PUEDE", "NO DEBE"],
    "recomendaciones": ["RECOMENDACIONES", "ESTE ODU RECOMIENDA"],
    "obras": ["OBRAS DEL ODU", "RELACION DE OBRAS", "EBO:", "PARALDO", "PROCEDIMIENTO"],
    "ewes": ["HIERBA DEL ODU", "HIERBAS DEL ODU", "EWES DEL ODU"],
    "eshu": ["ESHU DEL ODU", "ESHU-ELEGBA", "ESHU EMERE", "CARGA PARA ESTE ESHU"],
    "historiasYPatakies": ["HISTORIA", "RELACION DE ESES"],
    "nace": ["EN ESTE ODU NACE"],
    "diceIfa": ["DICE IFA"],
    "rezoYoruba": ["REZO:"],
    "suyereYoruba": ["SUYERE:"],
    "refranes": ["REFRANES"],
}


def fold(text: str) -> str:
    text = text or ""
    text = "".join(
        c for c in unicodedata.normalize("NFD", text) if unicodedata.category(c) != "Mn"
    )
    text = text.upper().strip()
    text = re.sub(r"\s+", " ", text)
    return text


def split_blocks(text: str) -> List[str]:
    if not text or not text.strip():
        return []
    normalized = text.replace("\r\n", "\n")
    parts = [p.strip() for p in re.split(r"\n\s*\n+", normalized) if p.strip()]
    blocks: List[str] = []
    for part in parts:
        lines = part.splitlines()
        cur: List[str] = []
        for line in lines:
            if is_heading_line(line) and cur:
                blocks.append("\n".join(cur).strip())
                cur = [line.rstrip()]
            else:
                cur.append(line.rstrip())
        if cur:
            blocks.append("\n".join(cur).strip())
    return [b for b in blocks if b]


def is_heading_line(line: str) -> bool:
    fline = fold(line)
    if not fline:
        return False
    for patterns in SECTION_HEADINGS.values():
        for p in patterns:
            if re.match(p, fline):
                return True
    return False


def heading_hits_by_section(block: str, source: str) -> Dict[str, int]:
    hits: Dict[str, int] = {}
    for line in block.splitlines():
        fline = fold(line.strip())
        if not fline:
            continue
        for sec, patterns in SECTION_HEADINGS.items():
            if sec == source:
                continue
            for p in patterns:
                if re.match(p, fline):
                    hits[sec] = hits.get(sec, 0) + 1
                    break
    return hits


def score_block_for_section(block: str, section: str) -> Tuple[int, List[str]]:
    fblock = fold(block)
    lines = [ln.strip() for ln in block.splitlines() if ln.strip()]
    score = 0
    reasons: List[str] = []

    # Lexical cues
    for cue in SECTION_CUES.get(section, []):
        if cue == "NO ":
            no_count = sum(1 for ln in lines if fold(ln).startswith("NO "))
            if no_count:
                score += min(4, no_count)
                reasons.append(f"{no_count} lines start with 'No ...'")
            continue
        if cue in fblock:
            score += 1
            reasons.append(f"contains cue '{cue.lower()}'")

    # Structural cues
    if section == "refranes":
        if len(lines) >= 3:
            avg_len = sum(len(ln) for ln in lines) / max(1, len(lines))
            if avg_len <= 120:
                score += 2
                reasons.append("short, line-oriented statements")
    if section == "descripcion":
        if len(block) >= 500:
            score += 2
            reasons.append("long explanatory prose length")
    if section == "ewes":
        if len(lines) <= 15 and all(len(ln) <= 120 for ln in lines):
            score += 1
            reasons.append("compact herb-like lines")
    if section == "historiasYPatakies":
        if re.search(r"(?m)^\s*\d+\s*[-–]", block):
            score += 3
            reasons.append("numbered story marker pattern")
    if section == "rezoYoruba":
        uppercase_ratio = sum(1 for c in block if c.isupper()) / max(1, sum(1 for c in block if c.isalpha()))
        if uppercase_ratio > 0.45:
            score += 1
            reasons.append("high uppercase ratio, chant-like style")
    if section == "suyereYoruba":
        repeated = re.search(r"\b([A-ZÁÉÍÓÚÑ]{3,})\b.*\b\1\b", block, re.IGNORECASE | re.DOTALL)
        if repeated:
            score += 1
            reasons.append("repetition pattern, chant-like line")

    return score, reasons


def suggest_destination(source: str, block: str) -> Tuple[str, str, str]:
    # 1) Strong heading contamination
    hits = heading_hits_by_section(block, source)
    if hits:
        target = max(hits, key=hits.get)
        reason = f"contains explicit heading markers for '{target}'"
        return target, reason, "HIGH"

    # Keep story section conservative: avoid noisy lexical migrations unless
    # there is a clear top marker in the block.
    if source == "historiasYPatakies":
        first_line = ""
        for ln in block.splitlines():
            if ln.strip():
                first_line = fold(ln.strip())
                break
        if first_line.startswith("REZO"):
            return "rezoYoruba", "story block starts with 'REZO:' marker", "HIGH"
        if first_line.startswith("SUYERE"):
            return "suyereYoruba", "story block starts with 'SUYERE:' marker", "HIGH"
        if first_line.startswith("DICE IFA"):
            return "diceIfa", "story block starts with 'DICE IFA' marker", "MEDIUM"
        if first_line.startswith("EBO"):
            return "obras", "story block starts with 'EBO:' procedural marker", "MEDIUM"
        return "", "", ""

    # 2) Strong hard-token contamination
    fblock = fold(block)
    flines = [fold(ln) for ln in block.splitlines() if ln.strip()]
    hard_scores: Dict[str, int] = {}
    for sec, toks in HARD_TOKENS.items():
        if sec == source:
            continue
        count = 0
        for tok in toks:
            tokf = fold(tok)
            line_hit = any(ln.startswith(tokf) for ln in flines)
            text_hit = tokf in fblock and (tokf.endswith(":") or " DEL ODU" in tokf or "RELACION" in tokf)
            if line_hit or text_hit:
                count += 1
        if count:
            hard_scores[sec] = count
    if hard_scores:
        target = max(hard_scores, key=hard_scores.get)
        # avoid auto-high when only generic words appear
        conf = "HIGH" if hard_scores[target] >= 2 else "MEDIUM"
        reason = f"contains hard contamination tokens for '{target}'"
        return target, reason, conf

    # 3) Heuristic scoring across sections
    scores: Dict[str, int] = {}
    reasons: Dict[str, List[str]] = {}
    for sec in SECTIONS:
        sc, rs = score_block_for_section(block, sec)
        scores[sec] = sc
        reasons[sec] = rs

    source_score = scores.get(source, 0)
    best_section = max(scores, key=scores.get)
    best_score = scores[best_section]
    if best_section == source:
        return "", "", ""
    if best_score < 2:
        return "", "", ""

    diff = best_score - source_score
    if diff >= 3 or best_score >= 5:
        conf = "HIGH"
    elif diff >= 2:
        conf = "MEDIUM"
    elif diff >= 1:
        conf = "LOW"
    else:
        return "", "", ""
    # Reduce false positives for inherently mixed ritual text.
    if source == "obras" and best_section in {"ewes", "predicciones", "descripcion", "refranes"} and diff < 3:
        return "", "", ""
    if source == "ewes" and best_section in {"descripcion", "predicciones"} and diff < 3:
        return "", "", ""
    reason = "; ".join(reasons[best_section][:3]) if reasons[best_section] else "heuristic fit to destination section"
    return best_section, reason, conf


def preview(text: str, limit: int = 300) -> str:
    text = text.strip().replace("\n", " ")
    text = re.sub(r"\s+", " ", text)
    return text[:limit]


def validate_entry(content: Dict[str, str]) -> List[Dict]:
    findings: List[Dict] = []
    for source in SECTIONS:
        raw = content.get(source, "")
        if not isinstance(raw, str) or not raw.strip():
            continue
        for block in split_blocks(raw):
            target, why, conf = suggest_destination(source, block)
            if not target:
                continue
            findings.append(
                {
                    "source_section": source,
                    "suspicious_text_preview": preview(block, 300),
                    "why_looks_misplaced": why,
                    "suggested_target_section": target,
                    "confidence": conf,
                }
            )

    # dedupe close duplicates
    seen = set()
    dedup: List[Dict] = []
    for f in findings:
        key = (
            f["source_section"],
            f["suggested_target_section"],
            f["suspicious_text_preview"][:120],
        )
        if key in seen:
            continue
        seen.add(key)
        dedup.append(f)
    return dedup


def output_paths_for_key(key: str) -> Tuple[Path, Path]:
    slug = fold(key).lower().replace(" ", "_")
    return (
        ROOT / f"build/{slug}_section_validation.md",
        ROOT / f"build/{slug}_section_validation.json",
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate section placement for one Odù entry.")
    parser.add_argument("--input", default=str(DEFAULT_INPUT))
    parser.add_argument("--odu-key", default=DEFAULT_KEY)
    args = parser.parse_args()

    input_path = Path(args.input)
    data = json.loads(input_path.read_text(encoding="utf-8"))
    odu_map = data.get("odu", {})
    if not isinstance(odu_map, dict) or args.odu_key not in odu_map:
        raise SystemExit(f"Odù key not found: {args.odu_key}")
    entry = odu_map[args.odu_key]
    content = entry.get("content", {}) if isinstance(entry, dict) else {}
    if not isinstance(content, dict):
        raise SystemExit(f"Invalid content for key: {args.odu_key}")

    md_path, json_path = output_paths_for_key(args.odu_key)
    findings = validate_entry(content)

    high = sum(1 for f in findings if f["confidence"] == "HIGH")
    med = sum(1 for f in findings if f["confidence"] == "MEDIUM")
    low = sum(1 for f in findings if f["confidence"] == "LOW")

    payload = {
        "target_odu_key": args.odu_key,
        "source_file": str(input_path),
        "sections_validated": SECTIONS,
        "suspicious_placements_found": len(findings),
        "high_confidence_moves": high,
        "medium_confidence_moves": med,
        "low_confidence_moves": low,
        "findings": findings,
    }
    json_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# Odù Section Placement Validation",
        "",
        f"- Target odù key: `{args.odu_key}`",
        f"- Source file: `{input_path}`",
        f"- Suspicious placements found: **{len(findings)}**",
        f"- High confidence moves: **{high}**",
        f"- Medium confidence moves: **{med}**",
        f"- Low confidence moves: **{low}**",
        "",
        "## Findings",
    ]
    if not findings:
        lines.append("- No suspicious section placements detected.")
    else:
        for i, f in enumerate(findings, start=1):
            lines.append(f"{i}. source section: `{f['source_section']}`")
            lines.append(f"   suspicious text preview: `{f['suspicious_text_preview']}`")
            lines.append(f"   why: `{f['why_looks_misplaced']}`")
            lines.append(f"   suggested target section: `{f['suggested_target_section']}`")
            lines.append(f"   confidence: `{f['confidence']}`")
    lines.append("")
    md_path.write_text("\n".join(lines), encoding="utf-8")

    print("target odu key =", args.odu_key)
    print("number of suspicious placements found =", len(findings))
    print("high confidence moves =", high)
    print("medium confidence moves =", med)
    print("low confidence moves =", low)


if __name__ == "__main__":
    main()
