#!/usr/bin/env python3
"""Build a standalone HTML viewer from the markdown docs.

Markdown in docs/ (and README.md) is the source of truth. This script parses
those files and writes a self-contained HTML page that can be opened as a
file — no HTTP server, and no second copy of the markdown kept in git.

Usage:
  python3 scripts/generate-viewer.py
  python3 scripts/generate-viewer.py --open
"""

from __future__ import annotations

import argparse
import html
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DEFAULT = ROOT / "docs" / "generated" / "index.html"

DOCS: list[tuple[str, Path, str, str]] = [
    # key, path, label, group
    ("plan", ROOT / "docs/plan.md", "Plan", "Overview"),
    ("architecture", ROOT / "docs/architecture.md", "Architecture", "Overview"),
    ("decisions", ROOT / "docs/decisions.md", "Decisions", "Overview"),
    ("briefs", ROOT / "docs/decision-briefs.md", "Decision briefs", "Overview"),
    ("vlan", ROOT / "docs/vlan-plan.md", "VLAN plan", "Network"),
    ("firewall", ROOT / "docs/firewall-matrix.md", "Firewall", "Network"),
    ("inventory", ROOT / "docs/inventory.md", "Inventory", "Network"),
    ("stages", ROOT / "docs/implementation-stages.md", "Stages", "Build"),
    ("bsp", ROOT / "docs/plans/rk1-bsp-fork.md", "RK1 BSP fork", "Deferred"),
    ("refAuth", ROOT / "docs/reference/auth-authelia-vs-authentik.md", "Auth", "Reference"),
    ("refSecrets", ROOT / "docs/reference/secrets-sops-vs-agenix.md", "Secrets", "Reference"),
    ("refGitops", ROOT / "docs/reference/gitops-flux-vs-argocd.md", "GitOps", "Reference"),
    ("refRouter", ROOT / "docs/reference/router-os-alternatives.md", "Router OS", "Reference"),
    ("refEscape", ROOT / "docs/reference/escape-hatches-ubuntu-talos.md", "RK1 escape", "Reference"),
    ("refCgnat", ROOT / "docs/reference/cgnat-options.md", "CGNAT", "Reference"),
    ("refBom", ROOT / "docs/reference/hardware-bom-norway.md", "Hardware BOM", "Reference"),
    ("readme", ROOT / "README.md", "README", "Repo"),
]

HEADING_RE = re.compile(r"^(#{1,6})\s+(.*)$")
FENCE_RE = re.compile(r"^```([\w-]*)\s*$")
HR_RE = re.compile(r"^(\*{3,}|-{3,}|_{3,})\s*$")
UL_RE = re.compile(r"^(\s*)([-*+])\s+(.*)$")
OL_RE = re.compile(r"^(\s*)(\d+)[.)]\s+(.*)$")
TASK_RE = re.compile(r"^\[([ xX])\]\s+(.*)$")
SEP_RE = re.compile(r"^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$")


def slugify(text: str) -> str:
    text = re.sub(r"<[^>]+>", "", text)
    text = html.unescape(text).lower().strip()
    text = re.sub(r"[^\w\s-]", "", text, flags=re.UNICODE)
    text = re.sub(r"\s+", "-", text)
    text = re.sub(r"-+", "-", text)
    return text.strip("-")


