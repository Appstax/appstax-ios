
#import <UIKit/UIKit.h>
#import "NoteColorView.h"
@import Appstax;

@interface DetailViewController : UIViewController<NoteColorViewDelegate, UITextViewDelegate>

@property (strong, nonatomic) AXObject *note;
@property (weak, nonatomic) IBOutlet UITextField *titleTextField;
@property (weak, nonatomic) IBOutlet UITextView *contentTextField;
@property (weak, nonatomic) IBOutlet NoteColorView *colorView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *contentTextBottomConstraint;
- (IBAction)didBeginEditingTitle:(id)sender;

@end
