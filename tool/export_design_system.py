"""디자인 시스템 원본(docs/design/design-system/project/)으로 정적 HTML 한 장을 만든다.

실행: python3 tool/export_design_system.py
결과: docs/design/design-system/index.html (토큰·글꼴·컴포넌트 미리보기)
"""
import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "docs/design/design-system/project"
OUT = ROOT / "docs/design/design-system/index.html"
FONT = "../../../assets/fonts/RunmagochiSans.ttf"  # 앱에 번들한 Pretendard 서브셋


def inline(text):
    t = html.escape(text)
    t = re.sub(r"`([^`]+)`", r"<code>\1</code>", t)
    t = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", t)
    return t


def md(text, skip_h1=True):
    out, para, lst, table = [], [], [], []

    def flush():
        if para:
            out.append(f"<p>{inline(' '.join(para))}</p>")
            para.clear()
        if lst:
            out.append("<ul>" + "".join(f"<li>{inline(i)}</li>" for i in lst) + "</ul>")
            lst.clear()
        if table:
            rows = [r for r in table if not re.fullmatch(r"\|[\s:|-]+\|", r)]
            cells = [[c.strip() for c in r.strip("|").split("|")] for r in rows]
            head, body = cells[0], cells[1:]
            out.append('<div class="tbl"><table><thead><tr>' + "".join(f"<th>{inline(c)}</th>" for c in head)
                       + "</tr></thead><tbody>" + "".join("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>" for r in body)
                       + "</tbody></table></div>")
            table.clear()

    for line in text.splitlines():
        s = line.rstrip()
        if not s:
            flush()
        elif s.startswith("|"):
            if para or lst:
                flush()
            table.append(s)
        elif m := re.match(r"(#{1,4}) (.*)", s):
            flush()
            if len(m.group(1)) == 1 and skip_h1:
                continue
            out.append(f"<h4>{inline(m.group(2))}</h4>")
        elif m := re.match(r"\s*[-*] (.*)", s):
            if para:
                flush()
            lst.append(m.group(1))
        else:
            if lst:
                flush()
            para.append(s.strip())
    flush()
    return "\n".join(out)


def css_vars(tokens):
    light, dark, plain = [], [], []
    for t in tokens["color"]["tokens"]:
        v = t["value"]
        if isinstance(v, dict):
            light.append(f"--{t['name']}: {v['light']};")
            if "dark" in v:
                dark.append(f"--{t['name']}: {v['dark']};")
        else:
            light.append(f"--{t['name']}: {v};")
    for fam, val in tokens.items():
        if fam in ("color", "type", "name", "version", "meta") or not isinstance(val, dict):
            continue
        for t in val.get("tokens", []):
            plain.append(f"--{t['name']}: {t['value']};")
    sans = tokens["type"]["families"]["sans"]
    root = " ".join(light + plain) + f' --font-sans: "Runmagochi Sans", {sans};'
    d = " ".join(dark)
    return (f'@font-face {{ font-family: "Runmagochi Sans"; src: url("{FONT}") format("truetype"); font-weight: 45 920; font-display: swap; }}\n'
            f":root {{ {root} }}\n"
            f'@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{ {d} color-scheme: dark; }} }}\n'
            f':root[data-theme="dark"] {{ {d} color-scheme: dark; }}\n')


