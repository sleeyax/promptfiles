#!/usr/bin/env python3
"""Fetch a shared Granola document and render its notes as markdown.

Usage:
  fetch-granola.py <url-or-id> [--format md|json] [--timeout SECONDS]

Accepts a Granola share URL (https://notes.granola.ai/d/<uuid>, query string
optional) or a bare document UUID. Prints the rendered notes to stdout.

Granola's share page renders client-side, but the document ships inside the
Next.js flight payload embedded in the served HTML, so no browser is needed.
The payload is a sequence of self.__next_f.push([1, "<chunk>"]) calls whose
chunks concatenate into one stream; the document lives in there as a
ProseMirror JSON doc.

Requests without a browser User-Agent are rejected with HTTP 403.

On failure: prints a diagnostic to stderr and exits non-zero.
"""

import argparse
import html
import json
import re
import sys
import urllib.error
import urllib.request

UA = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
)
UUID_RE = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", re.I)
CHUNK_RE = re.compile(r'self\.__next_f\.push\(\[1,("(?:[^"\\]|\\.)*")\]\)', re.S)


def die(msg):
    print(f"fetch-granola.py: {msg}", file=sys.stderr)
    sys.exit(1)


def resolve_url(arg):
    if UUID_RE.fullmatch(arg.strip()):
        return f"https://notes.granola.ai/d/{arg.strip()}"
    if "/t/" in arg:
        die(
            "that is a transcript URL (/t/...), which requires a Granola login and is "
            "not publicly shareable. Ask the user for the document URL (/d/...) instead."
        )
    m = UUID_RE.search(arg)
    if not m:
        die(f"no document id found in {arg!r}; expected a notes.granola.ai/d/<uuid> URL")
    return f"https://notes.granola.ai/d/{m.group(0)}"


def fetch(url, timeout):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "text/html"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        if e.code == 403:
            die("HTTP 403 — Granola rejected the request (share link may be private or revoked)")
        if e.code == 404:
            die("HTTP 404 — no such document; check the URL")
        die(f"HTTP {e.code} fetching {url}")
    except urllib.error.URLError as e:
        die(f"could not reach notes.granola.ai: {e.reason}")


def flight_payload(page):
    chunks = CHUNK_RE.findall(page)
    if not chunks:
        die("no Next.js payload in the page — Granola's share page format likely changed")
    return "".join(json.loads(c) for c in chunks)


def find_docs(payload):
    """Yield (panel_title, prosemirror_doc) for every document in the payload."""
    decoder = json.JSONDecoder()
    seen = set()
    for m in re.finditer(r'\{"type":"doc"', payload):
        try:
            doc, _ = decoder.raw_decode(payload[m.start():])
        except json.JSONDecodeError:
            continue
        key = json.dumps(doc, sort_keys=True)
        if key in seen:
            continue
        seen.add(key)
        preceding = payload[max(0, m.start() - 300):m.start()]
        titles = re.findall(r'"title":"((?:[^"\\]|\\.)*)"', preceding)
        yield (json.loads(f'"{titles[-1]}"') if titles else None), doc


def metadata(payload):
    meta = {}
    m = re.search(r'"document":\{(?:[^{}]|\{[^{}]*\})*\}', payload)
    if m:
        try:
            doc = json.loads(m.group(0)[len('"document":'):])
            meta["title"] = doc.get("title")
            meta["created_at"] = doc.get("created_at")
            owner = doc.get("owner") or {}
            meta["owner"] = owner.get("name")
        except json.JSONDecodeError:
            pass
    if not meta.get("title"):
        m = re.search(r'<title>(.*?)</title>', payload, re.S)
        if m:
            meta["title"] = html.unescape(m.group(1)).strip()
    return meta


def inline(node):
    text = node.get("text", "")
    for mark in node.get("marks", []):
        kind = mark.get("type")
        if kind == "code":
            text = f"`{text}`"
        elif kind in ("bold", "strong"):
            text = f"**{text}**"
        elif kind in ("italic", "em"):
            text = f"*{text}*"
        elif kind == "link":
            href = (mark.get("attrs") or {}).get("href")
            if href and href != text:
                text = f"[{text}]({href})"
    return text


def text_of(node):
    out = []
    for child in node.get("content", []):
        out.append(inline(child) if child.get("type") == "text" else text_of(child))
    return "".join(out)


def render(node, depth=0, ordered=None, index=1):
    kind = node.get("type")
    pad = "  " * depth
    out = []

    if kind == "heading":
        level = (node.get("attrs") or {}).get("level", 1)
        out.append(f"\n{'#' * level} {text_of(node)}")
    elif kind == "codeBlock":
        out.append(f"{pad}```\n{text_of(node)}\n{pad}```")
    elif kind == "horizontalRule":
        out.append("\n---")
    elif kind == "paragraph":
        body = text_of(node)
        if body.strip():
            out.append(f"{pad}{body}" if depth == 0 else f"{pad}{body}")
    elif kind == "listItem":
        bullet = f"{index}." if ordered else "-"
        first = True
        for child in node.get("content", []):
            if child.get("type") == "paragraph" and first:
                out.append(f"{pad}{bullet} {text_of(child)}")
                first = False
            else:
                out.extend(render(child, depth + 1))
    elif kind == "blockquote":
        for line in "\n".join(render(node, depth)).splitlines():
            out.append(f"{pad}> {line}")
    elif kind in ("bulletList", "orderedList"):
        is_ordered = kind == "orderedList"
        for i, child in enumerate(node.get("content", []), start=1):
            out.extend(render(child, depth, ordered=is_ordered, index=i))
    else:
        for child in node.get("content", []):
            out.extend(render(child, depth))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("target", help="Granola share URL or document UUID")
    ap.add_argument("--format", choices=("md", "json"), default="md")
    ap.add_argument("--timeout", type=float, default=30.0)
    args = ap.parse_args()

    url = resolve_url(args.target)
    payload = flight_payload(fetch(url, args.timeout))
    docs = list(find_docs(payload))
    if not docs:
        die("payload contained no document content — the share link may grant no access")

    if args.format == "json":
        print(json.dumps(
            {"url": url, "metadata": metadata(payload),
             "panels": [{"title": t, "content": d} for t, d in docs]},
            indent=2, ensure_ascii=False,
        ))
        return

    meta = metadata(payload)
    lines = []
    if meta.get("title"):
        lines.append(f"# {meta['title']}")
    trailer = [v for v in (meta.get("created_at"), meta.get("owner")) if v]
    if trailer:
        lines.append(" · ".join(trailer))
    lines.append(f"source: {url}")

    for title, doc in docs:
        if len(docs) > 1 and title:
            lines.append(f"\n## {title}")
        lines.extend(render(doc))

    print(re.sub(r"\n{3,}", "\n\n", "\n".join(lines).strip()))


if __name__ == "__main__":
    main()
