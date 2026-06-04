#!/usr/bin/env python3
"""Build a self-contained interactive HTML deck from a small Org-mode source file.

This is intentionally not a full Org exporter. It supports the slide subset used by
``docs/g6r-interactive-presentation.org``:

- top-level ``*`` headings as slides
- a ``:PROPERTIES:`` drawer for slide metadata
- ``#+BEGIN_LEAD`` / ``#+END_LEAD`` for the lead paragraph
- semantic blocks such as ``METRIC_CARDS``, ``CARDS``, ``PIPELINE``,
  ``FLOW``, ``FORMULA``, ``PILLS`` and ``WIDGET``
- ``#+BEGIN_CONTENT`` / ``#+END_CONTENT`` for optional raw HTML escape hatches
- ``#+BEGIN_NOTES`` / ``#+END_NOTES`` for speaker notes
"""

from __future__ import annotations

import argparse
import html
import re
import shlex
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_TEMPLATE = PROJECT_ROOT / "templates" / "interactive_deck.html"


@dataclass(frozen=True)
class Slide:
    """One slide parsed from the Org source."""

    title: str
    nav_title: str
    eyebrow: str = ""
    lead: str = ""
    content_html: str = ""
    notes_html: str = ""


@dataclass(frozen=True)
class Deck:
    """Interactive deck metadata and slides."""

    title: str = "Interactive Deck"
    subtitle: str = "Interactive presentation"
    source_label: str = "Org source"
    slides: list[Slide] = field(default_factory=list)


_HEADING_RE = re.compile(r"^\*+\s+(.+?)\s*$")
_METADATA_RE = re.compile(r"^#\+([A-Z0-9_]+):\s*(.*)$", re.IGNORECASE)
_PROPERTY_RE = re.compile(r"^:([A-Z0-9_]+):\s*(.*)$", re.IGNORECASE)
_BEGIN_RE = re.compile(r"^#\+BEGIN_([A-Z0-9_]+)(?:\s+(.*))?$", re.IGNORECASE)
_END_RE = re.compile(r"^#\+END_([A-Z0-9_]+)\s*$", re.IGNORECASE)


def parse_org_deck(path: str | Path) -> Deck:
    """Parse the supported Org subset into a :class:`Deck`."""

    source_path = Path(path)
    lines = source_path.read_text().splitlines()

    metadata: dict[str, str] = {}
    slide_chunks: list[tuple[str, list[str]]] = []
    current_title: str | None = None
    current_lines: list[str] = []

    for line in lines:
        heading = _HEADING_RE.match(line)
        if heading:
            if current_title is not None:
                slide_chunks.append((current_title, current_lines))
            current_title = heading.group(1)
            current_lines = []
            continue

        if current_title is None:
            meta = _METADATA_RE.match(line)
            if meta:
                metadata[meta.group(1).upper()] = meta.group(2).strip()
            continue

        current_lines.append(line)

    if current_title is not None:
        slide_chunks.append((current_title, current_lines))

    slides = [_parse_slide(title, chunk) for title, chunk in slide_chunks]
    return Deck(
        title=metadata.get("TITLE", "Interactive Deck"),
        subtitle=metadata.get("SUBTITLE", "Interactive presentation"),
        source_label=metadata.get("SOURCE_LABEL", str(source_path)),
        slides=slides,
    )