def main():
    tokens = json.loads((SRC / "tokens.json").read_text())
    readme = (SRC / "README.md").read_text()
    vars_css = css_vars(tokens)

    swatches = []
    for t in tokens["color"]["tokens"]:
        v = t["value"] if isinstance(t["value"], dict) else {"light": t["value"]}
        swatches.append(
            f'<div class="sw"><div class="chip" style="background:var(--{t["name"]})"></div>'
            f'<div class="sw-t"><b>{t["name"]}</b><span class="hex">{v.get("light", "")} · {v.get("dark", v.get("light", ""))}</span>'
            f'<span class="use">{inline(t.get("usage", ""))}</span></div></div>')

    type_rows = []
    for g in tokens["type"]["groups"]:
        for st in g["styles"]:
            size = st["fontSize"]
            shown = "min(" + size + ", 64px)"
            sample = "3.27" if g["name"] == "Number" else "달릴수록 자라는 친구"
            type_rows.append(
                f'<div class="ty"><div class="ty-s" style="font-size:{shown};line-height:1.1;font-weight:{st["fontWeight"]};letter-spacing:{st.get("letterSpacing", "normal")}">{sample}</div>'
                f'<div class="ty-m"><b>{st["name"]}</b><span>{size} / {st["lineHeight"]} · {st["fontWeight"]}</span></div></div>')

    scales = []
    for fam in ("spacing", "radius", "border", "shadow", "stage", "duration", "easing"):
        toks = tokens.get(fam, {}).get("tokens", [])
        if not toks:
            continue
        rows = "".join(f'<tr><td><code>{t["name"]}</code></td><td class="v">{html.escape(str(t["value"]))}</td><td>{inline(t.get("usage", ""))}</td></tr>' for t in toks)
        scales.append(f'<h3>{fam}</h3><div class="tbl"><table><tbody>{rows}</tbody></table></div>')

    order = ["Actions", "Selection", "Data", "Feedback", "Mascot", "Navigation"]
    comps = []
    for d in sorted((SRC / "components").iterdir()):
        prev = d / "preview.html"
        if not prev.exists() or d.name == "Cover":
            continue
        src = prev.read_text()
        m = re.match(r'<!-- @dsCard(.*?)-->', src)
        meta = m.group(1) if m else ""
        group = (re.search(r'group="([^"]+)"', meta) or [None, "Other"])[1]
        height = int((re.search(r"height=(\d+)", meta) or [None, "240"])[1])
        sub = (re.search(r'subtitle="([^"]+)"', meta) or [None, ""])[1]
        body = src[m.end():] if m else src
        doc = f"<!doctype html><html><head><meta charset='utf-8'><style>{vars_css} *{{box-sizing:border-box}} body{{margin:0}}</style></head><body>{body}</body></html>"
        rd = (d / "README.md").read_text() if (d / "README.md").exists() else ""
        comps.append((order.index(group) if group in order else 99, group,
                      f'<article class="comp" id="{d.name}"><div class="comp-h"><h3>{d.name}</h3><span class="grp">{group}</span></div>'
                      f'<p class="sub">{html.escape(sub)}</p>'
                      f'<iframe title="{d.name} 미리보기" srcdoc="{html.escape(doc, quote=True)}" style="height:{height}px" loading="lazy"></iframe>'
                      f'<div class="rd">{md(rd)}</div></article>'))
    comps.sort(key=lambda c: (c[0], c[2]))
    nav = "".join(f'<a href="#{re.search(r"id=\"([^\"]+)\"", c[2]).group(1)}">{re.search(r"id=\"([^\"]+)\"", c[2]).group(1)}</a>' for c in comps)

    page = f"""<!doctype html>
<html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>런마고치 디자인 시스템</title>
<style>
{vars_css}
* {{ box-sizing: border-box; }}
body {{ margin: 0; background: var(--background); color: var(--ink); font: 500 16px/1.6 var(--font-sans); }}
.wrap {{ max-width: 1120px; margin: 0 auto; padding: 0 20px; }}
header {{ padding-block: 48px 8px; }}
h1, h2, h3 {{ word-break: keep-all; }}
h1 {{ font-size: clamp(34px, 5vw, 52px); font-weight: 800; letter-spacing: -.03em; margin: 0; }}
h2 {{ font-size: 28px; font-weight: 800; letter-spacing: -.02em; margin: 0 0 18px; }}
h3 {{ font-size: 18px; font-weight: 800; margin: 0; }}
h4 {{ font-size: 15px; font-weight: 800; color: var(--ink-muted); margin: 18px 0 6px; }}
p {{ margin: 0 0 8px; }}
ul {{ margin: 0 0 8px; padding-left: 20px; }}
code {{ font: 13px ui-monospace, Menlo, monospace; background: var(--surface-soft); padding: 1px 6px; border-radius: 6px; overflow-wrap: anywhere; }}
section {{ padding-block: 48px 0; }}
.lead {{ max-width: 46em; color: var(--ink); }}
.lead p:first-child {{ font-size: 19px; font-weight: 700; }}
.bar {{ display: flex; flex-wrap: wrap; gap: 8px; align-items: center; margin-top: 20px; }}
.bar button {{ font: 700 14px var(--font-sans); padding: 8px 16px; border-radius: 999px; border: 2px solid var(--line); background: var(--surface); color: var(--ink); cursor: pointer; }}
.bar button[aria-pressed="true"] {{ background: var(--primary); color: var(--on-primary); border-color: var(--primary); }}
.toc {{ display: flex; flex-wrap: wrap; gap: 6px; margin-top: 14px; }}
.toc a {{ font-size: 13px; font-weight: 700; color: var(--ink); text-decoration: none; background: var(--surface); padding: 4px 12px; border-radius: 999px; }}
.toc a:hover {{ background: var(--primary); color: var(--on-primary); }}
.swatches {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 10px; }}
.sw {{ background: var(--surface); border-radius: 16px; padding: 12px; display: grid; grid-template-columns: 52px minmax(0, 1fr); gap: 12px; align-items: start; }}
.chip {{ width: 52px; height: 52px; border-radius: 12px; box-shadow: inset 0 0 0 1px rgba(127,127,127,.25); }}
.sw-t {{ display: grid; gap: 2px; min-width: 0; }}
.sw-t b {{ font-size: 14px; }}
.hex {{ font: 12px ui-monospace, Menlo, monospace; color: var(--ink-muted); }}
.use {{ font-size: 13px; color: var(--ink-muted); line-height: 1.45; }}
.types {{ display: grid; gap: 8px; }}
.ty {{ background: var(--surface); border-radius: 16px; padding: 14px 18px; display: flex; flex-wrap: wrap; gap: 8px 20px; align-items: baseline; justify-content: space-between; font-variant-numeric: tabular-nums; }}
.ty-s {{ min-width: 0; overflow-wrap: anywhere; }}
.ty-m {{ display: grid; text-align: right; font-size: 13px; color: var(--ink-muted); }}
.ty-m b {{ color: var(--ink); }}
.tbl {{ overflow-x: auto; background: var(--surface); border-radius: 16px; margin: 10px 0 22px; }}
table {{ border-collapse: collapse; width: 100%; font-size: 14px; }}
th, td {{ text-align: left; padding: 9px 14px; border-bottom: 1px solid var(--line); vertical-align: top; }}
tr:last-child td {{ border-bottom: 0; }}
td.v {{ font: 13px ui-monospace, Menlo, monospace; white-space: nowrap; }}
.comps {{ display: grid; grid-template-columns: minmax(0, 1fr); gap: 16px; }}
.comp {{ background: var(--surface); border-radius: 22px; padding: 20px 22px; min-width: 0; }}
.comp-h {{ display: flex; gap: 10px; align-items: baseline; }}
.grp {{ font-size: 12px; font-weight: 700; color: var(--ink-muted); background: var(--surface-soft); border-radius: 999px; padding: 2px 10px; }}
.sub {{ color: var(--ink-muted); font-size: 14px; margin-top: 4px; }}
iframe {{ width: 100%; border: 0; border-radius: 14px; background: var(--background); display: block; margin-top: 10px; }}
.rd {{ font-size: 15px; margin-top: 12px; }}
.rd h4:first-child {{ margin-top: 0; }}
footer {{ padding-block: 48px; color: var(--ink-muted); font-size: 13px; }}
</style></head><body>
<header><div class="wrap">
<h1>런마고치 디자인 시스템</h1>
<div class="lead">{md(readme)}</div>
<div class="bar" role="group" aria-label="화면 모드"><button type="button" data-t="" aria-pressed="true">시스템</button><button type="button" data-t="light" aria-pressed="false">라이트</button><button type="button" data-t="dark" aria-pressed="false">다크</button></div>
</div></header>
<main class="wrap">
<section id="color"><h2>색</h2><div class="swatches">{''.join(swatches)}</div></section>
<section id="type"><h2>글꼴</h2><div class="types">{''.join(type_rows)}</div></section>
<section id="scale"><h2>간격·모서리·그림자·무대·움직임</h2>{''.join(scales)}</section>
<section id="components"><h2>컴포넌트</h2><nav class="toc" aria-label="컴포넌트 목록">{nav}</nav><div class="comps" style="margin-top:16px">{''.join(c[2] for c in comps)}</div></section>
</main>
<footer><div class="wrap">원본 <code>docs/design/design-system/project/</code> · <code>python3 tool/export_design_system.py</code> 로 다시 만든다.</div></footer>
<script>
document.querySelectorAll('.bar button').forEach(function (b) {{
  b.addEventListener('click', function () {{
    var t = b.dataset.t;
    var docs = [document].concat(Array.prototype.map.call(document.querySelectorAll('iframe'), function (f) {{ return f.contentDocument; }}));
    docs.forEach(function (d) {{ if (!d) return; if (t) d.documentElement.setAttribute('data-theme', t); else d.documentElement.removeAttribute('data-theme'); }});
    document.querySelectorAll('.bar button').forEach(function (x) {{ x.setAttribute('aria-pressed', String(x === b)); }});
  }});
}});
</script>
</body></html>
"""
    OUT.write_text(page)
    print(f"{OUT.relative_to(ROOT)} ({len(comps)} 컴포넌트, 색 {len(swatches)}개)")


if __name__ == "__main__":
    main()
