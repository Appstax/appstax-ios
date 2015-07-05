
#import <Foundation/Foundation.h>

@class AXApiClient;
@class AXUser;
@class AXLoginViews;

@interface AXUserService : NSObject

@property (readonly, nonatomic) AXUser *currentUser;

- (instancetype)initWithApiClient:(AXApiClient *)apiClient;
- (void)signupWithUsername:(NSString *)username password:(NSString *)password properties:(NSDictionary *)properties completion:(void(^)(AXUser *, NSError *))completion;
- (void)loginWithUsername:(NSString *)username password:(NSString *)password completion:(void(^)(AXUser *user, NSError *error))completion;
- (void)requireLogin:(void(^)(AXUser *))completion withCustomViews:(void(^)(AXLoginViews *views))loginViews;
- (void)logout;

@end