def _parse_slide(title: str, lines: Iterable[str]) -> Slide:
    props: dict[str, str] = {}
    blocks: dict[str, list[str]] = {"LEAD": [], "CONTENT": [], "NOTES": []}
    mode: str | None = None
    mode_args = ""
    mode_lines: list[str] = []
    in_properties = False

    def flush_mode() -> None:
        nonlocal mode, mode_args, mode_lines
        if mode is None:
            return
        if mode in {"LEAD", "NOTES", "CONTENT"}:
            blocks[mode].extend(mode_lines)
        else:
            blocks["CONTENT"].append(_render_semantic_block(mode, mode_args, mode_lines))
        mode = None
        mode_args = ""
        mode_lines = []

    for line in lines:
        stripped = line.strip()
        upper = stripped.upper()

        if mode is not None:
            if _END_RE.match(stripped):
                flush_mode()
            else:
                mode_lines.append(line)
            continue

        if upper == ":PROPERTIES:":
            in_properties = True
            continue
        if in_properties:
            if upper == ":END:":
                in_properties = False
                continue
            prop = _PROPERTY_RE.match(stripped)
            if prop:
                props[prop.group(1).upper()] = prop.group(2).strip()
            continue

        begin = _BEGIN_RE.match(stripped)
        if begin:
            block_name = begin.group(1).upper()
            raw_args = (begin.group(2) or "").strip()
            if block_name == "EXPORT" and raw_args.lower() == "html":
                mode = "CONTENT"
                mode_args = ""
            else:
                mode = block_name
                mode_args = raw_args
            mode_lines = []
            continue

        directive = _METADATA_RE.match(stripped)
        if directive and _should_ignore_slide_directive(directive.group(1)):
            continue

        if stripped:
            blocks["CONTENT"].append(_render_org_lines([line]))

    flush_mode()

    return Slide(
        title=props.get("TITLE", title),
        nav_title=props.get("NAV_TITLE", title),
        eyebrow=props.get("EYEBROW", ""),
        lead=_join_block(blocks["LEAD"]),
        content_html=_join_block(blocks["CONTENT"]),
        notes_html=_join_block(blocks["NOTES"]),
    )


def _should_ignore_slide_directive(name: str) -> bool:
    upper = name.upper()
    return upper == "OPTIONS" or upper.startswith(("ATTR_", "REVEAL_"))


def _render_semantic_block(name: str, raw_args: str, lines: list[str]) -> str:
    args = _parse_block_args(raw_args)
    match name:
        case "METRIC_CARDS":
            return _render_metric_cards(lines, args)
        case "CARDS":
            return _render_cards(lines, args)
        case "PIPELINE":
            return _render_pipeline(lines)
        case "PILLS":
            return _render_pills(lines)
        case "FLOW":
            return _render_flow(lines)
        case "FORMULA":
            return _render_formula(lines)
        case "WIDGET":
            return _render_widget(args.get("type", ""))
        case "QUOTE":
            return f'<blockquote>{_render_org_lines(lines)}</blockquote>'
        case "SRC" | "SOURCE":
            return _render_formula(lines)
        case _:
            return _render_org_lines(lines)


def _parse_block_args(raw_args: str) -> dict[str, str]:
    tokens = shlex.split(raw_args)
    parsed: dict[str, str] = {}
    index = 0
    while index < len(tokens):
        token = tokens[index]
        if token.startswith(":"):
            key = token[1:].lower()
            if index + 1 < len(tokens) and not tokens[index + 1].startswith(":"):
                parsed[key] = tokens[index + 1]
                index += 2
            else:
                parsed[key] = "true"
                index += 1
        else:
            index += 1
    return parsed


def _parse_description_items(lines: list[str]) -> list[tuple[str, list[str]]]:
    items: list[tuple[str, list[str]]] = []
    current_title: str | None = None
    current_lines: list[str] = []

    for line in lines:
        match = re.match(r"^\s*[-+]\s+(.+?)\s+::\s*(.*)$", line)
        if match:
            if current_title is not None:
                items.append((current_title, current_lines))
            current_title = match.group(1).strip()
            first_line = match.group(2).strip()
            current_lines = [first_line] if first_line else []
            continue
        if current_title is not None:
            current_lines.append(line[2:] if line.startswith("  ") else line)

    if current_title is not None:
        items.append((current_title, current_lines))
    return items


def _grid_class(count: int) -> str:
    return f"grid-{2 if count == 2 else 3}"


