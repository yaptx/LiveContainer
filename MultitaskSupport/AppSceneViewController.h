//
//  AppSceneView.h
//  LiveContainer
//
//  Created by s s on 2025/5/17.
//
#import "UIKitPrivate+MultitaskSupport.h"
#import "FoundationPrivate.h"
@import UIKit;
@import Foundation;

@protocol AppSceneViewDelegate <NSObject>
- (void)appDidExit;
@end

@interface AppSceneViewController : UIViewController
@property(nonatomic) _UIScenePresenter *presenter;
@property(nonatomic) UIMutableApplicationSceneSettings *settings;
@property(nonatomic) UIApplicationSceneTransitionContext *transitionContext;
@property(nonatomic) NSString *sceneID;
@property(nonatomic) NSExtension* extension;
@property(nonatomic) NSString* dataUUID;
@property(nonatomic) int pid;
@property(nonatomic) id<AppSceneViewDelegate> delegate;

- (instancetype)initWithExtension:(NSExtension *)extension  frame:(CGRect)frame identifier:(NSUUID *)identifier dataUUID:(NSString*)dataUUID delegate:(id<AppSceneViewDelegate>)delegate;

- (void)resizeWindowWithFrame:(CGRect)frame;
- (void)closeWindow;
@end

