
#import "ViewController.h"
@import Appstax;

@interface ViewController ()
@property AXModel *model;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [Appstax setAppKey:@"NkxXMTRibGhEWHBLcg=="];
    
    self.model = [AXModel model];
    [self.model watch:@"todos"];
    [self.model on:@"change" handler:^(AXModelEvent *event) {
        [self.tableView reloadData];
    }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.model[@"todos"] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AXObject *todoItem = [self todoItemAtRow:indexPath.row];
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Cell"];
    cell.textLabel.text = todoItem[@"title"];
    if([todoItem[@"completed"] isEqual:@YES]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    return cell;
}

- (AXObject *)todoItemAtRow:(NSInteger)row {
    return self.model[@"todos"][row];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    
    if(textField.text != nil && textField.text.length > 0) {
        AXObject *todoItem = [AXObject create:@"todos"];
        todoItem[@"title"] = textField.text;
        todoItem[@"completed"] = @NO;
        [todoItem save];
        textField.text = @"";
    }
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [[self todoItemAtRow:indexPath.row] remove];
    }
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    AXObject *todoItem = [self todoItemAtRow:indexPath.row];
    if([todoItem[@"completed"] isEqual:@YES]) {
        todoItem[@"completed"] = @NO;
    } else {
        todoItem[@"completed"] = @YES;
    }
    [todoItem save];
    return NO;
}

@end
