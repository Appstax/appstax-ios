
#import <Foundation/Foundation.h>
#import "AXJsonApiClient.h"
#import "AXUser.h"

@interface AXUserService : NSObject

@property (readonly, nonatomic) AXUser *currentUser;

- (instancetype)initWithApiClient:(AXJsonApiClient *)apiClient;
- (void)signupWithUsername:(NSString *)username password:(NSString *)password completion:(void(^)(AXUser *user, NSError *error))completion;
- (void)loginWithUsername:(NSString *)username password:(NSString *)password completion:(void(^)(AXUser *user, NSError *error))completion;
- (void)requireLogin:(void(^)(AXUser *))completion withCustomViews:(void(^)(AXLoginViews *views))loginViews;
- (void)logout;

@end
