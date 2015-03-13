
#import "RootController.h"
#import "LeftSidebarView.h"
#import "MasterViewController.h"

@interface RootController ()
@property LeftSidebarView *sidebar;
@property UIGestureRecognizer *mainViewTapRecognizer;
@property UINavigationController *navigationController;
@property MasterViewController *masterViewController;
@end

@implementation RootController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupSidebar];
}

- (void)setupSidebar {
    const CGFloat width = 250.0;
    _sidebar = [[LeftSidebarView alloc] initWithFrame:CGRectMake(-width, 0, width, self.view.bounds.size.height)];
    _sidebar.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    _sidebar.rootController = self;
    
    [self.view addSubview:_sidebar];
    _mainViewTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideLeftSidebar)];
}

- (void)showLeftSidebar {
    [_sidebar update];
    [UIView animateWithDuration:0.2 animations:^{
        CGAffineTransform translate = CGAffineTransformMakeTranslation(_sidebar.bounds.size.width, 0);
        _navigationController.view.transform = translate;
        _sidebar.transform = translate;
    }];
    [self.view addGestureRecognizer:_mainViewTapRecognizer];
}

- (void)hideLeftSidebar {
    [self.view removeGestureRecognizer:_mainViewTapRecognizer];
    [UIView animateWithDuration:0.2 animations:^{
        _navigationController.view.transform = CGAffineTransformIdentity;
        _sidebar.transform = CGAffineTransformIdentity;
    }];
}

- (void)logout {
    [self hideLeftSidebar];
    [_navigationController popToRootViewControllerAnimated:YES];
    [_masterViewController logout];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    _navigationController = (UINavigationController *)segue.destinationViewController;
    _masterViewController = (MasterViewController *) _navigationController.viewControllers[0];
    _masterViewController.rootController = self;
}



@end
