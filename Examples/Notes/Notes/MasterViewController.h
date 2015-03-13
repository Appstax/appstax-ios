
#import <UIKit/UIKit.h>
#import "RootController.h"

@interface MasterViewController : UITableViewController

@property (weak, nonatomic) IBOutlet UIBarButtonItem *addButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *menuButton;
@property (weak) RootController *rootController;

- (IBAction)pressedMenuButton:(id)sender;

- (void)logout;

@end
