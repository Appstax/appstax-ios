
#import "AXUser.h"
#import "AppstaxInternals.h"

@interface AXUser ()
@property NSString *username;
@property AXObject *dataObject;
@end

@implementation AXUser

- (instancetype)initWithUsername:(NSString *)username properties:(NSDictionary *)properties {
    self = [super init];
    if(self) {
        _username = username;
        if(properties) {
            NSMutableDictionary *mutableProperties = [NSMutableDictionary dictionaryWithDictionary:properties];
            mutableProperties[@"sysUsername"] = username;
            _dataObject = [AXObject create:@"Users" properties:mutableProperties];
            _objectID = properties[@"sysObjectId"];
        }
    }
    return self;
}

- (void)save {
    [self save:nil];
}

- (void)save:(void(^)(NSError *error))completion {
    [_dataObject save:completion];
}

- (void)refresh:(void(^)(NSError *error))completion {
    [_dataObject refresh:completion];
}

- (id)objectForKeyedSubscript:(id <NSCopying>)key {
    return _dataObject[key];
}

- (void)setObject:(id)obj forKeyedSubscript:(id <NSCopying>)key {
    _dataObject[key] = obj;
}

#pragma mark - Class convenience methods

+ (void)signupWithUsername:(NSString *)username password:(NSString *)password completion:(void(^)(AXUser *user, NSError *error))completion {
    [[[Appstax defaultContext] userService] signupWithUsername:username password:password completion:completion];
}

+ (void)loginWithUsername:(NSString *)username password:(NSString *)password completion:(void(^)(AXUser *user, NSError *error))completion {
    [[[Appstax defaultContext] userService] loginWithUsername:username password:password completion:completion];
}

+ (void)requireLogin:(void(^)(AXUser *))completion {
    [[[Appstax defaultContext] userService] requireLogin:completion withCustomViews:nil];
}

+ (void)requireLogin:(void(^)(AXUser *))completion withCustomViews:(void(^)(AXLoginViews *views))loginViews {
    [[[Appstax defaultContext] userService] requireLogin:completion withCustomViews:loginViews];
}

+ (AXUser *)currentUser {
    return [[[Appstax defaultContext] userService] currentUser];
}

+ (void)logout {
    [[[Appstax defaultContext] userService] logout];
}

@end
