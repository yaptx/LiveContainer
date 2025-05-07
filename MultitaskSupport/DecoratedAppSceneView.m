#import "DecoratedAppSceneView.h"
#import "UIKitPrivate+MultitaskSupport.h"

@interface DecoratedAppSceneView()
@property(nonatomic) _UIScenePresenter *presenter;
@property(nonatomic) UIMutableApplicationSceneSettings *settings;
@property(nonatomic) UIApplicationSceneTransitionContext *transitionContext;
@property(nonatomic) NSString *sceneID;
@end

@implementation DecoratedAppSceneView
- (instancetype)initWithExtension:(NSExtension *)extension identifier:(NSUUID *)identifier {
    self = [super initWithFrame:CGRectMake(0, 100, 400, 400)];
    
    int pid = [extension pidForRequestIdentifier:identifier];
    NSLog(@"Presenting app scene from PID %d", pid);
    
    self.navigationBar.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    [self.navigationBar.standardAppearance configureWithTransparentBackground];
    self.navigationBar.standardAppearance.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(closeWindow)];
    
    self.transitionContext = [UIApplicationSceneTransitionContext new];
    RBSProcessPredicate* predicate = [PrivClass(RBSProcessPredicate) predicateMatchingIdentifier:@(pid)];
    
    FBProcessManager *manager = [PrivClass(FBProcessManager) sharedInstance];
    // At this point, the process is spawned and we're ready to create a scene to render in our app
    RBSProcessHandle* processHandle = [PrivClass(RBSProcessHandle) handleForPredicate:predicate error:nil];
    [manager registerProcessForAuditToken:processHandle.auditToken];
    // NSString *identifier = [NSString stringWithFormat:@"sceneID:%@-%@", bundleID, @"default"];
    self.sceneID = [NSString stringWithFormat:@"sceneID:%@-%@", @"LiveContainerAppProcess", NSUUID.UUID.UUIDString];
    
    FBSMutableSceneDefinition *definition = [PrivClass(FBSMutableSceneDefinition) definition];
    definition.identity = [PrivClass(FBSSceneIdentity) identityForIdentifier:self.sceneID];
    definition.clientIdentity = [PrivClass(FBSSceneClientIdentity) identityForProcessIdentity:processHandle.identity];
    definition.specification = [UIApplicationSceneSpecification specification];
    FBSMutableSceneParameters *parameters = [PrivClass(FBSMutableSceneParameters) parametersForSpecification:definition.specification];
    
    UIMutableApplicationSceneSettings *settings = [UIMutableApplicationSceneSettings new];
    settings.canShowAlerts = YES;
    settings.cornerRadiusConfiguration = [[PrivClass(BSCornerRadiusConfiguration) alloc] initWithTopLeft:self.layer.cornerRadius bottomLeft:self.layer.cornerRadius bottomRight:self.layer.cornerRadius topRight:self.layer.cornerRadius];
    settings.displayConfiguration = UIScreen.mainScreen.displayConfiguration;
    settings.foreground = YES;
    settings.frame = self.bounds;
    settings.interfaceOrientation = UIInterfaceOrientationPortrait;
    //settings.interruptionPolicy = 2; // reconnect
    settings.level = 1;
    settings.peripheryInsets = UIEdgeInsetsMake(self.navigationBar.frame.size.height, 0, 0, 0);
    settings.persistenceIdentifier = NSUUID.UUID.UUIDString;
    settings.safeAreaInsetsPortrait = UIEdgeInsetsMake(self.navigationBar.frame.size.height, 0, 0, 0);
    //settings.statusBarDisabled = 1;
    //settings.previewMaximumSize =
    //settings.deviceOrientationEventsEnabled = YES;
    self.settings = settings;
    parameters.settings = settings;
    
    UIMutableApplicationSceneClientSettings *clientSettings = [UIMutableApplicationSceneClientSettings new];
    clientSettings.interfaceOrientation = UIInterfaceOrientationPortrait;
    clientSettings.statusBarStyle = 0;
    parameters.clientSettings = clientSettings;
    
    FBScene *scene = [[PrivClass(FBSceneManager) sharedInstance] createSceneWithDefinition:definition initialParameters:parameters];
    
    self.navigationItem.title = @"Test name";
    
    self.presenter = [scene.uiPresentationManager createPresenterWithIdentifier:self.sceneID];
    [self.presenter activate];
    [self insertSubview:self.presenter.presentationView atIndex:0];
    return self;
}

- (void)closeWindow {
    self.layer.masksToBounds = NO;
    [UIView transitionWithView:self duration:0.4 options:UIViewAnimationOptionTransitionCurlUp animations:^{
        self.hidden = YES;
    } completion:^(BOOL b){
        [[PrivClass(FBSceneManager) sharedInstance] destroyScene:self.sceneID withTransitionContext:nil];
        if(self.presenter){
            [self.presenter deactivate];
            [self.presenter invalidate];
            self.presenter = nil;
        }
        [self removeFromSuperview];
    }];
}

- (void)resizeWindow:(UIPanGestureRecognizer*)sender {
    [super resizeWindow:sender];
    
    self.settings.frame = self.bounds;
    [self.presenter.scene updateSettings:self.settings withTransitionContext:self.transitionContext completion:nil];
}
@end
