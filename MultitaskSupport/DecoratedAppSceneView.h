#import "FoundationPrivate.h"
#import "DecoratedFloatingView.h"
#import "AppSceneViewController.h"

API_AVAILABLE(ios(16.0))
@interface DecoratedAppSceneView : DecoratedFloatingView<AppSceneViewDelegate>
- (instancetype)initWithExtension:(NSExtension *)extension identifier:(NSUUID *)identifier windowName:(NSString*)windowName dataUUID:(NSString*)dataUUID;
@end

