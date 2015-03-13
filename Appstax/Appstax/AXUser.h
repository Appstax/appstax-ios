
#import <Foundation/Foundation.h>
#import "AXLoginViews.h"

@class UIView;

@interface AXUser : NSObject

@property (readonly) NSString *username;
@property (readonly) NSString *objectID;

- (void)save;
- (void)save:(void(^)(NSError *error))completion;
- (void)refresh:(void(^)(NSError *error))completion;

- (id)objectForKeyedSubscript:(id <NSCopying>)key;
- (void)setObject:(id)obj forKeyedSubscript:(id <NSCopying>)key;

+ (void)requireLogin:(void(^)(AXUser *user))completion;
+ (void)requireLogin:(void(^)(AXUser *))completion withCustomViews:(void(^)(AXLoginViews *views))loginViews;
+ (AXUser *)currentUser;
+ (void)logout;
+ (void)signupWithUsername:(NSString *)username password:(NSString *)password completion:(void(^)(AXUser *user, NSError *error))completion;
+ (void)loginWithUsername:(NSString *)username password:(NSString *)password completion:(void(^)(AXUser *user, NSError *error))completion;


@end
