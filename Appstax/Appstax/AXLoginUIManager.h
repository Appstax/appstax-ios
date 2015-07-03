
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class AXUserService;
@class AXLoginViews;

@interface AXLoginUIManager : NSObject

- (instancetype)initWithUserService:(AXUserService *)userService;
- (void)presentModalLoginWithViews:(void(^)(AXLoginViews *views))loginViews completion:(void(^)(void))completion;
- (void)viewControllerDidPressSubmitButton:(UIViewController *)viewController;
- (void)viewControllerDidPressGoToLoginButton:(UIViewController *)viewController;

@end