class Converter:
    def __init__(self, key: str, source: Path, path_map: dict[Path, str]):
        self.key = key
        self.source = source
        self.path_map = path_map
        self.used_ids: dict[str, int] = {}

    def heading_id(self, text: str) -> str:
        base = slugify(re.sub(r"<[^>]+>", "", text)) or "section"
        n = self.used_ids.get(base, 0)
        self.used_ids[base] = n + 1
        slug = base if n == 0 else f"{base}-{n}"
        return f"{self.key}/{slug}"

    def rewrite_href(self, href: str) -> str:
        if href.startswith(("http://", "https://", "mailto:")):
            return href
        path_part, _, frag = href.partition("#")
        if not path_part:
            return f"#{self.key}/{frag}" if frag else f"#{self.key}"

        raw = path_part.split("?")[0]
        candidate = (self.source.parent / raw).resolve()
        if candidate in self.path_map:
            dest = self.path_map[candidate]
            return f"#{dest}/{frag}" if frag else f"#{dest}"

        if candidate.is_dir():
            for path, dest in self.path_map.items():
                try:
                    path.relative_to(candidate)
                except ValueError:
                    continue
                if dest.startswith("ref"):
                    return f"#{dest}"
            return href

        name = Path(raw).name
        for path, dest in self.path_map.items():
            if path.name == name:
                return f"#{dest}/{frag}" if frag else f"#{dest}"
        return href

    def inline(self, text: str) -> str:
        parts: list[str] = []
        pos = 0
        link_re = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")
        for m in link_re.finditer(text):
            parts.append(self._codes_and_emphasis(text[pos : m.start()]))
            label = self._codes_and_emphasis(m.group(1))
            href = html.escape(self.rewrite_href(m.group(2)), quote=True)
            parts.append(f'<a href="{href}">{label}</a>')
            pos = m.end()
        parts.append(self._codes_and_emphasis(text[pos:]))
        return "".join(parts)

    def _codes_and_emphasis(self, text: str) -> str:
        parts: list[str] = []
        pos = 0
        code_re = re.compile(r"`([^`]+)`")
        for m in code_re.finditer(text):
            parts.append(self._emphasis(html.escape(text[pos : m.start()])))
            parts.append("<code>" + html.escape(m.group(1)) + "</code>")
            pos = m.end()
        parts.append(self._emphasis(html.escape(text[pos:])))
        return "".join(parts)

    @staticmethod
    def _emphasis(text: str) -> str:
        text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
        text = re.sub(r"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)", r"<em>\1</em>", text)
        return text

    def convert(self, md: str) -> str:
        lines = md.replace("\r\n", "\n").replace("\r", "\n").split("\n")
        blocks: list[str] = []
        i = 0
        n = len(lines)
        while i < n:
            line = lines[i]
            if line.strip() == "":
                i += 1
                continue

            fence = FENCE_RE.match(line)
            if fence:
                lang = fence.group(1)
                i += 1
                body: list[str] = []
                while i < n and not FENCE_RE.match(lines[i]):
                    body.append(lines[i])
                    i += 1
                if i < n:
                    i += 1
                code = "\n".join(body)
                if lang.lower() == "mermaid":
                    blocks.append(
                        '<div class="mermaid">' + html.escape(code) + "</div>"
                    )
                else:
                    blocks.append(
                        "<pre><code>" + html.escape(code) + "</code></pre>"
                    )
                continue

            heading = HEADING_RE.match(line)
            if heading:
                level = len(heading.group(1))
                inner = self.inline(heading.group(2).rstrip())
                hid = html.escape(self.heading_id(heading.group(2)), quote=True)
                blocks.append(f'<h{level} id="{hid}">{inner}</h{level}>')
                i += 1
                continue

            if HR_RE.match(line.strip()) and not line.strip().startswith("|"):
                blocks.append("<hr>")
                i += 1
                continue

            if "|" in line and i + 1 < n and SEP_RE.match(lines[i + 1]):
                table_lines = [line]
                i += 1
                while i < n and lines[i].strip() and "|" in lines[i]:
                    table_lines.append(lines[i])
                    i += 1
                blocks.append(self._table(table_lines))
                continue

            ul = UL_RE.match(line)
            ol = OL_RE.match(line)
            if ul or ol:
                ordered = ol is not None
                items: list[tuple[str, bool | None]] = []
                while i < n:
                    m = (OL_RE if ordered else UL_RE).match(lines[i])
                    if not m:
                        break
                    body = m.group(3)
                    task = TASK_RE.match(body)
                    if task:
                        checked = task.group(1).lower() == "x"
                        items.append((self.inline(task.group(2)), checked))
                    else:
                        items.append((self.inline(body), None))
                    i += 1
                tag = "ol" if ordered else "ul"
                lis = []
                for inner, checked in items:
                    if checked is None:
                        lis.append(f"<li>{inner}</li>")
                    else:
                        attr = " checked" if checked else ""
                        lis.append(
                            f'<li><input type="checkbox" disabled{attr}>{inner}</li>'
                        )
                blocks.append(f"<{tag}>" + "".join(lis) + f"</{tag}>")
                continue

            if line.startswith(">"):
                quote: list[str] = []
                while i < n and lines[i].startswith(">"):
                    quote.append(lines[i].lstrip(">").lstrip())
                    i += 1
                inner = self.inline(" ".join(quote))
                blocks.append(f"<blockquote><p>{inner}</p></blockquote>")
                continue

            para: list[str] = []
            while i < n and lines[i].strip():
                if (
                    HEADING_RE.match(lines[i])
                    or FENCE_RE.match(lines[i])
                    or UL_RE.match(lines[i])
                    or OL_RE.match(lines[i])
                    or (
                        "|" in lines[i]
                        and i + 1 < n
                        and SEP_RE.match(lines[i + 1])
                    )
                    or (
                        HR_RE.match(lines[i].strip())
                        and not lines[i].strip().startswith("|")
                    )
                ):
                    break
                para.append(lines[i].rstrip())
                i += 1
            if para:
                blocks.append("<p>" + self.inline(" ".join(para)) + "</p>")

        return "\n".join(blocks)

    def _table(self, lines: list[str]) -> str:
        rows = [self._split_row(line) for line in lines]
        if len(rows) < 2:
            return "<p>" + self.inline(lines[0]) + "</p>"
        header, _sep, *body = rows[0], rows[1], *rows[2:]
        thead = "<thead><tr>" + "".join(
            f"<th>{self.inline(c)}</th>" for c in header
        ) + "</tr></thead>"
        tbody_rows = []
        for row in body:
            cells = row + [""] * (len(header) - len(row))
            tbody_rows.append(
                "<tr>"
                + "".join(f"<td>{self.inline(c)}</td>" for c in cells[: len(header)])
                + "</tr>"
            )
        tbody = "<tbody>" + "".join(tbody_rows) + "</tbody>"
        return f"<table>{thead}{tbody}</table>"

    @staticmethod
    def _split_row(line: str) -> list[str]:
        line = line.strip()
        if line.startswith("|"):
            line = line[1:]
        if line.endswith("|"):
            line = line[:-1]
        return [cell.strip() for cell in line.split("|")]


