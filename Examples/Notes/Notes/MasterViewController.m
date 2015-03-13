
#import "MasterViewController.h"
#import "DetailViewController.h"
#import "MasterTableViewCell.h"
#import "RootController.h"
#import <AppStax/AppStax.h>

@interface MasterViewController ()
@property NSMutableArray *notes;
@end

@implementation MasterViewController

#pragma mark - View Controller / navigation

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"";
    self.addButton.enabled = NO;
    self.tableView.allowsMultipleSelectionDuringEditing = NO;
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = [UIColor whiteColor];
    [self.refreshControl addTarget:self action:@selector(load) forControlEvents:UIControlEventValueChanged];

    [self login];
}

- (void)login {
    [AXUser requireLogin:^(AXUser *user) {
        [self load];
    } withCustomViews:^(AXLoginViews *views) {
        NSArray *nibViews = [[NSBundle mainBundle] loadNibNamed:@"LoginViews" owner:self options:nil];
        views.signup = nibViews[0];
        views.login = nibViews[1];
    }];
}

- (void)logout {
    [AXUser logout];
    [self login];
}

- (void)load {
    [AXObject findAll:@"Notes" completion:^(NSArray *notes, NSError *error) {
        if(error == nil) {
            self.notes = [NSMutableArray arrayWithArray:notes];
            self.addButton.enabled = YES;
            [self.refreshControl endRefreshing];
            [self.tableView reloadData];
        }
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    self.navigationController.navigationBar.barStyle = UIBarStyleDefault;
    self.navigationController.navigationBar.barTintColor = [UIColor whiteColor];
    self.navigationController.navigationBar.tintColor = [UIColor blackColor];
    [self.tableView reloadData];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([[segue identifier] isEqualToString:@"showNote"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        AXObject *note = self.notes[[self noteIndexForRow:indexPath.row]];
        [[segue destinationViewController] setNote:note];
    }
    if([[segue identifier] isEqualToString:@"addNote"]) {
        AXObject *note = [AXObject create:@"Notes"];
        [self.notes addObject:note];
        [[segue destinationViewController] setNote:note];
    }
}

- (NSUInteger)noteIndexForRow:(NSUInteger)row {
    return self.notes.count - row - 1;;
}

- (IBAction)pressedMenuButton:(id)sender {
    [_rootController showLeftSidebar];
}

#pragma mark - Table View

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MasterTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.note = self.notes[[self noteIndexForRow:indexPath.row]];
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.notes.count;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSUInteger noteIndex = [self noteIndexForRow:indexPath.row];
        [self.notes[noteIndex] remove];
        [self.notes removeObjectAtIndex:noteIndex];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

@end