def _render_metric_cards(lines: list[str], args: dict[str, str]) -> str:
    items = _parse_description_items(lines)
    columns = int(args.get("columns", min(max(len(items), 1), 3)))
    parts = [f'<div class="{_grid_class(columns)}">']
    for value, body_lines in items:
        parts.append('  <div class="card emphasis">')
        parts.append(f'    <span class="big-number">{_render_inline(value)}</span>')
        parts.append(f"    {_render_org_lines(body_lines)}")
        parts.append("  </div>")
    parts.append("</div>")
    return "\n".join(parts)


def _render_cards(lines: list[str], args: dict[str, str]) -> str:
    items = _parse_description_items(lines)
    columns = int(args.get("columns", min(max(len(items), 1), 3)))
    emphasis = _parse_index_set(args.get("emphasis", ""))
    parts = [f'<div class="{_grid_class(columns)}">']
    for index, (title, body_lines) in enumerate(items, start=1):
        card_class = "card emphasis" if index in emphasis else "card"
        parts.append(f'  <div class="{card_class}">')
        parts.append(f"    <h3>{_render_inline(title)}</h3>")
        parts.append(_indent(_render_org_lines(body_lines), "    "))
        parts.append("  </div>")
    parts.append("</div>")
    return "\n".join(parts)


def _parse_index_set(raw: str) -> set[int]:
    if raw.lower() == "all":
        return set(range(1, 100))
    return {int(part) for part in re.split(r"[, ]+", raw.strip()) if part.isdigit()}


def _render_pipeline(lines: list[str]) -> str:
    items = _parse_description_items(lines)
    nodes: list[str] = []
    for index, (title, body_lines) in enumerate(items):
        body = " ".join(line.strip() for line in body_lines if line.strip())
        subtitle, _, detail = body.partition("||")
        detail = detail.strip() or subtitle.strip()
        active = " active" if index == 0 else ""
        nodes.append(
            f'<button class="pipe-node{active}" data-detail="{html.escape(detail)}">'
            f"<strong>{_render_inline(title)}</strong><span>{_render_inline(subtitle.strip())}</span></button>"
        )
    rows = [nodes[index : index + 5] for index in range(0, len(nodes), 5)]
    parts = ['<div class="pipeline">']
    for row in rows:
        parts.append('  <div class="pipeline-row">')
        parts.extend(f"    {node}" for node in row)
        parts.append("  </div>")
    parts.append("</div>")
    if nodes:
        first_body = " ".join(line.strip() for line in items[0][1] if line.strip())
        _, _, first_detail = first_body.partition("||")
        detail_text = first_detail.strip() or first_body.strip()
        parts.append(f'<div id="pipelineDetail" class="detail-panel">{_render_inline(detail_text)}</div>')
    return "\n".join(parts)


def _render_pills(lines: list[str]) -> str:
    pills = [_strip_list_marker(line) for line in lines if _strip_list_marker(line)]
    parts = ['<div class="pill-row">']
    parts.extend(f'  <span class="pill">{_render_inline(pill)}</span>' for pill in pills)
    parts.append("</div>")
    return "\n".join(parts)


def _render_flow(lines: list[str]) -> str:
    labels = [_strip_list_marker(line) for line in lines if _strip_list_marker(line)]
    parts = ['<div class="mini-diagram">']
    for index, label in enumerate(labels):
        if index:
            parts.append('  <span class="arrow">→</span>')
        parts.append(f'  <span class="block">{_render_inline(label)}</span>')
    parts.append("</div>")
    return "\n".join(parts)


def _render_formula(lines: list[str]) -> str:
    return f'<div class="formula">{html.escape(_join_block(lines))}</div>'


