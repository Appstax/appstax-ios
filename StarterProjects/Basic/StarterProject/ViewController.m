
#import "ViewController.h"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    /*
    [AXUser requireLogin:^(AXUser *user) {
        [self.outputLabel setText:user.username];
    }]; */
}

/*

- (void)createAndSave {
    AXObject *todo = [AXObject create:@"TodoItem"];
    todo[@"content"] = @"Buy milk";
    
    [todo save:^(NSError *error) {
        if(!error) {
            [self loadAndView];
        }
    }];
}

- (void)loadAndView {
    [AXObject findAll:@"TodoItem" completion:^(NSArray *objects, NSError *error) {
        if(!error && objects.count > 0) {
            AXObject *todo = (AXObject *)objects[0];
            NSString *text = [NSString stringWithFormat:@"Remember: %@", todo[@"content"]];
            [self.outputLabel setText:text];
        } else {
            [self.outputLabel setText:@"Nothing to see here!"];
        }
    }];
}

 */

@end
