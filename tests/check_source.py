#!/usr/bin/env python3
from pathlib import Path
import plistlib, json
from PIL import Image
r=Path(__file__).resolve().parents[1]
def text(p): return (r/p).read_text()
f=plistlib.loads((r/'AxsDaFeiYuPet.plist').read_bytes())
assert f['Filter']['Bundles']==['com.apple.springboard']
p=plistlib.loads((r/'AxsDaFeiYuPetPrefs/Resources/AxsDaFeiYuPetRoot.plist').read_bytes())
items={v['key']:v for v in p['items'] if 'key' in v}
assert items['enabled']['default'] is False and items['roam']['default'] is False
assert items['size']['default']==180 and items['opacity']['default']==1
assert json.loads(text('tweak.json'))['minimum_ios']=='15.0'
assert '16.5:15.0' in text('AxsDaFeiYuPetBuild.mk')
s=text('Sources/AxsDaFeiYuPetController.m')
assert 'makeKeyAndVisible]' not in s and 'animationImages' not in s.replace('// At most one decode in flight + one displayed image, never UIImageView.animationImages.','')
assert '[self.axs_dafeiyupet_link invalidate]' in s and 'generation!=' in s and 'if(!allow)' in s
assert 'return NO;' in text('Sources/AxsDaFeiYuPetConfig.m') or ' : NO;' in text('Sources/AxsDaFeiYuPetConfig.m')
chat=text('AxsDaFeiYuPetPrefs/AxsDaFeiYuPetChatController.m')
for token in ('kSecAttrAccessibleWhenUnlockedThisDeviceOnly','ephemeralSessionConfiguration','65536','2048','completionHandler(nil)','invalidateAndCancel','35'):
    assert token in chat,token
for p in list((r/'Sources').glob('*'))+list((r/'AxsDaFeiYuPetPrefs').glob('*.m')):
    assert 'NSLog(' not in p.read_text() and 'os_log(' not in p.read_text()
assets=r/'layout/Library/Application Support/AxsDaFeiYuPet'
manifest=plistlib.loads((assets/'manifest.plist').read_bytes()); count=0
assert set(manifest)=={'idle','look','tap','drag'}
for action,durations in manifest.items():
    assert len(durations)==120
    for i,duration in enumerate(durations):
        assert .08<=duration<=1
        im=Image.open(assets/action/f'{i:04d}.png')
        assert im.size==(220,124) and im.mode=='RGBA'
        assert im.getchannel('A').getextrema()==(0,255); count+=1
workflow=text('.github/workflows/build.yml')
assert 'workflow_dispatch:' in workflow and 'push:' not in workflow and 'release' not in workflow.lower()
assert 'https://github.com/roothide/theos.git' in workflow and 'https://github.com/theos/theos.git' in workflow
print(f'PASS contracts: config, injection, lifecycle, AI bounds, {count} true-alpha frames, manual-only CI')