def _render_widget(widget_type: str) -> str:
    match widget_type.lower():
        case "ordering":
            return """<div class="ordering-buttons" id="orderingButtons"></div>
<div class="grid-2">
  <div class="card emphasis">
    <h3 id="orderingTitle">Ordering 0</h3>
    <div class="mini-diagram">
      <span class="block variable" id="lhsBlock">LHS: 4,5,6</span>
      <span class="arrow">=</span>
      <span class="block variable" id="rhsBlock">RHS: 3,2</span>
      <span class="arrow">; removed</span>
      <span class="block constant" id="removedBlock">1</span>
    </div>
    <p class="muted">The labels θa, θb, θc, θd, θe are roles inside one ordering, not permanent physical joint names.</p>
  </div>
  <div class="card">
    <h3>Why remove a joint?</h3>
    <p>Directly solving six coupled trig unknowns is too hard. Removing one joint leaves five unknowns, then later elimination reduces it to three.</p>
    <p><strong>Key idea:</strong> choose vectors that are invariant to the removed joint’s angle.</p>
  </div>
</div>"""
        case "vandermonde":
            return """<div class="grid-2">
  <div class="demo-box">
    <h3>Toy coefficient recovery</h3>
    <p class="muted">The hidden curve is y = a·x² + b·x + c. Click sample sets and watch the coefficients recover.</p>
    <div class="choice-buttons" id="sampleButtons"></div>
    <table class="matrix" aria-label="Sample table"><thead><tr><th>x</th><th>observed y</th></tr></thead><tbody id="sampleTable"></tbody></table>
    <div id="coefOut" class="formula">Recovered: a=?, b=?, c=?</div>
  </div>
  <div class="card emphasis">
    <h3>What G6R does</h3>
    <ol>
      <li>Evaluate RR14 at 9 fixed (θb, θc) sample pairs.</li>
      <li>Multiply by a precomputed 9×9 inverse.</li>
      <li>Recover the 14×9 coefficient matrix P(θa).</li>
      <li>Evaluate θa at 0, π/2, π to split sin/cos/constant parts.</li>
    </ol>
    <p class="muted">This avoids a computer algebra system and makes generated solvers robot-adaptable.</p>
  </div>
</div>"""
        case "half-angle":
            return """<div class="grid-2">
  <div class="demo-box">
    <h3>Move the angle</h3>
    <div class="slider-row"><label for="thetaSlider">θ</label><input id="thetaSlider" type="range" min="-179" max="179" value="45" /><output id="thetaLabel">45°</output></div>
    <table class="matrix"><tbody><tr><th>sin θ</th><td id="sinOut"></td></tr><tr><th>cos θ</th><td id="cosOut"></td></tr><tr><th>x = tan(θ/2)</th><td id="tanOut"></td></tr></tbody></table>
    <div class="meter" aria-label="near pi warning"><span id="piMeter"></span></div>
    <p id="piHint" class="muted"></p>
  </div>
  <div class="card emphasis">
    <h3>The formulas</h3>
    <div class="formula">sin θ = 2x / (1 + x²)\ncos θ = (1 - x²) / (1 + x²)\nx = tan(θ/2)</div>
    <p>Near θ = ±π, x becomes huge. That is why the report emphasizes generalized eigenvalues and robust eigenvector extraction.</p>
  </div>
</div>"""
        case "filter":
            return """<div class="choice-buttons">
  <button class="choice active" data-filter-step="0">Candidate counts</button>
  <button class="choice" data-filter-step="1">Run verification</button>
  <button class="choice" data-filter-step="2">Newton polish</button>
</div>
<div id="filterPanel" class="grid-3"></div>"""
        case _:
            return ""


def _render_org_lines(lines: list[str]) -> str:
    cleaned = [line.rstrip() for line in lines]
    while cleaned and not cleaned[0].strip():
        cleaned.pop(0)
    while cleaned and not cleaned[-1].strip():
        cleaned.pop()
    if not cleaned:
        return ""

    if all(line.lstrip().startswith(("- ", "+ ")) or not line.strip() for line in cleaned):
        items = [_strip_list_marker(line) for line in cleaned if _strip_list_marker(line)]
        return "<ul>\n" + "\n".join(f"  <li>{_render_inline(item)}</li>" for item in items) + "\n</ul>"

    if all(line.strip().startswith("|") for line in cleaned if line.strip()):
        return _render_table(cleaned)

    paragraphs: list[str] = []
    current: list[str] = []
    for line in cleaned:
        if line.strip():
            current.append(line.strip())
        elif current:
            paragraphs.append(" ".join(current))
            current = []
    if current:
        paragraphs.append(" ".join(current))
    return "\n".join(f"<p>{_render_inline(paragraph)}</p>" for paragraph in paragraphs)


