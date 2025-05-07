//
//  LiveProcessHooks.m
//  LiveContainer
//
//  Created by Duy Tran on 7/5/25.
//

#import <UIKit/UIKit.h>

@implementation UIWindow(LiveProcessHooks)
// Fix blank screen for apps not using SceneDelegate
- (void)hook_makeKeyAndVisible {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(200 * MSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if(!self.windowScene) {
            self.windowScene = (id)((UIApplication *)[UIApplication performSelector:@selector(sharedApplication)]).connectedScenes.anyObject;
        }
    });
    [self hook_makeKeyAndVisible];
}
@end

void swizzle(Class class, SEL originalAction, SEL swizzledAction);
__attribute__((constructor)) void LiveProcessHooksInit(void) {
    swizzle(UIWindow.class, @selector(makeKeyAndVisible), @selector(hook_makeKeyAndVisible));
}
