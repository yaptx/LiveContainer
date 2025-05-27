#import "DecoratedAppSceneView.h"
#import "UIKitPrivate+MultitaskSupport.h"
#import "LiveContainerSwiftUI-Swift.h"
#import "AppSceneViewController.h"

@interface DecoratedAppSceneView()
@property(nonatomic) AppSceneViewController* appSceneView;
@property(nonatomic) NSString *sceneID;
@property(nonatomic) NSString* dataUUID;
@property(nonatomic) NSString* windowName;
@property(nonatomic) int pid;
@property(nonatomic) bool isPidShown;
@end

@implementation DecoratedAppSceneView
- (instancetype)initWithExtension:(NSExtension *)extension identifier:(NSUUID *)identifier windowName:(NSString*)windowName dataUUID:(NSString*)dataUUID {
    self = [super initWithFrame:CGRectMake(0, 100, 320, 480 + 44)];
    AppSceneViewController* appSceneView = [[AppSceneViewController alloc] initWithExtension:extension frame:CGRectMake(0, 0, self.contentView.bounds.size.width, self.contentView.bounds.size.height) identifier:identifier dataUUID:dataUUID delegate:self];
    self.appSceneView = appSceneView;
    int pid = appSceneView.pid;
    self.dataUUID = dataUUID;
    self.pid = pid;
    NSLog(@"Presenting app scene from PID %d", pid);
    
    self.navigationBar.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    [self.navigationBar.standardAppearance configureWithTransparentBackground];
    self.navigationBar.standardAppearance.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(closeWindow)];
    self.windowName = windowName;
    self.isPidShown = false;
    self.navigationItem.title = windowName;
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(switchAppNameAndPid:)];
    [self.navigationBar addGestureRecognizer:tapGesture];

    [self.contentView insertSubview:appSceneView.view atIndex:0];

    return self;
}

- (void)closeWindow {
    [self.appSceneView closeWindow];
}

- (void)resizeWindow:(UIPanGestureRecognizer*)sender {
    [super resizeWindow:sender];
    [self.appSceneView resizeWindowWithFrame:CGRectMake(0, 0, self.contentView.bounds.size.width, self.contentView.bounds.size.height)] ;
}

- (void)switchAppNameAndPid:(UITapGestureRecognizer*)sender {
    if(self.isPidShown) {
        self.navigationItem.title = self.windowName;
    } else {
        self.navigationItem.title = [NSString stringWithFormat:@"PID: %d", self.pid];
    }
    self.isPidShown = !self.isPidShown;
}

- (void)appDidExit {
    self.layer.masksToBounds = NO;
    [UIView transitionWithView:self duration:0.4 options:UIViewAnimationOptionTransitionCurlUp animations:^{
        self.hidden = YES;
    } completion:^(BOOL b){
        [self removeFromSuperview];
    }];
}
@end
