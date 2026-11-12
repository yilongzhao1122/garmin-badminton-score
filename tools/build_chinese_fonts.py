"""Create renamed, OFL-licensed 1-bit BMFont subsets of UI string literals.
Requires Pillow + fontTools and the source Noto Sans CJK Bold TTC at --font.
Prebuilt FNT/PNG files are included; users do not need this tool to compile.
"""
from pathlib import Path
from PIL import Image, ImageFont, ImageDraw
from fontTools.ttLib import TTCollection
import re,json,math,argparse
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--font',default='/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc');parser.add_argument('--index',type=int,default=2);args=parser.parse_args()
chars=set(chr(c) for c in range(32,127))
for p in (ROOT/'source').glob('*.mc'):
    for m in re.finditer(r'"(?:\\.|[^"\\])*"',p.read_text()):
        for ch in json.loads(m[0]):
            if ch.isprintable():chars.add(ch)
for p in (ROOT/'resources/strings').glob('*.xml'):
    for text in re.findall(r'>([^<>]+)<',p.read_text()):chars.update(c for c in text if c.isprintable())
chars=sorted(chars,key=ord)
out=ROOT/'resources/fonts';out.mkdir(exist_ok=True)
metrics={}
for size,line_height,base,name,key in [(16,22,17,'cn16','31'),(19,26,20,'cn19','32')]:
    f=ImageFont.truetype(args.font,size,index=args.index)
    cell=size+4;columns=256//cell;rows=math.ceil(len(chars)/columns);height=rows*cell
    atlas=Image.new('RGBA',(256,height),(255,255,255,0));glyphs={};lines=[]
    for i,ch in enumerate(chars):
        left,top,right,bottom=f.getbbox(ch,anchor='ls');w=right-left;h=bottom-top
        advance=round(f.getlength(ch));x=(i%columns)*cell;y=(i//columns)*cell
        assert w<=cell and h<=cell,(ch,w,h,cell)
        assert base+top>=0 and base+bottom<=line_height,(ch,top,bottom,base)
        if w and h:
            mask=Image.new('L',(w,h),0);ImageDraw.Draw(mask).text((-left,-top),ch,font=f,fill=255,anchor='ls')
            mask=mask.point(lambda n:255 if n>=128 else 0)
            ink=Image.new('RGBA',(w,h),(255,255,255,255));ink.putalpha(mask);atlas.paste(ink,(x,y))
        g=dict(x=x,y=y,width=w,height=h,xoffset=left,yoffset=base+top,xadvance=advance)
        glyphs[str(ord(ch))]=g
        lines.append('char id='+str(ord(ch))+' '+' '.join(k+'='+str(v) for k,v in g.items())+' page=0 chnl=15')
    atlas.save(out/(name+'.png'),optimize=True)
    header=[f'info face="BadmintonCN" size={size} bold=1 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1 outline=0',
        f'common lineHeight={line_height} base={base} scaleW=256 scaleH={height} pages=1 packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4',
        f'page id=0 file="{name}.png"',f'chars count={len(chars)}']
    (out/(name+'.fnt')).write_text('\n'.join(header+lines)+'\n')
    metrics[key]=dict(lineHeight=line_height,base=base,size=size,atlas=name+'.png',glyphs=glyphs)
    print(name,len(chars),'glyphs',atlas.size,'1-bit glyph area <=',256*height//8,'bytes before resource conversion')
(ROOT/'design/font_metrics.json').write_text(json.dumps(metrics,ensure_ascii=False))
(out/'fonts.xml').write_text('<fonts>\n  <font id="CnSmall" filename="cn16.fnt" antialias="false"/>\n  <font id="CnMenu" filename="cn19.fnt" antialias="false"/>\n</fonts>\n')
collection=TTCollection(args.font,lazy=True)
font=collection.fonts[args.index]
notices=[]
for record in font['name'].names:
    if record.nameID==0:
        text=record.toUnicode()
        if text not in notices:notices.append(text)
license_source=Path('/usr/share/doc/fonts-noto-cjk/copyright').read_text()
license_text=license_source[license_source.index(' SIL OPEN FONT LICENSE Version 1.1'):].split('\nLicense: GPL-3+',1)[0]
license_text='\n'.join('' if line.strip()=='.' else line[1:] if line.startswith(' ') else line for line in license_text.splitlines())
(ROOT/'FONT_LICENSE.txt').write_text('BadmintonCN bitmap subsets\nDerived from Noto Sans CJK SC Bold, renamed BadmintonCN.\nSource: https://github.com/notofonts/noto-cjk\n\n'+'\n'.join(notices)+'\n'+license_text+'\n')
