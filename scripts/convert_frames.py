#!/usr/bin/env python3
"""Independent trusted converter: upstream transparent preview GIF -> bounded RGBA PNG sequence.
No repository scripts executed. Pillow coalesces GIF disposal frames before RGBA export.
"""
from pathlib import Path
import argparse, plistlib, hashlib, json
from PIL import Image, ImageSequence
p=argparse.ArgumentParser(); p.add_argument('source'); p.add_argument('--output',default='layout/Library/Application Support/AxsDaFeiYuPet'); a=p.parse_args()
root=Path(a.source); out=Path(a.output); out.mkdir(parents=True,exist_ok=True)
actions={'idle':'daiji-huxi-xiuxian.gif','look':'dongzhangxiwang.gif','tap':'dianji-huiying-yuanqi-huishou.gif','drag':'beishubiao-tuozhuai-xuankong-fankui.gif'}
manifest={}; provenance={}
for action,name in actions.items():
    path=root/name; im=Image.open(path); durations=[]; dest=out/action; dest.mkdir(exist_ok=True)
    for index,frame in enumerate(ImageSequence.Iterator(im)):
        rgba=frame.convert('RGBA'); assert rgba.size==(220,124),rgba.size
        assert rgba.getchannel('A').getextrema()==(0,255),f'Opaque animation rejected: {name}:{index}'
        rgba.save(dest/f'{index:04d}.png',optimize=True)
        durations.append(max(.08,frame.info.get('duration',80)/1000))
    manifest[action]=durations
    provenance[action]={'source':name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'frames':len(durations),'size':[220,124],'alpha':'per-frame verified 0..255; GIF binary alpha, not HEVC'}
(out/'manifest.plist').write_bytes(plistlib.dumps(manifest))
Path('Assets/provenance.json').parent.mkdir(exist_ok=True)
Path('Assets/provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(provenance,ensure_ascii=False))
