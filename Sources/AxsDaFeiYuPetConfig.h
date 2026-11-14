#pragma once

#import <Foundation/Foundation.h>

@interface AxsDaFeiYuPetConfig : NSObject
+ (instancetype)axs_dafeiyupet_shared;
- (BOOL)axs_dafeiyupet_isEnabled;
- (id)axs_dafeiyupet_valueForKey:(NSString *)key defaultValue:(id)defaultValue;
- (void)axs_dafeiyupet_reload;
@end