CSS = """
    :root {
      --bg: #0f1419;
      --bg-sidebar: #1a2332;
      --bg-content: #151b24;
      --text: #e6edf3;
      --text-muted: #8b9cb3;
      --border: #2d3a4f;
      --accent: #58a6ff;
      --accent-dim: #388bfd66;
      --code-bg: #1c2430;
      --table-stripe: #1a2230;
    }
    @media (prefers-color-scheme: light) {
      :root {
        --bg: #f6f8fa;
        --bg-sidebar: #ffffff;
        --bg-content: #ffffff;
        --text: #1f2328;
        --text-muted: #656d76;
        --border: #d0d7de;
        --accent: #0969da;
        --accent-dim: #0969da22;
        --code-bg: #f6f8fa;
        --table-stripe: #f6f8fa;
      }
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
      font-size: 16px;
      line-height: 1.6;
      color: var(--text);
      background: var(--bg);
    }
    .layout { display: grid; grid-template-columns: 260px 1fr; min-height: 100vh; }
    @media (max-width: 900px) {
      .layout { grid-template-columns: 1fr; }
      .sidebar { position: relative; height: auto; }
    }
    .sidebar {
      background: var(--bg-sidebar);
      border-right: 1px solid var(--border);
      padding: 1.25rem;
      position: sticky;
      top: 0;
      height: 100vh;
      overflow-y: auto;
    }
    .sidebar h1 { font-size: 1.1rem; margin: 0 0 0.25rem; font-weight: 600; }
    .sidebar .subtitle { color: var(--text-muted); font-size: 0.8rem; margin-bottom: 1.25rem; }
    .nav-docs { display: flex; flex-direction: column; gap: 0.2rem; margin-bottom: 1.5rem; }
    .nav-group {
      font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.05em;
      color: var(--text-muted); margin: 0.9rem 0 0.25rem; padding: 0 0.75rem;
    }
    .nav-group:first-child { margin-top: 0; }
    .nav-docs button {
      text-align: left; background: none; border: 1px solid transparent;
      border-radius: 6px; padding: 0.4rem 0.75rem; color: var(--text);
      font-size: 0.88rem; cursor: pointer;
    }
    .nav-docs button:hover { background: var(--accent-dim); }
    .nav-docs button.active {
      background: var(--accent-dim); border-color: var(--accent);
      color: var(--accent); font-weight: 600;
    }
    .toc { font-size: 0.8rem; }
    .toc h2 {
      font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.05em;
      color: var(--text-muted); margin: 0 0 0.5rem;
    }
    .toc ul { list-style: none; padding: 0; margin: 0; }
    .toc li { margin: 0.15rem 0; }
    .toc a {
      color: var(--text-muted); text-decoration: none; display: block;
      padding: 0.15rem 0; line-height: 1.35;
    }
    .toc a:hover { color: var(--accent); }
    .toc .h3 { padding-left: 0.75rem; }
    .toc .h4 { padding-left: 1.5rem; }
    main { padding: 2rem 2.5rem 4rem; max-width: 52rem; background: var(--bg-content); }
    .content[hidden] { display: none !important; }
    .content h1 { font-size: 2rem; border-bottom: 1px solid var(--border); padding-bottom: 0.4rem; margin-top: 0; }
    .content h2 { font-size: 1.5rem; margin-top: 2rem; border-bottom: 1px solid var(--border); padding-bottom: 0.3rem; }
    .content h3 { font-size: 1.2rem; margin-top: 1.5rem; }
    .content h4 { font-size: 1rem; margin-top: 1.25rem; }
    .content a { color: var(--accent); }
    .content p, .content ul, .content ol { margin: 0.75rem 0; }
    .content li { margin: 0.25rem 0; }
    .content code {
      background: var(--code-bg); padding: 0.15rem 0.4rem; border-radius: 4px;
      font-size: 0.9em; border: 1px solid var(--border);
    }
    .content pre {
      background: var(--code-bg); border: 1px solid var(--border); border-radius: 8px;
      padding: 1rem; overflow-x: auto; font-size: 0.85rem; line-height: 1.45;
    }
    .content pre code { background: none; border: none; padding: 0; }
    .content table {
      width: 100%; border-collapse: collapse; font-size: 0.9rem;
      margin: 1rem 0; display: block; overflow-x: auto;
    }
    .content th, .content td {
      border: 1px solid var(--border); padding: 0.5rem 0.75rem; text-align: left;
    }
    .content th { background: var(--table-stripe); font-weight: 600; }
    .content tr:nth-child(even) td { background: var(--table-stripe); }
    .content blockquote {
      border-left: 4px solid var(--accent); margin: 1rem 0;
      padding: 0.25rem 1rem; color: var(--text-muted);
    }
    .content hr { border: none; border-top: 1px solid var(--border); margin: 2rem 0; }
    .content input[type="checkbox"] { margin-right: 0.4rem; pointer-events: none; }
    .mermaid {
      background: var(--code-bg); border: 1px solid var(--border); border-radius: 8px;
      padding: 1rem; margin: 1rem 0; text-align: center; overflow-x: auto;
    }
    @media print {
      .sidebar { display: none !important; }
      .layout { display: block; }
      .content[hidden] { display: none !important; }
      main { max-width: none; padding: 0; background: white; color: black; }
    }
"""

