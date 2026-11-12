"""Build this project's small Markdown subset into a standalone offline guide."""
from pathlib import Path
import argparse, base64, html, re
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--lang',choices=['cn','en'],default='cn')
args=parser.parse_args()
lang=args.lang.upper()
english=args.lang=='en'
lines=(ROOT/f'docs/USER_GUIDE_{lang}.md').read_text().splitlines()

def link(href):
    # Standalone downloaded guides must not depend on adjacent Markdown files.
    if not href.startswith(('https://','http://','#')):
        from posixpath import normpath
        href='https://github.com/yilongzhao1122/garmin-badminton-score/blob/main/'+normpath('docs/'+href)
    return href

def inline(s):
    s=html.escape(s)
    s=re.sub(r'`([^`]+)`',r'<code>\1</code>',s)
    s=re.sub(r'\*\*([^*]+)\*\*',r'<strong>\1</strong>',s)
    return re.sub(r'\[([^\]]+)\]\(([^)]+)\)',lambda m:'<a href="'+link(m[2])+'">'+m[1]+'</a>',s)

parts=[];paragraph=[];toc=[];i=0

def flush():
    if paragraph:
        parts.append('<p>'+inline(' '.join(paragraph))+'</p>');paragraph.clear()

while i<len(lines):
    s=lines[i]
    if not s.strip():flush();i+=1;continue
    if s.startswith('```'):
        flush();code=[];i+=1
        while i<len(lines) and not lines[i].startswith('```'):code.append(lines[i]);i+=1
        parts.append('<pre><code>'+html.escape('\n'.join(code))+'</code></pre>');i+=1;continue
    if s.startswith('# '):
        flush();parts.append('<h1>'+inline(s[2:])+'</h1>');i+=1;continue
    if s.startswith('## '):
        flush();anchor='part-'+str(len(toc)+1);toc.append((anchor,s[3:]));
        parts.append('<h2 id="'+anchor+'">'+inline(s[3:])+'</h2>');i+=1;continue
    if s.startswith('|'):
        flush();rows=[]
        while i<len(lines) and lines[i].startswith('|'):
            cells=[c.strip() for c in lines[i].strip().strip('|').split('|')]
            if not all(re.fullmatch(r':?-+:?',c.replace(' ','')) for c in cells):rows.append(cells)
            i+=1
        parts.append('<div class="table-wrap"><table><thead><tr>'+''.join('<th>'+inline(c)+'</th>' for c in rows[0])+'</tr></thead><tbody>')
        for row in rows[1:]:parts.append('<tr>'+''.join('<td>'+inline(c)+'</td>' for c in row)+'</tr>')
        parts.append('</tbody></table></div>');continue
    image=re.fullmatch(r'!\[([^\]]*)\]\(([^)]+)\)',s)
    if image:
        flush();file=ROOT/'docs'/image[2];data=base64.b64encode(file.read_bytes()).decode()
        caption=' · Illustration, not a device screenshot' if english else ' · 示意图，非真机截图'
        parts.append('<figure><img alt="'+html.escape(image[1])+'" src="data:image/png;base64,'+data+'"><figcaption>'+inline(image[1])+caption+'</figcaption></figure>');i+=1;continue
    item=re.match(r'^(\d+)\.\s+(.*)$',s)
    if item:
        flush();parts.append('<ol start="'+item[1]+'">')
        while i<len(lines):
            item=re.match(r'^(\d+)\.\s+(.*)$',lines[i])
            if not item:break
            parts.append('<li>'+inline(item[2])+'</li>');i+=1
        parts.append('</ol>');continue
    if s.startswith('- '):
        flush();parts.append('<ul>')
        while i<len(lines) and lines[i].startswith('- '):
            parts.append('<li>'+inline(lines[i][2:])+'</li>');i+=1
        parts.append('</ul>');continue
    paragraph.append(s);i+=1
flush()
css='''*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:#eef2f0;color:#21332a;font-family:"Microsoft YaHei","PingFang SC",sans-serif;line-height:1.85}main{max-width:1120px;margin:28px auto;background:white;border-radius:18px;padding:35px 42px;box-shadow:0 8px 30px #21332a12}h1{font-size:30px;line-height:1.4;margin:0 0 25px}h2{font-size:22px;border-top:1px solid #d7e2db;padding-top:26px;margin-top:40px;scroll-margin-top:18px}p,li{font-size:16px}li{padding:3px 0}nav{background:#edf6ef;border-radius:12px;padding:18px 24px;margin:24px 0}nav a{display:inline-block;margin:3px 16px 3px 0;font-size:14px}a{color:#16653d;text-decoration:none}a:hover{text-decoration:underline}.table-wrap{overflow-x:auto}table{border-collapse:collapse;min-width:480px;width:100%;font-size:15px}th,td{text-align:left;border:1px solid #d6e2d9;padding:10px 12px;vertical-align:top}th{background:#edf6ef}tr:nth-child(even){background:#f8faf9}pre{background:#172b20;color:#e6f8eb;padding:16px;border-radius:10px;overflow:auto;line-height:1.55}code{font-family:Consolas,monospace;font-size:14px}figure{margin:26px 0}img{width:100%;height:auto;border-radius:12px}figcaption{text-align:center;color:#607568;font-size:13px}footer{border-top:1px solid #d6e2d9;margin-top:35px;padding-top:18px;color:#607568;font-size:13px}@media(max-width:700px){main{margin:0;border-radius:0;padding:24px 18px}h1{font-size:25px}h2{font-size:21px}nav a{display:block}}@media print{body{background:white}main{box-shadow:none;padding:0;margin:0;max-width:none}nav{display:none}h2{break-after:avoid}table,figure,pre{break-inside:avoid}a{color:inherit}}'''
nav='<nav><strong>'+('Contents' if english else '目录')+'</strong><br>'+''.join('<a href="#'+anchor+'">'+inline(title)+'</a>' for anchor,title in toc)+'</nav>'
# Put navigation after the document title.
parts.insert(1,nav)
title='Garmin Badminton Score v0.9.0 — User Guide' if english else '羽毛球计分器 v0.9.0 操作指南'
footer='v0.9.0 · Illustrations are not native screenshots. See the project validation report.' if english else 'v0.9.0 · 本文图片为设计示意；验证范围请参阅项目验证报告。'
page='<!doctype html><html lang="'+('en' if english else 'zh-CN')+'"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>'+title+'</title><style>'+css+'</style></head><body><main>'+''.join(parts)+'<footer>'+footer+'</footer></main></body></html>'
out=ROOT/f'docs/USER_GUIDE_{lang}.html';out.write_text(page)
print(f'{out}: {len(toc)} sections, 2 embedded PNGs, {out.stat().st_size:,} bytes')
