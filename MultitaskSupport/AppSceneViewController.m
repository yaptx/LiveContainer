//
//  AppSceneView.m
//  LiveContainer
//
//  Created by s s on 2025/5/17.
//
#import "AppSceneViewController.h"
#import "LiveContainerSwiftUI-Swift.h"
#import "../LiveContainerSwiftUI/LCUtils.h"

@implementation AppSceneViewController {
    bool isAppRunning;
    int resizeDebounceToken;
}

- (instancetype)initWithExtension:(NSExtension *)extension frame:(CGRect)frame identifier:(NSUUID *)identifier dataUUID:(NSString*)dataUUID delegate:(id<AppSceneViewDelegate>)delegate{
    self = [super initWithNibName:nil bundle:nil];
    int pid = [extension pidForRequestIdentifier:identifier];
    self.delegate = delegate;
    self.extension = extension;
    self.dataUUID = dataUUID;
    self.pid = pid;
    isAppRunning = true;
    
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
    settings.cornerRadiusConfiguration = [[PrivClass(BSCornerRadiusConfiguration) alloc] initWithTopLeft:self.view.layer.cornerRadius bottomLeft:self.view.layer.cornerRadius bottomRight:self.view.layer.cornerRadius topRight:self.view.layer.cornerRadius];
    settings.displayConfiguration = UIScreen.mainScreen.displayConfiguration;
    settings.foreground = YES;

    settings.deviceOrientation = UIDevice.currentDevice.orientation;
    bool isNativeWindow = [[[NSUserDefaults alloc] initWithSuiteName:[LCUtils appGroupID]] integerForKey:@"LCMultitaskMode" ] == 1;
    if(UIInterfaceOrientationIsLandscape(UIApplication.sharedApplication.statusBarOrientation)) {
        settings.frame = CGRectMake(0, 0, frame.size.height, frame.size.width);
    } else {
        settings.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
    }
    settings.interfaceOrientation = UIApplication.sharedApplication.statusBarOrientation;
    //settings.interruptionPolicy = 2; // reconnect
    settings.level = 1;
    settings.persistenceIdentifier = NSUUID.UUID.UUIDString;
    if(isNativeWindow) {
        UIEdgeInsets defaultInsets = UIApplication.sharedApplication.keyWindow.safeAreaInsets;
        settings.peripheryInsets = defaultInsets;
        settings.safeAreaInsetsPortrait = defaultInsets;
    } else {
        // it seems some apps don't honor these settings so we don't cover the top of the app
        settings.peripheryInsets = UIEdgeInsetsMake(0, 0, 0, 0);
        settings.safeAreaInsetsPortrait = UIEdgeInsetsMake(0, 0, 0, 0);
    }


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
    [self.presenter modifyPresentationContext:^(UIMutableScenePresentationContext *context) {
        context.appearanceStyle = 2;
    }];
    [self.presenter activate];
    [extension setRequestInterruptionBlock:^(NSUUID *uuid) {
        NSLog(@"Request %@ interrupted.", uuid);
        [NSNotificationCenter.defaultCenter removeObserver:self];
        dispatch_async(dispatch_get_main_queue(), ^{
            if(self.delegate) {
                [self.delegate appDidExit];
                [MultitaskManager unregisterMultitaskContainerWithContainer:self.dataUUID];
                self->isAppRunning = false;
                [self closeWindow];
            }
        });
        
    }];
    
    [self.view insertSubview:self.presenter.presentationView atIndex:0];
    [MultitaskManager registerMultitaskContainerWithContainer:dataUUID];
    if(!isNativeWindow) {
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(rotated) name:UIDeviceOrientationDidChangeNotification object:nil];
    }
    return self;
}

- (void)resizeWindowWithFrame:(CGRect)frame {    
    __block int currentDebounceToken = self->resizeDebounceToken + 1;
    self->resizeDebounceToken = currentDebounceToken;
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC));
    dispatch_after(delay, dispatch_get_main_queue(), ^{
        if(currentDebounceToken != self->resizeDebounceToken) {
            return;
        }
        [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
            settings.deviceOrientation = UIDevice.currentDevice.orientation;
            [settings setInterfaceOrientation:UIApplication.sharedApplication.statusBarOrientation];
            if(UIInterfaceOrientationIsLandscape(UIApplication.sharedApplication.statusBarOrientation)) {
                CGRect frame2 = CGRectMake(frame.origin.x, frame.origin.y, frame.size.height, frame.size.width);
                settings.frame = frame2;
            } else {
                settings.frame = frame;
            }
        }];
    });
}

- (void)closeWindow {
    [[PrivClass(FBSceneManager) sharedInstance] destroyScene:self.sceneID withTransitionContext:nil];
    if(self.presenter){
        [self.presenter deactivate];
        [self.presenter invalidate];
        self.presenter = nil;
    }
    if(isAppRunning) {
        [self.extension _kill:SIGTERM];
        NSLog(@"sent sigterm");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.extension _kill:SIGKILL];
        });
    }

}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
        settings.userInterfaceStyle = self.traitCollection.userInterfaceStyle;
    }];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
     } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
         [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
             settings.deviceOrientation = UIDevice.currentDevice.orientation;
             [settings setInterfaceOrientation:UIApplication.sharedApplication.statusBarOrientation];
             if(UIInterfaceOrientationIsLandscape(UIApplication.sharedApplication.statusBarOrientation)) {
                 CGRect frame2 = CGRectMake(0, 0, size.height, size.width);
                 settings.frame = frame2;
             } else {
                 CGRect frame = CGRectMake(0, 0, size.width, size.height);
                 settings.frame = frame;
             }
         }];
     }];
}
- (void)rotated {
    [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
        if(UIDeviceOrientationIsLandscape(settings.deviceOrientation) ^ UIDeviceOrientationIsLandscape(UIDevice.currentDevice.orientation)) {
            settings.frame = CGRectMake(0, 0, settings.frame.size.height, settings.frame.size.width);
        }
        settings.deviceOrientation = UIDevice.currentDevice.orientation;
        [settings setInterfaceOrientation:UIApplication.sharedApplication.statusBarOrientation];
    }];
}

- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
        UIEdgeInsets defaultInsets = UIApplication.sharedApplication.keyWindow.safeAreaInsets;
        settings.peripheryInsets = defaultInsets;
        settings.safeAreaInsetsPortrait = defaultInsets;
    }];

}

@end
 
