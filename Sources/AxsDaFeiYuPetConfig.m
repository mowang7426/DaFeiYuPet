#import "AxsDaFeiYuPetConfig.h"
#import "AxsDaFeiYuPetPreferences.h"

@interface AxsDaFeiYuPetConfig ()
@property (atomic, copy) NSDictionary *snapshot;
@property (nonatomic, strong) dispatch_queue_t reloadQueue;
@end

static void axs_dafeiyupet_preferencesDidChange(CFNotificationCenterRef center, void *observer,
                                          CFStringRef name, const void *object, CFDictionaryRef info) {
    AxsDaFeiYuPetConfig *config = (__bridge AxsDaFeiYuPetConfig *)observer;
    dispatch_async(config.reloadQueue, ^{
        [config axs_dafeiyupet_reload];
    });
}

@implementation AxsDaFeiYuPetConfig

+ (instancetype)axs_dafeiyupet_shared {
    static AxsDaFeiYuPetConfig *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _reloadQueue = dispatch_queue_create("com.axs.dafeiyupet.preferences", DISPATCH_QUEUE_SERIAL);
        [self axs_dafeiyupet_reload];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge const void *)self, axs_dafeiyupet_preferencesDidChange,
            (__bridge CFStringRef)AxsDaFeiYuPetPreferencesChanged, NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
        // Close the window between the first read and observer registration.
        dispatch_async(_reloadQueue, ^{ [self axs_dafeiyupet_reload]; });
    }
    return self;
}

- (void)axs_dafeiyupet_reload {
    self.snapshot = axs_dafeiyupet_readPreferences();
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:AxsDaFeiYuPetPreferencesChanged object:self];
    });
}

- (id)axs_dafeiyupet_valueForKey:(NSString *)key defaultValue:(id)defaultValue {
    return self.snapshot[key] ?: defaultValue;
}

- (BOOL)axs_dafeiyupet_isEnabled {
    id value = [self axs_dafeiyupet_valueForKey:@"enabled" defaultValue:@(NO)];
    return [value isKindOfClass:[NSNumber class]] ? [value boolValue] : NO;
}

- (void)dealloc {
    CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                            (__bridge const void *)self);
}

@end