JS = r"""
    const LABELS = %LABELS%;

    mermaid.initialize({
      startOnLoad: false,
      theme: window.matchMedia("(prefers-color-scheme: light)").matches ? "default" : "dark",
      securityLevel: "strict",
    });

    let current = "plan";

    function parseHash() {
      const raw = (location.hash || "").replace(/^#/, "");
      if (!raw) return { key: "plan", heading: null };
      const slash = raw.indexOf("/");
      if (slash === -1) {
        return LABELS[raw] ? { key: raw, heading: null } : { key: "plan", heading: null };
      }
      const key = raw.slice(0, slash);
      return {
        key: LABELS[key] ? key : "plan",
        heading: raw.slice(slash + 1) || null,
      };
    }

    function setActive(key) {
      document.querySelectorAll(".nav-docs button").forEach((btn) => {
        btn.classList.toggle("active", btn.dataset.doc === key);
      });
    }

    function buildToc(article) {
      const tocList = document.getElementById("toc-list");
      const tocNav = document.getElementById("toc");
      tocList.innerHTML = "";
      const headings = article.querySelectorAll("h2, h3, h4");
      if (headings.length === 0) {
        tocNav.hidden = true;
        return;
      }
      headings.forEach((heading) => {
        const li = document.createElement("li");
        li.className = heading.tagName.toLowerCase();
        const a = document.createElement("a");
        a.href = "#" + heading.id;
        a.textContent = heading.textContent;
        li.appendChild(a);
        tocList.appendChild(li);
      });
      tocNav.hidden = false;
    }

    async function renderMermaid(article) {
      const nodes = [...article.querySelectorAll(".mermaid")];
      if (nodes.length === 0) return;
      nodes.forEach((node) => {
        if (!node.dataset.src) node.dataset.src = node.textContent.trim();
        node.removeAttribute("data-processed");
        node.textContent = node.dataset.src;
      });
      try {
        await mermaid.run({ nodes });
      } catch (err) {
        console.error("Mermaid render error:", err);
      }
    }

    async function show(key, heading) {
      current = key;
      document.querySelectorAll("article.content").forEach((el) => {
        el.hidden = el.dataset.doc !== key;
      });
      setActive(key);
      const article = document.querySelector('article.content[data-doc="' + key + '"]');
      if (!article) return;
      buildToc(article);
      await renderMermaid(article);
      document.title = LABELS[key] + " — net";
      const next = "#" + key + (heading ? "/" + heading : "");
      if (location.hash !== next) history.replaceState(null, "", next);
      if (heading) {
        const target = document.getElementById(key + "/" + heading);
        if (target) target.scrollIntoView();
        else window.scrollTo(0, 0);
      } else {
        window.scrollTo(0, 0);
      }
    }

    document.querySelectorAll(".nav-docs button").forEach((btn) => {
      btn.addEventListener("click", () => show(btn.dataset.doc));
    });

    window.addEventListener("hashchange", () => {
      const { key, heading } = parseHash();
      show(key, heading);
    });

    document.querySelector("main").addEventListener("click", (event) => {
      const a = event.target.closest("a");
      if (!a) return;
      const href = a.getAttribute("href") || "";
      if (!href.startsWith("#")) return;
      event.preventDefault();
      const raw = href.replace(/^#/, "");
      const slash = raw.indexOf("/");
      const parsed =
        slash === -1
          ? { key: LABELS[raw] ? raw : current, heading: LABELS[raw] ? null : raw }
          : { key: raw.slice(0, slash), heading: raw.slice(slash + 1) };
      show(LABELS[parsed.key] ? parsed.key : current, parsed.heading || null);
    });

    const initial = parseHash();
    show(initial.key, initial.heading);
"""


