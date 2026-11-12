"""Render actual ScoreView mock draw commands with illustrative desktop fonts.
Requires Node-generated design/preview_scenes.json. This is NOT Garmin output.
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'docs/assets'
DATA = json.loads((ROOT / 'design/preview_scenes.json').read_text())
COLORS = {0:'#000000',1:'#ffffff',2:'#00ff00',3:'#aaaaaa',4:'#555555',5:'#ffff00',6:'#ff0000'}
FONT = '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'
BOLD = '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc'
BITMAP_FONTS = json.loads((ROOT / 'design/font_metrics.json').read_text())
ATLASES = {key:Image.open(ROOT / 'resources/fonts' / info['atlas']).convert('RGBA') for key,info in BITMAP_FONTS.items()}

def font(size, bold=False):
    return ImageFont.truetype(BOLD if bold else FONT, size, index=2)

def center(draw, xy, text, size, color='#1d3028', bold=False):
    f=font(size,bold); b=draw.textbbox((0,0),text,font=f)
    draw.text((xy[0]-(b[2]-b[0])/2,xy[1]-(b[3]-b[1])/2-b[1]),text,font=f,fill=color)

def native_scene(name):
    im=Image.new('RGB',(280,280),'black'); d=ImageDraw.Draw(im)
    for c in DATA['scenes'][name]:
        op=c['op']; a=c['args']; color=COLORS[c['color']]
        if op=='clear': d.rectangle((0,0,279,279),fill=COLORS[c['background']])
        elif op=='line': d.line(tuple(a),fill=color,width=1)
        elif op in ('rect','fillRect'):
            x,y,w,h=a; box=(x,y,x+w,y+h)
            d.rectangle(box,outline=color if op=='rect' else None,fill=color if op=='fillRect' else None)
        elif op in ('circle','fillCircle'):
            x,y,r=a; box=(x-r,y-r,x+r,y+r)
            d.ellipse(box,outline=color if op=='circle' else None,fill=color if op=='fillCircle' else None)
        elif op=='text':
            x,y,ft,value,width,height=a
            if str(ft) in BITMAP_FONTS:
                info=BITMAP_FONTS[str(ft)];atlas=ATLASES[str(ft)];pen=round(x-width/2)
                for ch in value:
                    g=info['glyphs'][str(ord(ch))]
                    if g['width'] and g['height']:
                        mask=atlas.crop((g['x'],g['y'],g['x']+g['width'],g['y']+g['height'])).getchannel('A')
                        ink=Image.new('RGB',mask.size,color)
                        im.paste(ink,(pen+g['xoffset'],round(y)+g['yoffset']),mask)
                    pen+=g['xadvance']
                continue
            f=font(max(10,round(height*0.84)),ft in [3,4,5,6]); b=d.textbbox((0,0),value,font=f)
            # Preserve the common font height; fit desktop glyph widths to
            # mock device measurements without shrinking narrow digits.
            glyph=Image.new('RGBA',(max(1,b[2]-b[0]),max(1,b[3]-b[1])),(0,0,0,0))
            ImageDraw.Draw(glyph).text((-b[0],-b[1]),value,font=f,fill=color)
            if glyph.width>width:
                glyph=glyph.resize((max(1,width),glyph.height),Image.Resampling.LANCZOS)
            im.paste(glyph,(round(x-glyph.width/2),round(y+(height-glyph.height)/2)),glyph)
    return im

BG='#edf1f4'

def watch(canvas, center_xy, scene, scale=1.12):
    cx,cy=center_xy; radius=round(145*scale); d=ImageDraw.Draw(canvas)
    for r,col in [(radius+12,'#839087'),(radius+9,'#26332e'),(radius+1,'#121b17')]:
        d.ellipse((cx-r,cy-r,cx+r,cy+r),fill=col)
    image=native_scene(scene).resize((round(280*scale),round(280*scale)),Image.Resampling.NEAREST)
    mask=Image.new('L',image.size,0); ImageDraw.Draw(mask).ellipse((0,0,image.width-1,image.height-1),fill=255)
    canvas.paste(image,(round(cx-image.width/2),round(cy-image.height/2)),mask)
    for number,side,dy in [(1,-1,-71),(2,-1,-16),(3,-1,39),(4,1,-55),(5,1,55)]:
        x=cx+side*(radius+15); y=cy+round(dy*scale)
        d.rounded_rectangle((x-6,y-14,x+6,y+14),4,fill='#59675f')
        center(d,(x+side*20,y),str(number),15,'#4c6257',True)

out=Image.new('RGB',(1380,1250),BG); d=ImageDraw.Draw(out)
d.text((40,24),'羽毛球计分 v0.9.0 · 局末4键闭环与轻量结果动画',font=font(27,True),fill='#193629')
d.text((40,72),'默认选“是”；2/3选择、4确认、5返回。结果动画为代码线条，无图片文件。',font=font(18),fill='#4b6255')
items=[(240,326,'game_over','本局结束，按4继续','保留比分，进入局末选择'),
 (690,326,'round_save','先选择是否保存本局','默认“是”，保存表内比分/用时检查点'),
 (1140,326,'round_next','再选择是否开始下一局','“否”回原比分；“是”设置接发球'),
 (240,886,'result_win','我方获胜：轻量奖杯动画','约2.4秒，也可按4直接继续'),
 (690,886,'result_lose','对方获胜：继续加油','复用同一页面和字体，无额外图像'),
 (1140,886,'match_save','最后选择是否保存比赛','处理后回0:0，可直接开球或新建')]
for x,y,key,title,caption in items:
    watch(out,(x,y),key,1.05)
    center(d,(x,y+204),title,20,bold=True);center(d,(x,y+242),caption,15,color='#4c6257')
d.text((40,1210),'界面示意，非官方模拟器或真机截图；此预览图仅供电脑查看，不作为手表背景加载。',font=font(16),fill='#607568')
path=DEST/'interface.png';out.save(path)

cases=Image.new('RGB',(1120,1230),BG);d=ImageDraw.Draw(cases)
d.text((35,22),'发球区按双方各自面向球网的左右确定',font=font(25,True),fill='#193629')
d.text((35,67),'对方始终在上，我方始终在下；实心绿色标记为发球人。',font=font(17),fill='#4c6257')
for x,y,key,title,caption in [(280,326,'singles_0_0','单打 0:0 / 我方发球','偶数右区：屏幕下半场右侧'),(840,326,'singles_0_1','单打 0:1 / 对方发球','奇数左区：屏幕上半场右侧'),(280,856,'doubles_1_0','双打 1:0 / A1发球','A1在下方左侧，斜对面的B2接球'),(840,856,'doubles_1_1','双打 1:1 / B2发球','B2在上方右侧，斜对面的A1接球')]:
    watch(cases,(x,y),key,1.06);center(d,(x,y+205),title,20,bold=True);center(d,(x,y+241),caption,16,color='#4c6257')
d.text((35,1178),'此图表示发球轮转关系，并非实时定位或按实际长宽比例绘制。',font=font(17),fill='#607568')
cases.save(ROOT/'docs/assets/courts.png')

# Preview images stay outside runtime resources.

print(path)
print(ROOT/'docs/assets/courts.png')
