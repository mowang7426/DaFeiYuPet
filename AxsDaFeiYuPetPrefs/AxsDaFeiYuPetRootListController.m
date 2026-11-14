#import "AxsDaFeiYuPetRootListController.h"
#import "AxsDaFeiYuPetPreferences.h"
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import "AxsDaFeiYuPetChatController.h"


@interface AxsDaFeiYuPetRootListController ()
@end

@implementation AxsDaFeiYuPetRootListController

- (NSMutableArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *items = [[self loadSpecifiersFromPlistName:@"AxsDaFeiYuPetRoot"
                                                           target:self] mutableCopy];
        [self axs_dafeiyupet_addButton:@"回初始位置" action:@selector(axs_dafeiyupet_reset:) to:items];
        [self axs_dafeiyupet_addButton:@"原生 AI 聊天 / API Key" action:@selector(axs_dafeiyupet_chat:) to:items];
        _specifiers = items;
    }
    return _specifiers;
}

- (void)axs_dafeiyupet_reset:(id)sender {
    PSSpecifier *item=[PSSpecifier preferenceSpecifierNamed:@"reset" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    [item setProperty:@"resetToken" forKey:@"key"];
    [self setPreferenceValue:@([NSDate date].timeIntervalSince1970) specifier:item];
}
- (void)axs_dafeiyupet_chat:(id)sender {
    [self.navigationController pushViewController:[AxsDaFeiYuPetChatController new] animated:YES];
}

- (void)axs_dafeiyupet_addButton:(NSString *)title action:(SEL)action to:(NSMutableArray *)items {
    PSSpecifier *item = [PSSpecifier preferenceSpecifierNamed:title target:self
                          set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    item.buttonAction = action;
    [items addObject:item];
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (key.length == 0) return nil;
    return axs_dafeiyupet_readPreferences()[key] ?: [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (key.length == 0) return;
    NSError *error = nil;
    if (!axs_dafeiyupet_writePreference(key, value, &error)) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置未保存"
            message:error.localizedDescription ?: @"请检查配置文件路径和写入权限。"
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        [self reloadSpecifiers];
    }
}

- (void)axs_dafeiyupet_openURL:(NSURL *)url fallback:(NSURL *)fallback {
    if (!url) return;
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
        if (success) return;
        if (fallback) {
            [self axs_dafeiyupet_openURL:fallback fallback:nil];
        } else {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法打开链接"
                message:@"请确认已安装对应应用。" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }];
}

- (void)axs_dafeiyupet_openRepository:(id)sender {
    NSString *source = @"https://axs66.github.io/pro";
    // Encode the entire URL as a path component, including its own delimiters.
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
                              @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"];
    NSString *encoded = [source stringByAddingPercentEncodingWithAllowedCharacters:allowed];
    NSURL *primary = [NSURL URLWithString:[@"sileo://source/" stringByAppendingString:encoded]];
    [self axs_dafeiyupet_openURL:primary fallback:[NSURL URLWithString:source]];
}

- (void)axs_dafeiyupet_openTelegram:(id)sender {
    [self axs_dafeiyupet_openURL:[NSURL URLWithString:@"tg://resolve?domain=wxfx8"]
                   fallback:[NSURL URLWithString:@"https://t.me/wxfx8"]];
}

- (void)axs_dafeiyupet_openQQ:(id)sender {
    [self axs_dafeiyupet_openURL:[NSURL URLWithString:@"mqqapi://card/show_pslcard?src_type=internal&version=1&uin=678055716&card_type=group&source=qrcode"] fallback:nil];
}


@end
