typedef enum {
    None                                     = 0,
    SBSRelaunchOptionsRestartRenderServer    = (1 << 0),
    SBSRelaunchOptionsSnapshot               = (1 << 1),
    SBSRelaunchOptionsFadeToBlack            = (1 << 2),
} SBSRelaunchOptions;

@interface SBSRelaunchAction : NSObject
+ (SBSRelaunchAction *)actionWithReason:(NSString *)reason options:(SBSRelaunchOptions)options targetURL:(NSURL *)url;
@end