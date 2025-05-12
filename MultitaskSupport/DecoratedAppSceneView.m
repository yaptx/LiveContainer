#import "DecoratedAppSceneView.h"
#import "UIKitPrivate+MultitaskSupport.h"
#import "LiveContainerSwiftUI-Swift.h"

@interface DecoratedAppSceneView()
@property(nonatomic) _UIScenePresenter *presenter;
@property(nonatomic) UIMutableApplicationSceneSettings *settings;
@property(nonatomic) UIApplicationSceneTransitionContext *transitionContext;
@property(nonatomic) NSString *sceneID;
@property(nonatomic) NSExtension* extension;
@property(nonatomic) NSString* dataUUID;
@property(nonatomic) NSString* windowName;
@property(nonatomic) int pid;
@property(nonatomic) bool isPidShown;
@property(nonatomic) int resizeDebounceToken;
@end

@implementation DecoratedAppSceneView
- (instancetype)initWithExtension:(NSExtension *)extension identifier:(NSUUID *)identifier windowName:(NSString*)windowName dataUUID:(NSString*)dataUUID {
    self = [super initWithFrame:CGRectMake(0, 100, 375, 667 + 44)];
    self.resizeDebounceToken = 0;
    int pid = [extension pidForRequestIdentifier:identifier];
    self.extension = extension;
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
    settings.frame = CGRectMake(0, 0, self.contentView.bounds.size.width, self.contentView.bounds.size.height);
    settings.interfaceOrientation = UIInterfaceOrientationPortrait;
    //settings.interruptionPolicy = 2; // reconnect
    settings.level = 1;
    // it seems some apps don't honor these settings so we don't cover the top of the app
    settings.peripheryInsets = UIEdgeInsetsMake(0, 0, 0, 0);
    settings.persistenceIdentifier = NSUUID.UUID.UUIDString;
    settings.safeAreaInsetsPortrait = UIEdgeInsetsMake(0, 0, 0, 0);
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
    
    self.presenter = [scene.uiPresentationManager createPresenterWithIdentifier:self.sceneID];
    [self.presenter activate];
    
    
    [self.contentView insertSubview:self.presenter.presentationView atIndex:0];
    
    [extension setRequestInterruptionBlock:^(NSUUID *uuid) {
        NSLog(@"Request %@ interrupted.", uuid);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self closeWindow];
        });
        
    }];
    [MultitaskManager registerMultitaskContainerWithContainer:dataUUID];
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
        [self.extension _kill:SIGTERM];
        [MultitaskManager unregisterMultitaskContainerWithContainer:self.dataUUID];
    }];
}

- (void)resizeWindow:(UIPanGestureRecognizer*)sender {
    [super resizeWindow:sender];
    __block int currentDebounceToken = self.resizeDebounceToken + 1;
    self.resizeDebounceToken = currentDebounceToken;
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC));
    dispatch_after(delay, dispatch_get_main_queue(), ^{
        if(currentDebounceToken != self.resizeDebounceToken) {
            return;
        }
        [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
            settings.frame = CGRectMake(0, 0, self.contentView.bounds.size.width, self.contentView.bounds.size.height);
        }];
    });

}

- (void)switchAppNameAndPid:(UITapGestureRecognizer*)sender {
    if(self.isPidShown) {
        self.navigationItem.title = self.windowName;
    } else {
        self.navigationItem.title = [NSString stringWithFormat:@"PID: %d", self.pid];
    }
    self.isPidShown = !self.isPidShown;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
        settings.userInterfaceStyle = self.traitCollection.userInterfaceStyle;
    }];
}
@end
