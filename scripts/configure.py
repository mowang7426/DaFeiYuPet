from pathlib import Path
import plistlib
root=Path(__file__).resolve().parents[1]
def choice(label,key,default,titles,values):
    return dict(cell='PSLinkListCell',detail='PSListItemsController',label=label,key=key,defaults='com.axs.dafeiyupet',default=default,validTitles=titles,validValues=values)
items=[dict(cell='PSGroupCell',label='0.1.0 预览',footerText='默认关闭。锁屏始终隐藏；宠物以外触摸穿透。四种透明动作，画质为220×124预览级。'),dict(cell='PSSwitchCell',label='启用大肥鱼',key='enabled',defaults='com.axs.dafeiyupet',default=False),dict(cell='PSSwitchCell',label='自动漫游（可关闭）',key='roam',defaults='com.axs.dafeiyupet',default=False),choice('大小','size',180,['小 120','中 180','大 240','超大 300'],[120,180,240,300]),choice('透明度','opacity',1.0,['100%','80%','60%','40%','20%'],[1.0,.8,.6,.4,.2]),choice('活动范围','scope',0,['主屏幕与前台App（待真机验收）','仅主屏幕'],[0,1]),dict(cell='PSGroupCell',label='AI 聊天 · 仅在设置进程',footerText='聊天页输入文字与API Key；不会夺取SpringBoard keyWindow。Base URL应包含/v1但不含/chat/completions。只接受HTTPS，无重定向。'),dict(cell='PSEditTextCell',label='Base URL',key='aiURL',defaults='com.axs.dafeiyupet',default='https://api.openai.com/v1',placeholder='https://api.openai.com/v1',autoCaps=False,autoCorrection=False),dict(cell='PSEditTextCell',label='模型',key='aiModel',defaults='com.axs.dafeiyupet',default='gpt-4o-mini',autoCaps=False,autoCorrection=False)]
(root/'AxsDaFeiYuPetPrefs/Resources/AxsDaFeiYuPetRoot.plist').write_bytes(plistlib.dumps(dict(title='大肥鱼',items=items),sort_keys=False))
# Retain notices inside the installed package as well as source tree.
doc=root/'layout/usr/share/doc/com.axs.dafeiyupet'; doc.mkdir(parents=True,exist_ok=True)
for p in [root/'LICENSE',*(root/'LICENSES').glob('*')]: (doc/p.name).write_bytes(p.read_bytes())
