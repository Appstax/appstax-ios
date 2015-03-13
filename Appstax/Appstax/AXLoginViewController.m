
#import "AXLoginViewController.h"
#import "Appstax.h"
#import "AppstaxInternals.h"
#import "AXUserService.h"

@interface AXLoginViewController ()
@property (weak, nonatomic) IBOutlet UITextField *usernameTextField;
@property (weak, nonatomic) IBOutlet UITextField *passwordTextField;
@property (weak, nonatomic) IBOutlet UIButton *submitButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UILabel *errorLabel;
@property (weak) AXLoginUIManager *loginUIManager;
@property (weak, nonatomic) IBOutlet UIButton *goToLoginButton;
@property (weak, nonatomic) IBOutlet UIView *backgroundContainer;
@property (nonatomic) UIView *backgroundView;
@property BOOL viewLoaded;
@end

@implementation AXLoginViewController


- (instancetype)initWithUIManager:(AXLoginUIManager *)uiManager {
    self = [super initWithNibName:@"AXLoginViewController" bundle:[Appstax frameworkBundle]];
    if (self) {
        _loginUIManager = uiManager;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _viewLoaded = YES;
    [_submitButton setTitle:_submitTitle forState:UIControlStateNormal];
    _goToLoginButton.hidden = _goToLoginHidden;
    [self setBackgroundView:_backgroundView];
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == _usernameTextField) {
        [_passwordTextField becomeFirstResponder];
    } else if(textField == _passwordTextField) {
        [textField resignFirstResponder];
        [self pressedSignUpButton:nil];
    }
    return YES;
}

- (IBAction)pressedSignUpButton:(id)sender {
    [self disableInputs];
    [_activityIndicator startAnimating];
    _errorLabel.hidden = YES;
    [_loginUIManager viewControllerDidPressSubmitButton:self];
}

- (IBAction)pressedGoToLoginButton:(id)sender {
    [_loginUIManager viewControllerDidPressGoToLoginButton:self];
}

- (void)setBackgroundView:(UIView *)view {
    if(_backgroundView != nil) {
        [_backgroundView removeFromSuperview];
        _backgroundView = nil;
    }
    _backgroundView = view;
    if(_viewLoaded) {
        _backgroundView.frame = _backgroundContainer.bounds;
        [_backgroundContainer addSubview:_backgroundView];
    }
}

- (void)clear {
    _usernameTextField.text = @"";
    _passwordTextField.text = @"";
    _errorLabel.text = @"";
    [_activityIndicator stopAnimating];
    [self enableInputs];
}

- (void)showError:(NSString *)errorMessage {
    _errorLabel.hidden = NO;
    _errorLabel.text = errorMessage;
    [self enableInputs];
    [_activityIndicator stopAnimating];
}

- (void)disableInputs {
    [self.view endEditing:YES];
    _usernameTextField.enabled = NO;
    _passwordTextField.enabled = NO;
    _submitButton.enabled = NO;
}

- (void)enableInputs {
    _usernameTextField.enabled = YES;
    _passwordTextField.enabled = YES;
    _submitButton.enabled = YES;
}

- (NSString *)username {
    return _usernameTextField.text;
}

- (NSString *)password {
    return _passwordTextField.text;
}

@end
