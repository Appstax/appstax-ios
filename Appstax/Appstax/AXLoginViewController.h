
#import <UIKit/UIKit.h>
#import "AXUser.h"
#import "AXLoginUIManager.h"

@interface AXLoginViewController : UIViewController
@property (readonly) NSString *username;
@property (readonly) NSString *password;
@property NSString *submitTitle;
@property BOOL goToLoginHidden;

- (instancetype)initWithUIManager:(AXLoginUIManager *)uiManager;
- (void)showError:(NSString *)errorMessage;
- (void)clear;
- (void)setBackgroundView:(UIView *)view;

@end
