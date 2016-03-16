
#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (weak, nonatomic) IBOutlet UILabel *label;

- (IBAction)logout:(id)sender;
- (IBAction)loginWithFacebook:(id)sender;

@end

