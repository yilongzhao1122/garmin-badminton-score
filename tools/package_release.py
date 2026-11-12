"""Package only public project files; never include signing keys or build output."""
from pathlib import Path
import hashlib, subprocess, zipfile, shutil

ROOT=Path(__file__).resolve().parents[1]
version=(ROOT/'VERSION').read_text().strip()
out=ROOT/'dist';out.mkdir(exist_ok=True)
import sys
for lang in ['cn','en']:
    subprocess.run([sys.executable,str(ROOT/'tools/build_guide.py'),'--lang',lang],check=True)
files=[]
for p in sorted(ROOT.rglob('*')):
    rel=p.relative_to(ROOT)
    if not p.is_file() or any(part in {'.git','dist','bin','__pycache__'} for part in rel.parts):continue
    if p.suffix.lower() in {'.pem','.key','.der','.prg','.iq'} or p.name.startswith(('developer_key','.env')):
        raise SystemExit('Private or compiled file found: '+str(rel))
    files.append((p,rel))
name=f'garmin-badminton-score-v{version}'
archive=out/(name+'-source.zip')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for p,rel in files:z.write(p,Path('garmin-badminton-score')/rel)
guides=[]
for lang in ['cn','en']:
    guide=out/(name+f'-guide-{lang}.html')
    shutil.copyfile(ROOT/f'docs/USER_GUIDE_{lang.upper()}.html',guide)
    guides.append(guide)
checksums=out/'SHA256SUMS.txt'
checksums.write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name+'\n' for p in [archive,*guides]))
with zipfile.ZipFile(archive) as z:assert z.testzip() is None
print(f'Packaged {len(files)} public files. No SDK, signing key or compiled PRG included.')
for p in [archive,*guides,checksums]:print(p.name,p.stat().st_size)
