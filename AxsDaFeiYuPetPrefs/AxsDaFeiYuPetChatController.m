#import "AxsDaFeiYuPetChatController.h"
#import "AxsDaFeiYuPetPreferences.h"
#import <Security/Security.h>

static NSDictionary *axs_dafeiyupet_keyQuery(void) {
    return @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
             (__bridge id)kSecAttrService:@"com.axs.dafeiyupet.ai",(__bridge id)kSecAttrAccount:@"provider"};
}
@interface AxsDaFeiYuPetChatController ()
@property(nonatomic,strong) UITextView *axs_dafeiyupet_input,*axs_dafeiyupet_reply;
@property(nonatomic,strong) UILabel *axs_dafeiyupet_status;
@property(nonatomic,strong) NSURLSession *axs_dafeiyupet_session;
@property(nonatomic,strong) NSURLSessionDataTask *axs_dafeiyupet_task;
@property(nonatomic,strong) NSMutableData *axs_dafeiyupet_data;
@property(nonatomic) BOOL axs_dafeiyupet_httpOK;
@end
@implementation AxsDaFeiYuPetChatController
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=@"大肥鱼 · 原生聊天"; self.view.backgroundColor=UIColor.systemBackgroundColor;
    UIStackView *stack=[UIStackView new]; stack.axis=UILayoutConstraintAxisVertical; stack.spacing=12;
    stack.translatesAutoresizingMaskIntoConstraints=NO; [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [stack.bottomAnchor constraintLessThanOrEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor constant:-8]]];
    UILabel *note=[UILabel new]; note.numberOfLines=0; note.font=[UIFont systemFontOfSize:13];
    note.text=@"仅发送你主动输入的文字给设置中的 HTTPS 服务。无历史、无录音、无屏幕读取；离开本页立即取消。Key 仅存本机 Keychain。"; [stack addArrangedSubview:note];
    UIButton *key=[UIButton buttonWithType:UIButtonTypeSystem]; [key setTitle:@"设置 / 删除 API Key" forState:UIControlStateNormal];
    [key addTarget:self action:@selector(axs_dafeiyupet_key) forControlEvents:UIControlEventTouchUpInside]; [stack addArrangedSubview:key];
    self.axs_dafeiyupet_input=[UITextView new]; self.axs_dafeiyupet_input.delegate=self;
    self.axs_dafeiyupet_input.font=[UIFont systemFontOfSize:17]; self.axs_dafeiyupet_input.backgroundColor=UIColor.secondarySystemBackgroundColor;
    [self.axs_dafeiyupet_input.heightAnchor constraintEqualToConstant:100].active=YES; [stack addArrangedSubview:self.axs_dafeiyupet_input];
    UIStackView *buttons=[UIStackView new]; buttons.distribution=UIStackViewDistributionFillEqually;
    UIButton *send=[UIButton buttonWithType:UIButtonTypeSystem]; [send setTitle:@"发送（≤2048字符）" forState:UIControlStateNormal];
    [send addTarget:self action:@selector(axs_dafeiyupet_send) forControlEvents:UIControlEventTouchUpInside]; [buttons addArrangedSubview:send];
    UIButton *cancel=[UIButton buttonWithType:UIButtonTypeSystem]; [cancel setTitle:@"取消" forState:UIControlStateNormal];
    [cancel addTarget:self action:@selector(axs_dafeiyupet_cancel) forControlEvents:UIControlEventTouchUpInside]; [buttons addArrangedSubview:cancel]; [stack addArrangedSubview:buttons];
    self.axs_dafeiyupet_status=[UILabel new]; self.axs_dafeiyupet_status.font=[UIFont systemFontOfSize:13]; [stack addArrangedSubview:self.axs_dafeiyupet_status];
    self.axs_dafeiyupet_reply=[UITextView new]; self.axs_dafeiyupet_reply.editable=NO; self.axs_dafeiyupet_reply.font=[UIFont systemFontOfSize:16];
    [self.axs_dafeiyupet_reply.heightAnchor constraintEqualToConstant:160].active=YES; [stack addArrangedSubview:self.axs_dafeiyupet_reply];
}
- (void)viewDidDisappear:(BOOL)animated { [super viewDidDisappear:animated]; [self axs_dafeiyupet_cancel]; self.axs_dafeiyupet_input.text=@""; self.axs_dafeiyupet_reply.text=@""; }
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    return textView.text.length-range.length+text.length<=2048;
}
- (void)axs_dafeiyupet_key {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"API Key" message:@"输入保存在本机 Keychain；空值保存会删除。不会显示已存密钥。" preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *f){f.secureTextEntry=YES; f.autocorrectionType=UITextAutocorrectionTypeNo;}];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        NSString *key=a.textFields.firstObject.text ?: @"";
        if(key.length>4096) { self.axs_dafeiyupet_status.text=@"Key过长，未保存"; return; }
        NSMutableDictionary *q=[axs_dafeiyupet_keyQuery() mutableCopy]; OSStatus status;
        if(!key.length) status=SecItemDelete((__bridge CFDictionaryRef)q);
        else {
            NSDictionary *attrs=@{(__bridge id)kSecValueData:[key dataUsingEncoding:NSUTF8StringEncoding],(__bridge id)kSecAttrAccessible:(__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly};
            status=SecItemUpdate((__bridge CFDictionaryRef)q,(__bridge CFDictionaryRef)attrs);
            if(status==errSecItemNotFound) { [q addEntriesFromDictionary:attrs]; status=SecItemAdd((__bridge CFDictionaryRef)q,NULL); }
        }
        a.textFields.firstObject.text=@"";
        self.axs_dafeiyupet_status.text=(status==errSecSuccess||(!key.length&&status==errSecItemNotFound))?@"Key 已更新":@"Keychain失败；不降级明文存储";
    }]]; [self presentViewController:a animated:YES completion:nil];
}
- (void)axs_dafeiyupet_cancel {
    [self.axs_dafeiyupet_task cancel]; self.axs_dafeiyupet_task=nil;
    [self.axs_dafeiyupet_session invalidateAndCancel]; self.axs_dafeiyupet_session=nil;
    self.axs_dafeiyupet_data=nil; self.axs_dafeiyupet_status.text=@"已取消 / 就绪";
}
- (void)axs_dafeiyupet_send {
    [self axs_dafeiyupet_cancel]; [self.view endEditing:YES];
    NSDictionary *cfg=axs_dafeiyupet_readPreferences();
    NSString *base=[cfg[@"aiURL"] isKindOfClass:NSString.class]?cfg[@"aiURL"]:@"https://api.openai.com/v1";
    NSString *model=[cfg[@"aiModel"] isKindOfClass:NSString.class]?cfg[@"aiModel"]:@"gpt-4o-mini";
    NSURLComponents *c=[NSURLComponents componentsWithString:base];
    if(![c.scheme.lowercaseString isEqual:@"https"] || !c.host.length || !c.URL || base.length>2048 || c.user || c.password || c.query || c.fragment || !model.length || model.length>128) { self.axs_dafeiyupet_status.text=@"请配置合法HTTPS Base URL与模型"; return; }
    NSString *text=self.axs_dafeiyupet_input.text;
    if(!text.length || text.length>2048) { self.axs_dafeiyupet_status.text=@"输入须为1–2048字符"; return; }
    while([c.path hasSuffix:@"/"]) c.path=[c.path substringToIndex:c.path.length-1];
    c.path=[c.path stringByAppendingString:@"/chat/completions"];
    NSMutableDictionary *q=[axs_dafeiyupet_keyQuery() mutableCopy]; q[(__bridge id)kSecReturnData]=@YES;
    CFTypeRef value=NULL; OSStatus status=SecItemCopyMatching((__bridge CFDictionaryRef)q,&value);
    NSData *secret=CFBridgingRelease(value);
    NSString *key=status==errSecSuccess?[[NSString alloc] initWithData:secret encoding:NSUTF8StringEncoding]:nil;
    if(!key.length || [key rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location!=NSNotFound) { self.axs_dafeiyupet_status.text=@"请先保存有效API Key"; return; }
    NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:c.URL]; r.HTTPMethod=@"POST"; r.timeoutInterval=30;
    [r setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [r setValue:[@"Bearer " stringByAppendingString:key] forHTTPHeaderField:@"Authorization"];
    r.HTTPBody=[NSJSONSerialization dataWithJSONObject:@{@"model":model,@"messages":@[@{@"role":@"system",@"content":@"你是友善简短的大肥鱼桌宠。"},@{@"role":@"user",@"content":text}],@"max_tokens":@256,@"stream":@NO} options:0 error:nil];
    NSURLSessionConfiguration *conf=NSURLSessionConfiguration.ephemeralSessionConfiguration;
    conf.timeoutIntervalForRequest=30; conf.timeoutIntervalForResource=35; conf.URLCache=nil; conf.HTTPCookieStorage=nil;
    self.axs_dafeiyupet_session=[NSURLSession sessionWithConfiguration:conf delegate:self delegateQueue:NSOperationQueue.mainQueue];
    self.axs_dafeiyupet_data=[NSMutableData new]; self.axs_dafeiyupet_httpOK=NO;
    self.axs_dafeiyupet_task=[self.axs_dafeiyupet_session dataTaskWithRequest:r];
    self.axs_dafeiyupet_status.text=@"请求中（可取消，最长35秒）"; [self.axs_dafeiyupet_task resume];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler {
    completionHandler(nil); // Never forward Authorization to a redirect target.
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    if(task!=self.axs_dafeiyupet_task) { completionHandler(NSURLSessionResponseCancel); return; }
    self.axs_dafeiyupet_httpOK=[response isKindOfClass:NSHTTPURLResponse.class] && ((NSHTTPURLResponse *)response).statusCode==200 && response.expectedContentLength<=65536;
    completionHandler(self.axs_dafeiyupet_httpOK?NSURLSessionResponseAllow:NSURLSessionResponseCancel);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    if(task!=self.axs_dafeiyupet_task) return;
    if(self.axs_dafeiyupet_data.length+data.length>65536) { self.axs_dafeiyupet_httpOK=NO; [task cancel]; return; }
    [self.axs_dafeiyupet_data appendData:data];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if(task!=self.axs_dafeiyupet_task) return;
    if(!error && self.axs_dafeiyupet_httpOK) {
        id json=[NSJSONSerialization JSONObjectWithData:self.axs_dafeiyupet_data options:0 error:nil];
        NSArray *choices=[json isKindOfClass:NSDictionary.class]?json[@"choices"]:nil;
        id first=[choices isKindOfClass:NSArray.class]?choices.firstObject:nil;
        id message=[first isKindOfClass:NSDictionary.class]?first[@"message"]:nil;
        id answer=[message isKindOfClass:NSDictionary.class]?message[@"content"]:nil;
        if([answer isKindOfClass:NSString.class]) {
            self.axs_dafeiyupet_reply.text=[answer substringToIndex:MIN([answer length],4096)];
            self.axs_dafeiyupet_status.text=@"完成 · 不保存历史";
        } else self.axs_dafeiyupet_status.text=@"服务响应格式不兼容";
    } else self.axs_dafeiyupet_status.text=@"请求失败、超时或响应超限；未记录服务详情";
    self.axs_dafeiyupet_task=nil; self.axs_dafeiyupet_data=nil;
    [self.axs_dafeiyupet_session finishTasksAndInvalidate]; self.axs_dafeiyupet_session=nil;
}
@end
