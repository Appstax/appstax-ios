
#import <Foundation/Foundation.h>

@class AXApiClient;

@interface AXPermissionsService : NSObject

- (instancetype)initWithApiClient:(AXApiClient *)apiClient;

- (void)grant:(NSArray *)grants revoke:(NSArray *)revokes objectID:(NSString *)objectID completion:(void(^)(NSError *))completion;

@end
