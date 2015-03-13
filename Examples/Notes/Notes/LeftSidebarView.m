
#import "LeftSidebarView.h"
#import "RootController.h"
@import Appstax;

@interface LeftSidebarView ()
@property UIView *view;
@property (weak, nonatomic) IBOutlet UILabel *usernameLabel;
@end

@implementation LeftSidebarView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        _view = [[[NSBundle mainBundle] loadNibNamed:@"LeftSidebarView" owner:self options:nil] objectAtIndex:0];
        [self addSubview:_view];
        _view.frame = self.bounds;
    }
    return self;
}

- (IBAction)pressedLogout:(id)sender {
    NSLog(@"Log out");
    [_rootController logout];
}

- (void)update {
    _usernameLabel.text = [[AXUser currentUser] username];
}

@end
