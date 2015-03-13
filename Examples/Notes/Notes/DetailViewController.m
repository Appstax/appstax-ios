
#import "DetailViewController.h"
#import "NoteColors.h"

@interface DetailViewController ()
@end

@implementation DetailViewController

#pragma mark - Managing the detail item

- (void)setNote:(AXObject *)note {
    if (_note != note) {
        _note = note;
        [self setupLoadingView];
        [_note refresh:^(NSError *error) {
            [self setupView];
        }];
    }
}

- (void)setupLoadingView {
    [self setupView];
    self.titleTextField.enabled = NO;
    self.titleTextField.text = @"Loading ...";
    self.contentTextField.editable = NO;
    self.contentTextField.text = @"";
}

- (void)setupView {
    self.titleTextField.enabled = YES;
    self.contentTextField.editable = YES;
    self.titleTextField.textColor = [UIColor whiteColor];
    self.titleTextField.text = self.note[@"Title"];
    self.contentTextField.text = self.note[@"Content"];
    if ([self.titleTextField respondsToSelector:@selector(setAttributedPlaceholder:)]) {
        UIColor *color = [UIColor colorWithWhite:1.0 alpha:0.7];
        self.titleTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:self.titleTextField.placeholder
                                                                                    attributes:@{NSForegroundColorAttributeName: color}];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupView];
    [self registerForKeyboardNotifications];
}

- (void)registerForKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    
}

- (void)keyboardDidShow:(NSNotification *)notification {
    NSDictionary* info = [notification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    _contentTextBottomConstraint.constant = kbSize.height;
}

- (void)keyboardWillHide:(NSNotification *)notification {
    _contentTextBottomConstraint.constant = 0;
}

- (void)viewWillAppear:(BOOL)animated {
    self.navigationController.navigationBar.barTintColor = [NoteColors allColors][[_note[@"ColorIndex"] intValue]];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    self.navigationController.navigationBar.barStyle = UIBarStyleBlackTranslucent;
}

- (void)viewDidAppear:(BOOL)animated {
    if(_note.objectID == nil) {
        [self.titleTextField becomeFirstResponder];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    self.note[@"Title"] = self.titleTextField.text;
    self.note[@"Content"] = self.contentTextField.text;
    [self.note save];
    [self.view endEditing:YES];
}

- (IBAction)didBeginEditingTitle:(id)sender {
    [_colorView show];
}

- (void)colorView:(NoteColorView *)view didSelectIndex:(NSUInteger)index color:(UIColor *)color {
    self.navigationController.navigationBar.barTintColor = color;
    _note[@"ColorIndex"] = @(index);
}

@end
