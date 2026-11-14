"""Verify ldid embedded CodeDirectory integrity, not Apple certificate trust.
macOS codesign rejects ldid's CMS-less flags=0 blobs, a normal jailbreak format.
Check every code page in every CodeDirectory (SHA1 and SHA256) plus special slots.
"""
import struct,hashlib,math

def axs_dafeiyupet_verify_signature(data,base,blob_offset,blob_size,info_plist=None):
    sb=base+blob_offset
    magic,length,count=struct.unpack_from('>III',data,sb)
    assert magic==0xfade0cc0 and 12+8*count<=length<=blob_size
    blobs={}
    for i in range(count):
        typ,rel=struct.unpack_from('>II',data,sb+12+8*i)
        assert rel>=12+8*count and rel+8<=length
        m,size=struct.unpack_from('>II',data,sb+rel); assert size>=8 and rel+size<=length
        blobs[typ]=data[sb+rel:sb+rel+size]
    checked=[]
    for typ,cd in blobs.items():
        if struct.unpack_from('>I',cd)[0]!=0xfade0c02: continue
        magic,size,version,flags,hash_off,ident,special,slots,limit,hash_size,hash_type,platform,page=struct.unpack_from('>9I4B',cd)
        assert limit>0 and limit<=blob_offset and page<=20
        page_size=1<<page if page else limit
        assert slots==math.ceil(limit/page_size)
        assert hash_off-special*hash_size>=0 and hash_off+slots*hash_size<=len(cd)
        assert ident<len(cd) and b'\0' in cd[ident:]
        algorithm={1:'sha1',2:'sha256',3:'sha256',4:'sha384'}[hash_type]
        def digest(raw): return hashlib.new(algorithm,raw).digest()[:hash_size]
        for i in range(slots):
            actual=digest(data[base+i*page_size:base+min((i+1)*page_size,limit)])
            assert actual==cd[hash_off+i*hash_size:hash_off+(i+1)*hash_size],('CodeDirectory page hash mismatch',typ,i)
        for i in range(1,special+1):
            stored=cd[hash_off-i*hash_size:hash_off-(i-1)*hash_size]
            if not any(stored): continue
            raw=info_plist if i==1 else blobs.get(i)
            assert raw is not None,('Missing special signature slot',i)
            assert digest(raw)==stored,('Special slot hash mismatch',i)
        checked.append({'slot':typ,'algorithm':algorithm,'pages':slots,'flags':flags,'identifier':cd[ident:].split(b'\0')[0].decode()})
    assert checked and any(x['algorithm']=='sha256' for x in checked)
    return checked
