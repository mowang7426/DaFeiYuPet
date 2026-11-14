#!/usr/bin/env python3
"""Strict deb + Mach-O slices + code-signature + actual packaged alpha audit."""
from pathlib import Path
import subprocess, tempfile, sys, struct, plistlib, hashlib, json
from PIL import Image
from signature_integrity import axs_dafeiyupet_verify_signature
package=Path(sys.argv[1]).resolve(); scheme=sys.argv[2]
def run(*args): return subprocess.check_output(args,text=True).strip()
meta=run('dpkg-deb','-f',str(package)); print(meta)
expected='iphoneos-arm64e' if scheme=='roothide' else 'iphoneos-arm64'
assert f'Architecture: {expected}' in meta and 'Version: 0.1.0' in meta
assert 'Package: com.axs.dafeiyupet' in meta

def slices(path):
    data=path.read_bytes(); magic=struct.unpack_from('>I',data)[0]
    if magic==0xcafebabe:
        n=struct.unpack_from('>I',data,4)[0]
        offsets=[struct.unpack_from('>IIIII',data,8+20*i)[2] for i in range(n)]
    else: offsets=[0]
    result=[]
    for offset in offsets:
        h=struct.unpack_from('<IIIIIIII',data,offset)
        assert h[0]==0xfeedfacf
        cpu,subtype,ncmds=h[1],h[2]&0xffffff,h[4]
        pos=offset+32; signed=False
        for _ in range(ncmds):
            cmd,size=struct.unpack_from('<II',data,pos); assert size>=8
            if cmd==0x1d:
                blob,size2=struct.unpack_from('<II',data,pos+8)
                assert size2>0 and offset+blob+size2<=len(data)
                assert struct.unpack_from('>I',data,offset+blob)[0]==0xfade0cc0
                info=path.parent/'Info.plist'
                info_bytes=info.read_bytes() if info.exists() else None
                print('Verified ldid CodeDirectories',axs_dafeiyupet_verify_signature(data,offset,blob,size2,info_bytes))
                tampered=bytearray(data); tampered[offset+256]^=1
                try:
                    axs_dafeiyupet_verify_signature(tampered,offset,blob,size2,info_bytes)
                except AssertionError: pass
                else: raise AssertionError('Signature verification failed to reject altered code')
                signed=True
            pos+=size
        assert signed,'Missing LC_CODE_SIGNATURE or embedded signature'
        result.append((cpu,subtype))
    assert (0x100000c,2) in result and (0x100000c,0) in result,('arm64 + arm64e slices required',result)
    return result
with tempfile.TemporaryDirectory() as t:
    root=Path(t); subprocess.run(['dpkg-deb','-x',str(package),t],check=True)
    dylibs=list(root.rglob('AxsDaFeiYuPet.dylib')); assert len(dylibs)==1
    binaries=[dylibs[0],*root.rglob('AxsDaFeiYuPetPrefs.bundle/AxsDaFeiYuPetPrefs')]
    assert len(binaries)==2
    for b in binaries:
        print(b.relative_to(root),slices(b))
    plists=list(root.rglob('DynamicLibraries/AxsDaFeiYuPet.plist')); assert len(plists)==1
    assert plistlib.loads(plists[0].read_bytes())['Filter']['Bundles']==['com.apple.springboard']
    manifests=list(root.rglob('AxsDaFeiYuPet/manifest.plist')); assert len(manifests)==1
    manifest=plistlib.loads(manifests[0].read_bytes()); count=0
    for action,durations in manifest.items():
        for i in range(len(durations)):
            im=Image.open(manifests[0].parent/action/f'{i:04d}.png')
            assert im.size==(220,124) and im.getchannel('A').getextrema()==(0,255); count+=1
    assert count==480
    assert list(root.rglob('ARTWORK-NONCOMMERCIAL.md'))
    assert list(root.rglob('PreferenceLoader/Preferences/AxsDaFeiYuPetPrefs.plist'))
    # Rootless package physically owns /var/jb; RootHide uses its relocation-aware toolchain.
    if scheme=='rootless': assert str(dylibs[0].relative_to(root)).startswith('var/jb/')
    print('PASS package:',scheme,'480 alpha frames, preference entry, licenses, signed arm64e slices')
print('SHA256',hashlib.sha256(package.read_bytes()).hexdigest())