def _render_table(lines: list[str]) -> str:
    rows = []
    for line in lines:
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if all(re.fullmatch(r"[-+]+", cell) for cell in cells):
            continue
        rows.append(cells)
    if not rows:
        return ""
    parts = ['<table class="matrix">']
    parts.append("  <thead><tr>" + "".join(f"<th>{_render_inline(cell)}</th>" for cell in rows[0]) + "</tr></thead>")
    if len(rows) > 1:
        parts.append("  <tbody>")
        for row in rows[1:]:
            parts.append("    <tr>" + "".join(f"<td>{_render_inline(cell)}</td>" for cell in row) + "</tr>")
        parts.append("  </tbody>")
    parts.append("</table>")
    return "\n".join(parts)


def _strip_list_marker(line: str) -> str:
    match = re.match(r"^\s*[-+]\s+(.*)$", line)
    return match.group(1).strip() if match else line.strip()


def _render_inline(text: str) -> str:
    escaped = html.escape(text)
    escaped = re.sub(r"\[\[([^\]]+)\]\[([^\]]+)\]\]", r'<a href="\1">\2</a>', escaped)
    escaped = re.sub(r"(?<!\w)\*([^*]+)\*", r"<strong>\1</strong>", escaped)
    escaped = re.sub(r"~([^~]+)~", r"<code>\1</code>", escaped)
    return escaped


def _join_block(lines: list[str]) -> str:
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    return "\n".join(lines)


def render_deck(deck: Deck, template_path: str | Path = DEFAULT_TEMPLATE) -> str:
    """Render a deck as self-contained HTML."""

    template = Path(template_path).read_text()
    slide_html = "\n".join(_render_slide(slide, index == 0) for index, slide in enumerate(deck.slides))
    replacements = {
        "{{HTML_TITLE}}": html.escape(deck.title),
        "{{DECK_TITLE}}": html.escape(deck.title),
        "{{DECK_SUBTITLE}}": html.escape(deck.subtitle),
        "{{SOURCE_LABEL}}": html.escape(deck.source_label),
        "{{SLIDE_COUNT}}": str(len(deck.slides)),
        "{{SLIDES}}": slide_html,
    }
    for placeholder, value in replacements.items():
        template = template.replace(placeholder, value)
    return template


def _render_slide(slide: Slide, active: bool) -> str:
    classes = "slide active" if active else "slide"
    parts = [f'        <article class="{classes}" data-title="{html.escape(slide.nav_title)}">']
    if slide.eyebrow:
        parts.append(f'          <div class="eyebrow">{_render_inline(slide.eyebrow)}</div>')
    parts.append(f"          <h2>{_render_inline(slide.title)}</h2>")
    if slide.lead:
        parts.append(f'          <p class="lead">{_render_inline(slide.lead)}</p>')
    if slide.content_html:
        parts.append(_indent(slide.content_html, "          "))
    if slide.notes_html:
        parts.append('          <div class="notes">')
        parts.append(_indent(_render_org_lines(slide.notes_html.splitlines()), "            "))
        parts.append("          </div>")
    parts.append("        </article>")
    return "\n".join(parts)


def _indent(text: str, prefix: str) -> str:
    return "\n".join(prefix + line if line else line for line in text.splitlines())


def build_deck(source: str | Path, output: str | Path, template_path: str | Path = DEFAULT_TEMPLATE) -> None:
    """Build ``output`` from Org ``source``."""

    rendered = render_deck(parse_org_deck(source), template_path)
    output_path = Path(output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Org-mode deck source")
    parser.add_argument("output", type=Path, help="Generated standalone HTML deck")
    parser.add_argument(
        "--template",
        type=Path,
        default=DEFAULT_TEMPLATE,
        help=f"HTML template path (default: {DEFAULT_TEMPLATE})",
    )
    args = parser.parse_args()

    build_deck(args.source, args.output, args.template)
    print(f"Wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
