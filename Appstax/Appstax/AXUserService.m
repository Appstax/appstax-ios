
#import "AppstaxInternals.h"
#import "AXUserService.h"
#import "AXLoginUIManager.h"
#import "AXKeychain.h"
#import <Appstax/Appstax-Swift.h>

@interface AXUserService ()
@property AXApiClient *apiClient;
@property AXUser * _Nullable currentUser;
@property AXLoginUIManager *loginManager;
@end

@implementation AXUserService

- (instancetype)initWithApiClient:(AXApiClient *)apiClient {
    self = [super init];
    if(self) {
        _apiClient = apiClient;
        _loginManager = [[AXLoginUIManager alloc] initWithUserService:self];
        _keychain = [[AXKeychain alloc] init];
    }
    return self;
}

- (void)signupWithUsername:(NSString *)username password:(NSString *)password login:(BOOL)login properties:(NSDictionary *)properties completion:(void(^)(AXUser *, NSError *))completion {
    
    NSURL *url = [_apiClient urlByConcatenatingStrings:@[@"users"]];
    if(!login) {
        url = [_apiClient urlByConcatenatingStrings:@[@"users?login=false"]];
    }
    NSMutableDictionary *data = [NSMutableDictionary dictionaryWithDictionary:properties];
    data[@"sysUsername"] = username;
    data[@"sysPassword"] = password;
    [_apiClient postDictionary:data
                         toUrl:url
                    completion:^(NSDictionary *dictionary, NSError *error) {
                        if(completion != nil) {
                            [self setSessionID:dictionary[@"sysSessionId"]];
                            if(!error) {
                                NSString *objectID = [dictionary valueForKeyPath:@"user.sysObjectId"];
                                AXUser *user = [[AXUser alloc] initWithUsername:username properties:dictionary[@"user"]];
                                if(login) {
                                    _currentUser = user;
                                    _keychain[@"SessionID"] = dictionary[@"sysSessionId"];
                                    _keychain[@"Username"] = username;
                                    _keychain[@"UserObjectID"] = objectID;
                                }
                                completion(user, nil);
                            } else {
                                completion(nil, error);
                            }
                        }
                    }];
}

- (void)loginWithUsername:(NSString *)username password:(NSString *)password completion:(void(^)(AXUser *user, NSError *error))completion {
    
    NSURL *url = [_apiClient urlByConcatenatingStrings:@[@"sessions"]];
    [_apiClient postDictionary:@{@"sysUsername":username,@"sysPassword":password}
                         toUrl:url
                    completion:^(NSDictionary *dictionary, NSError *error) {
                        if(!completion) { return; }
                        if(!error) {
                            [self setSessionID:dictionary[@"sysSessionId"]];
                            NSString *objectID = [dictionary valueForKeyPath:@"user.sysObjectId"];
                            _keychain[@"SessionID"] = dictionary[@"sysSessionId"];
                            _keychain[@"Username"] = username;
                            _keychain[@"UserObjectID"] = objectID;
                            _currentUser = [[AXUser alloc] initWithUsername:username properties:dictionary[@"user"]];
                            completion(_currentUser, nil);
                        } else {
                            completion(nil, error);
                        }
                    }];
}

- (AXUser *)currentUser {
    if(!_currentUser) {
        [self restoreUserFromPreviousSession];
    }
    return _currentUser;
}

- (void)requireLogin:(void(^)(AXUser *))completion withCustomViews:(void(^)(AXLoginViews *views))loginViews {
    if(self.currentUser) {
        [self.currentUser refresh:^(NSError *error) {
            completion(self.currentUser);
        }];
    } else {
        [_loginManager presentModalLoginWithViews:loginViews completion:^{
            completion(self.currentUser);
        }];
    }
}

- (void)setSessionID:(NSString *)sessionID {
    [_apiClient updateSessionID:sessionID];
}

- (void)logout {
    if(_apiClient.sessionID) {
        [_apiClient deleteUrl:[_apiClient urlByConcatenatingStrings:@[@"sessions/", _apiClient.sessionID]]
                   completion:nil];
    }
    _keychain[@"SessionID"] = nil;
    _keychain[@"Username"] = nil;
    _currentUser = nil;
    [_apiClient updateSessionID:nil];
}

- (void)restoreUserFromPreviousSession {
    NSString *sessionID = _keychain[@"SessionID"];
    NSString *username = _keychain[@"Username"];
    NSString *userObjectID = _keychain[@"UserObjectID"];
    if(sessionID != nil && username != nil && userObjectID != nil) {
        [_apiClient updateSessionID:sessionID];
        _currentUser = [[AXUser alloc] initWithUsername:username properties:@{@"sysObjectId":userObjectID}];
    }
}

@end
