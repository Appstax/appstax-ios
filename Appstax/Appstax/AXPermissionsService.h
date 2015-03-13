
#import <Foundation/Foundation.h>
#import "AXJsonApiClient.h"

@interface AXPermissionsService : NSObject

- (instancetype)initWithApiClient:(AXJsonApiClient *)apiClient;

- (void)grant:(NSArray *)grants revoke:(NSArray *)revokes objectID:(NSString *)objectID completion:(void(^)(NSError *))completion;

@end
