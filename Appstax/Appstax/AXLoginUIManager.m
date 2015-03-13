
#import "AppstaxInternals.h"
#import "AXLoginUIManager.h"
#import "AXLoginViewController.h"

@interface AXLoginUIManager ()
@property AXLoginViewController *signupViewController;
@property AXLoginViewController *loginViewController;
@property (weak) AXUserService *userService;
@property (weak) UIViewController *presentationRoot;
@property UINavigationController *navigationController;
@property (copy) void (^completion)(void);
@end

@implementation AXLoginUIManager

- (instancetype)initWithUserService:(AXUserService *)userService {
    self = [super init];
    if(self) {
        _userService = userService;
        [self setupSignupViewController];
        [self setupLoginViewController];
        [self setupNavigationController];
    }
    return self;
}

- (void)setupNavigationController {
    _navigationController = [[UINavigationController alloc] initWithRootViewController:_signupViewController];
    _navigationController.navigationBarHidden = YES;
}

- (void)setupSignupViewController {
    _signupViewController = [[AXLoginViewController alloc] initWithUIManager:self];
    _signupViewController.submitTitle = @"Sign up";
}

- (void)setupLoginViewController {
    _loginViewController = [[AXLoginViewController alloc] initWithUIManager:self];
    _loginViewController.submitTitle = @"Log in";
    _loginViewController.goToLoginHidden = YES;
}

- (void)setupCustomViews:(void(^)(AXLoginViews *views))loginViews {
    AXLoginViews *views = [[AXLoginViews alloc] initWithSize:_loginViewController.view.bounds.size];
    loginViews(views);
    [_signupViewController setBackgroundView:views.signup];
    [_loginViewController setBackgroundView:views.login];
}

- (void)presentModalLoginWithViews:(void(^)(AXLoginViews *views))loginViews completion:(void(^)(void))completion {
    self.completion = completion;
    dispatch_async(dispatch_get_main_queue(), ^{
        _presentationRoot = [UIApplication sharedApplication].keyWindow.rootViewController;
        if(loginViews) {
            [self setupCustomViews:loginViews];
        }
        [_presentationRoot presentViewController:_navigationController animated:YES completion:nil];
    });
}

- (void)viewControllerDidPressSubmitButton:(UIViewController *)viewController {
    if([viewController isEqual:_signupViewController]) {
        [self signupViewControllerPressedSubmitButton];
    }
    if([viewController isEqual:_loginViewController]) {
        [self loginViewControllerPressedSubmitButton];
    }
}

- (void)viewControllerDidPressGoToLoginButton:(UIViewController *)viewController {
    [_navigationController pushViewController:_loginViewController animated:YES];
}

- (void)signupViewControllerPressedSubmitButton {
    [_userService signupWithUsername:_signupViewController.username
                            password:_signupViewController.password
                          completion:^(AXUser *user, NSError *error) {
                              if(!error) {
                                  [self finish];
                              } else {
                                  [_signupViewController showError:error.userInfo[@"ErrorMessage"]];
                              }
                          }];
}

- (void)loginViewControllerPressedSubmitButton {
    [_userService loginWithUsername:_loginViewController.username
                           password:_loginViewController.password
                         completion:^(AXUser *user, NSError *error) {
                             if(!error) {
                                 [self finish];
                             } else {
                                 [_loginViewController showError:error.userInfo[@"ErrorMessage"]];
                             }
                         }];
}

- (void)finish {
    [_presentationRoot dismissViewControllerAnimated:YES completion:^{
        [_loginViewController clear];
        [_signupViewController clear];
    }];
    _completion();
}

@end
