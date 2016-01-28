
#import <Foundation/Foundation.h>

@class AXApiClient;
@class AXUser;
@class AXLoginViews;
@class AXKeychain;

@interface AXUserService : NSObject

@property (readonly, nonatomic) AXUser *currentUser;

// shoud be made private when possible
@property AXKeychain *keychain;

- (instancetype)initWithApiClient:(AXApiClient *)apiClient;
- (void)signupWithUsername:(NSString *)username password:(NSString *)password login:(BOOL)login properties:(NSDictionary *)properties completion:(void(^)(AXUser *, NSError *))completion;
- (void)loginWithUsername:(NSString *)username password:(NSString *)password completion:(void(^)(AXUser *user, NSError *error))completion;
- (void)requireLogin:(void(^)(AXUser *))completion withCustomViews:(void(^)(AXLoginViews *views))loginViews;
- (void)logout;

@end