def build_nav() -> str:
    parts: list[str] = []
    last_group = None
    for key, _path, label, group in DOCS:
        if group != last_group:
            parts.append(f'        <p class="nav-group">{html.escape(group)}</p>')
            last_group = group
        parts.append(
            f'        <button type="button" data-doc="{html.escape(key)}">'
            f"{html.escape(label)}</button>"
        )
    return "\n".join(parts)


def build() -> str:
    path_map = {path.resolve(): key for key, path, _label, _group in DOCS}
    articles: list[str] = []
    for key, path, label, _group in DOCS:
        md = path.read_text(encoding="utf-8")
        body = Converter(key, path, path_map).convert(md)
        articles.append(
            f'      <article class="content" data-doc="{html.escape(key)}" '
            f'aria-label="{html.escape(label)}" hidden>\n{body}\n      </article>'
        )

    labels = {key: label for key, _p, label, _g in DOCS}
    import json

    js = JS.replace("%LABELS%", json.dumps(labels))

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>net — Network Plan</title>
  <!-- Generated by scripts/generate-viewer.py from markdown. Do not edit. -->
  <style>{CSS}
  </style>
</head>
<body>
  <div class="layout">
    <aside class="sidebar">
      <h1>net</h1>
      <p class="subtitle">Home network architecture</p>
      <nav class="nav-docs" aria-label="Documents">
{build_nav()}
      </nav>
      <nav class="toc" id="toc" hidden>
        <h2>On this page</h2>
        <ul id="toc-list"></ul>
      </nav>
    </aside>
    <main>
{chr(10).join(articles)}
    </main>
  </div>
  <script src="https://cdn.jsdelivr.net/npm/mermaid@10.9.1/dist/mermaid.min.js"></script>
  <script>
{js}
  </script>
</body>
</html>
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=OUT_DEFAULT,
        help=f"output path (default: {OUT_DEFAULT})",
    )
    parser.add_argument(
        "--open",
        action="store_true",
        help="open the generated file in the default browser",
    )
    args = parser.parse_args()

    missing = [str(path) for _k, path, _l, _g in DOCS if not path.is_file()]
    if missing:
        print("missing markdown:", *missing, sep="\n  ", file=sys.stderr)
        return 1

    out: Path = args.output
    if not out.is_absolute():
        out = ROOT / out
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(build(), encoding="utf-8")
    print(f"wrote {out}")

    if args.open:
        opener = "open" if sys.platform == "darwin" else "xdg-open"
        subprocess.run([opener, str(out)], check=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
