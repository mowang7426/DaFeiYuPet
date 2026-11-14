#import "AxsDaFeiYuPetController.h"
#import "AxsDaFeiYuPetConfig.h"
#import "AxsDaFeiYuPetPreferences.h"
#import "AxsDaFeiYuPetPhysics.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <notify.h>

// Checked object-returning zero-argument selectors only; unknown state fails closed.
static id axs_dafeiyupet_object(id obj, NSString *name) {
    SEL s=NSSelectorFromString(name); if(!obj || ![obj respondsToSelector:s]) return nil;
    Method m=class_getInstanceMethod(object_getClass(obj),s);
    if(!m || method_getNumberOfArguments(m)!=2) return nil;
    char *t=method_copyReturnType(m); BOOL ok=t && t[0]=='@'; free(t);
    return ok ? ((id(*)(id,SEL))objc_msgSend)(obj,s) : nil;
}
static BOOL axs_dafeiyupet_locked(void) {
    id m=axs_dafeiyupet_object(NSClassFromString(@"SBLockScreenManager"),@"sharedInstance");
    SEL s=NSSelectorFromString(@"isUILocked");
    if(!m || ![m respondsToSelector:s]) return YES;
    Method method=class_getInstanceMethod([m class],s);
    char *type=method_copyReturnType(method);
    BOOL valid=method_getNumberOfArguments(method)==2 && type && (type[0]=='B'||type[0]=='c'); free(type);
    return !valid || ((BOOL(*)(id,SEL))objc_msgSend)(m,s);
}
@interface AxsDaFeiYuPetWindow : UIWindow
@property(nonatomic,weak) UIView *axs_dafeiyupet_pet;
@end
@implementation AxsDaFeiYuPetWindow
- (BOOL)canBecomeKeyWindow { return NO; }
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)event {
    UIView *pet=self.axs_dafeiyupet_pet;
    if(self.hidden || pet.hidden || !CGRectContainsPoint(pet.frame,p)) return nil;
    // Only the character body catches touches; transparent margins pass through.
    CGPoint q=[pet convertPoint:p fromView:self];
    CGRect body=CGRectInset(pet.bounds,pet.bounds.size.width*.30,pet.bounds.size.height*.05);
    return CGRectContainsPoint(body,q) ? [pet hitTest:q withEvent:event] : nil;
}
@end
@interface AxsDaFeiYuPetController () {
    AxsDaFeiYuPetBody _axs_dafeiyupet_body;
    int _axs_dafeiyupet_lockToken;
}
@property(nonatomic,strong) AxsDaFeiYuPetWindow *axs_dafeiyupet_window;
@property(nonatomic,strong) UIImageView *axs_dafeiyupet_pet;
@property(nonatomic,strong) UILabel *axs_dafeiyupet_bubble;
@property(nonatomic,strong) CADisplayLink *axs_dafeiyupet_link;
@property(nonatomic,strong) dispatch_source_t axs_dafeiyupet_watch;
@property(nonatomic,strong) dispatch_queue_t axs_dafeiyupet_decodeQueue;
@property(nonatomic,copy) NSDictionary *axs_dafeiyupet_manifest;
@property(nonatomic,copy) NSString *axs_dafeiyupet_action;
@property(nonatomic) NSUInteger axs_dafeiyupet_frame, axs_dafeiyupet_generation;
@property(nonatomic) BOOL axs_dafeiyupet_loading, axs_dafeiyupet_dragging, axs_dafeiyupet_flying;
@property(nonatomic) CFTimeInterval axs_dafeiyupet_last, axs_dafeiyupet_frameTime, axs_dafeiyupet_idleTime, axs_dafeiyupet_bubbleUntil;
@property(nonatomic) double axs_dafeiyupet_reset;
@end
@implementation AxsDaFeiYuPetController
+ (instancetype)axs_dafeiyupet_shared { static id instance; static dispatch_once_t once; dispatch_once(&once,^{instance=[self new];}); return instance; }
- (void)axs_dafeiyupet_start {
    self.axs_dafeiyupet_decodeQueue=dispatch_queue_create("com.axs.dafeiyupet.frames",DISPATCH_QUEUE_SERIAL);
    NSString *p=axs_dafeiyupet_resourcePath(@"/Library/Application Support/AxsDaFeiYuPet/manifest.plist");
    self.axs_dafeiyupet_manifest=[NSDictionary dictionaryWithContentsOfFile:p];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(axs_dafeiyupet_refresh) name:AxsDaFeiYuPetPreferencesChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(axs_dafeiyupet_refresh) name:UIApplicationDidBecomeActiveNotification object:nil];
    __weak typeof(self) weakSelf=self;
    notify_register_dispatch("com.apple.springboard.lockstate",&_axs_dafeiyupet_lockToken,dispatch_get_main_queue(),^(int token){
        [weakSelf axs_dafeiyupet_destroy];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/5),dispatch_get_main_queue(),^{ [weakSelf axs_dafeiyupet_refresh]; });
    });
    [self axs_dafeiyupet_refresh];
}
- (double)axs_dafeiyupet_number:(NSString *)key fallback:(double)fallback low:(double)low high:(double)high {
    id v=[[AxsDaFeiYuPetConfig axs_dafeiyupet_shared] axs_dafeiyupet_valueForKey:key defaultValue:@(fallback)];
    return axs_dafeiyupet_clamp([v isKindOfClass:NSNumber.class]?[v doubleValue]:fallback,low,high);
}
- (void)axs_dafeiyupet_refresh {
    if(![[AxsDaFeiYuPetConfig axs_dafeiyupet_shared] axs_dafeiyupet_isEnabled]) {
        if(self.axs_dafeiyupet_watch) { dispatch_source_cancel(self.axs_dafeiyupet_watch); self.axs_dafeiyupet_watch=nil; }
        [self axs_dafeiyupet_destroy]; return;
    }
    if(!self.axs_dafeiyupet_watch) {
        self.axs_dafeiyupet_watch=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_get_main_queue());
        dispatch_source_set_timer(self.axs_dafeiyupet_watch,DISPATCH_TIME_NOW,NSEC_PER_SEC/2,NSEC_PER_SEC/10);
        __weak typeof(self) weakSelf=self;
        dispatch_source_set_event_handler(self.axs_dafeiyupet_watch,^{[weakSelf axs_dafeiyupet_visibility];});
        dispatch_resume(self.axs_dafeiyupet_watch);
    }
    [self axs_dafeiyupet_visibility];
}
- (void)axs_dafeiyupet_visibility {
    BOOL locked=axs_dafeiyupet_locked();
    NSInteger scope=(NSInteger)[self axs_dafeiyupet_number:@"scope" fallback:0 low:0 high:1];
    BOOL allow=!locked; // Lock-screen content is deliberately never shown in preview.
    if(scope==1) {
        id app=axs_dafeiyupet_object(UIApplication.sharedApplication,@"_accessibilityFrontMostApplication");
        NSString *bid=axs_dafeiyupet_object(app,@"bundleIdentifier");
        BOOL selectorKnown=[UIApplication.sharedApplication respondsToSelector:NSSelectorFromString(@"_accessibilityFrontMostApplication")];
        allow=allow && selectorKnown && (!app || [bid isEqual:@"com.apple.springboard"]);
    }
    if(!allow) { [self axs_dafeiyupet_destroy]; return; }
    if(!self.axs_dafeiyupet_window) [self axs_dafeiyupet_create];
    UIWindow *w=self.axs_dafeiyupet_window;
    if(!CGRectEqualToRect(w.frame,UIScreen.mainScreen.bounds)) { w.frame=UIScreen.mainScreen.bounds; [self axs_dafeiyupet_home]; }
    CGFloat size=[self axs_dafeiyupet_number:@"size" fallback:180 low:100 high:300];
    self.axs_dafeiyupet_pet.bounds=CGRectMake(0,0,size,size*124/220);
    self.axs_dafeiyupet_pet.alpha=[self axs_dafeiyupet_number:@"opacity" fallback:1 low:.2 high:1];
    double reset=[self axs_dafeiyupet_number:@"resetToken" fallback:0 low:0 high:1e12];
    if(reset!=self.axs_dafeiyupet_reset) { self.axs_dafeiyupet_reset=reset; [self axs_dafeiyupet_home]; }
    [self axs_dafeiyupet_place];
}
- (void)axs_dafeiyupet_create {
    AxsDaFeiYuPetWindow *w=[[AxsDaFeiYuPetWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    w.windowLevel=UIWindowLevelAlert+1; w.backgroundColor=UIColor.clearColor;
    UIViewController *vc=[UIViewController new]; vc.view.backgroundColor=UIColor.clearColor; w.rootViewController=vc;
    UIImageView *pet=[[UIImageView alloc] initWithFrame:CGRectMake(0,0,180,180.*124/220)];
    pet.userInteractionEnabled=YES; pet.contentMode=UIViewContentModeScaleAspectFit;
    [vc.view addSubview:pet]; w.axs_dafeiyupet_pet=pet;
    UILabel *bubble=[UILabel new]; bubble.numberOfLines=3; bubble.font=[UIFont systemFontOfSize:13];
    bubble.textAlignment=NSTextAlignmentCenter; bubble.backgroundColor=[UIColor colorWithWhite:1 alpha:.92];
    bubble.textColor=UIColor.blackColor; bubble.layer.cornerRadius=10; bubble.clipsToBounds=YES; bubble.hidden=YES; bubble.userInteractionEnabled=NO;
    [vc.view addSubview:bubble];
    self.axs_dafeiyupet_window=w; self.axs_dafeiyupet_pet=pet; self.axs_dafeiyupet_bubble=bubble;
    [pet addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(axs_dafeiyupet_tap:)]];
    [pet addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(axs_dafeiyupet_pan:)]];
    [self axs_dafeiyupet_home]; [self axs_dafeiyupet_action:@"idle"];
    // Never makeKeyAndVisible: SpringBoard's keyboard/focus ownership remains untouched.
    w.hidden=NO;
    self.axs_dafeiyupet_link=[CADisplayLink displayLinkWithTarget:self selector:@selector(axs_dafeiyupet_tick:)];
    self.axs_dafeiyupet_link.preferredFramesPerSecond=30;
    [self.axs_dafeiyupet_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}
- (void)axs_dafeiyupet_destroy {
    [self.axs_dafeiyupet_link invalidate]; self.axs_dafeiyupet_link=nil;
    self.axs_dafeiyupet_window.hidden=YES; self.axs_dafeiyupet_window=nil;
    self.axs_dafeiyupet_pet.image=nil; self.axs_dafeiyupet_pet=nil; self.axs_dafeiyupet_bubble=nil;
    self.axs_dafeiyupet_generation++; self.axs_dafeiyupet_last=0;
    self.axs_dafeiyupet_dragging=NO; self.axs_dafeiyupet_flying=NO;
}
- (void)axs_dafeiyupet_home {
    CGSize s=self.axs_dafeiyupet_window.bounds.size, p=self.axs_dafeiyupet_pet.bounds.size;
    _axs_dafeiyupet_body=(AxsDaFeiYuPetBody){fmax(0,s.width-p.width-12),fmax(0,s.height-p.height-48),0,0};
    self.axs_dafeiyupet_flying=NO; [self axs_dafeiyupet_place];
}
- (void)axs_dafeiyupet_place {
    CGSize s=self.axs_dafeiyupet_window.bounds.size, p=self.axs_dafeiyupet_pet.bounds.size;
    _axs_dafeiyupet_body.x=axs_dafeiyupet_clamp(_axs_dafeiyupet_body.x,0,fmax(0,s.width-p.width));
    _axs_dafeiyupet_body.y=axs_dafeiyupet_clamp(_axs_dafeiyupet_body.y,44,fmax(44,s.height-p.height-34));
    self.axs_dafeiyupet_pet.frame=(CGRect){{_axs_dafeiyupet_body.x,_axs_dafeiyupet_body.y},p};
    CGFloat x=axs_dafeiyupet_clamp(_axs_dafeiyupet_body.x,8,fmax(8,s.width-188));
    self.axs_dafeiyupet_bubble.frame=CGRectMake(x,fmax(44,_axs_dafeiyupet_body.y-68),180,60);
}
- (void)axs_dafeiyupet_action:(NSString *)name {
    if(!self.axs_dafeiyupet_manifest[name]) name=@"idle";
    self.axs_dafeiyupet_action=name; self.axs_dafeiyupet_frame=0;
    self.axs_dafeiyupet_frameTime=0; self.axs_dafeiyupet_generation++;
}
- (void)axs_dafeiyupet_tap:(UITapGestureRecognizer *)g {
    if(g.state!=UIGestureRecognizerStateEnded) return;
    [self axs_dafeiyupet_action:@"tap"];
    self.axs_dafeiyupet_bubble.text=@"大肥鱼在这里～\n长拖可甩抛；聊天请到设置。";
    self.axs_dafeiyupet_bubble.hidden=NO; self.axs_dafeiyupet_bubbleUntil=CACurrentMediaTime()+4;
}
- (void)axs_dafeiyupet_pan:(UIPanGestureRecognizer *)g {
    if(g.state==UIGestureRecognizerStateBegan) {
        self.axs_dafeiyupet_dragging=YES; self.axs_dafeiyupet_flying=NO;
        [self axs_dafeiyupet_action:@"drag"];
    }
    if(g.state==UIGestureRecognizerStateChanged || g.state==UIGestureRecognizerStateBegan) {
        CGPoint t=[g translationInView:self.axs_dafeiyupet_window];
        _axs_dafeiyupet_body.x+=t.x; _axs_dafeiyupet_body.y+=t.y;
        [g setTranslation:CGPointZero inView:self.axs_dafeiyupet_window]; [self axs_dafeiyupet_place];
    }
    if(g.state==UIGestureRecognizerStateEnded || g.state==UIGestureRecognizerStateCancelled || g.state==UIGestureRecognizerStateFailed) {
        CGPoint v=g.state==UIGestureRecognizerStateEnded?[g velocityInView:self.axs_dafeiyupet_window]:CGPointZero;
        self.axs_dafeiyupet_dragging=NO; self.axs_dafeiyupet_flying=hypot(v.x,v.y)>500;
        _axs_dafeiyupet_body.vx=axs_dafeiyupet_release(v.x); _axs_dafeiyupet_body.vy=axs_dafeiyupet_release(v.y);
        [self axs_dafeiyupet_action:@"idle"];
    }
}
- (void)axs_dafeiyupet_tick:(CADisplayLink *)link {
    CFTimeInterval now=link.timestamp, dt=self.axs_dafeiyupet_last?fmin(.05,now-self.axs_dafeiyupet_last):0;
    self.axs_dafeiyupet_last=now;
    CGSize s=self.axs_dafeiyupet_window.bounds.size,p=self.axs_dafeiyupet_pet.bounds.size;
    if(self.axs_dafeiyupet_flying && !self.axs_dafeiyupet_dragging) {
        // Physics uses a y=0 origin inside the top safe margin.
        _axs_dafeiyupet_body.y-=44;
        axs_dafeiyupet_step(&_axs_dafeiyupet_body,dt,s.width-p.width,s.height-p.height-78);
        _axs_dafeiyupet_body.y+=44;
        if(_axs_dafeiyupet_body.vx==0 && _axs_dafeiyupet_body.vy==0) self.axs_dafeiyupet_flying=NO;
        [self axs_dafeiyupet_place];
    }
    if(now-self.axs_dafeiyupet_idleTime>12 && !self.axs_dafeiyupet_dragging && !self.axs_dafeiyupet_flying) {
        self.axs_dafeiyupet_idleTime=now; [self axs_dafeiyupet_action:@"look"];
        if([self axs_dafeiyupet_number:@"roam" fallback:0 low:0 high:1]>0) {
            _axs_dafeiyupet_body.vx=arc4random_uniform(2)?100:-100; _axs_dafeiyupet_body.vy=-150; self.axs_dafeiyupet_flying=YES;
        }
    }
    if(now>self.axs_dafeiyupet_bubbleUntil) self.axs_dafeiyupet_bubble.hidden=YES;
    if(self.axs_dafeiyupet_loading || now-self.axs_dafeiyupet_frameTime<.08) return;
    NSArray *durations=self.axs_dafeiyupet_manifest[self.axs_dafeiyupet_action];
    if(![durations isKindOfClass:NSArray.class] || durations.count==0) return;
    NSUInteger index=self.axs_dafeiyupet_frame;
    if(index>=durations.count) { [self axs_dafeiyupet_action:self.axs_dafeiyupet_dragging?@"drag":@"idle"]; return; }
    if(now-self.axs_dafeiyupet_frameTime<[durations[index] doubleValue]) return;
    NSString *relative=[NSString stringWithFormat:@"/Library/Application Support/AxsDaFeiYuPet/%@/%04lu.png",self.axs_dafeiyupet_action,(unsigned long)index];
    NSString *path=axs_dafeiyupet_resourcePath(relative);
    NSUInteger generation=self.axs_dafeiyupet_generation;
    self.axs_dafeiyupet_loading=YES;
    // At most one decode in flight + one displayed image, never UIImageView.animationImages.
    dispatch_async(self.axs_dafeiyupet_decodeQueue,^{ @autoreleasepool {
        UIImage *image=[UIImage imageWithContentsOfFile:path];
        if(image) { UIGraphicsBeginImageContextWithOptions(image.size,NO,1); [image drawAtPoint:CGPointZero]; image=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); }
        dispatch_async(dispatch_get_main_queue(),^{
            self.axs_dafeiyupet_loading=NO;
            if(generation!=self.axs_dafeiyupet_generation || !self.axs_dafeiyupet_pet) return;
            self.axs_dafeiyupet_pet.image=image;
            self.axs_dafeiyupet_frame++; self.axs_dafeiyupet_frameTime=CACurrentMediaTime();
        });
    }});
}
@end
