#import <UIKit/UIKit.h>
#import "AxsDaFeiYuPetConfig.h"
#import "AxsDaFeiYuPetController.h"

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    [[AxsDaFeiYuPetController axs_dafeiyupet_shared] axs_dafeiyupet_start];
}
%end

%ctor {
    @autoreleasepool {
        [AxsDaFeiYuPetConfig axs_dafeiyupet_shared];
    }
}
