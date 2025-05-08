#import "FoundationPrivate.h"
#import "DecoratedFloatingView.h"

@interface DecoratedAppSceneView : DecoratedFloatingView
- (instancetype)initWithExtension:(NSExtension *)extension identifier:(NSUUID *)identifier dataUUID:(NSString*)dataUUID;
@end

