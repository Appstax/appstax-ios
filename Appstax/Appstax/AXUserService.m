
#import "AXUserService.h"
#import "AppstaxInternals.h"
#import "AXLoginUIManager.h"
#import "AXKeychain.h"

@interface AXUserService ()
@property AXJsonApiClient *apiClient;
@property AXUser *currentUser;
@property AXLoginUIManager *loginManager;
@property AXKeychain *keychain;
@end

@implementation AXUserService

- (instancetype)initWithApiClient:(AXJsonApiClient *)apiClient {
    self = [super init];
    if(self) {
        _apiClient = apiClient;
        _loginManager = [[AXLoginUIManager alloc] initWithUserService:self];
        _keychain = [[AXKeychain alloc] init];
    }
    return self;
}

- (void)signupWithUsername:(NSString *)username password:(NSString *)password completion:(void(^)(AXUser *, NSError *))completion {
    
    NSURL *url = [_apiClient urlByConcatenatingStrings:@[@"users"]];
    [_apiClient postDictionary:@{@"sysUsername":username,@"sysPassword":password}
                         toUrl:url
                    completion:^(NSDictionary *dictionary, NSError *error) {
                        if(completion != nil) {
                            [self setSessionID:dictionary[@"sysSessionId"]];
                            if(!error) {
                                NSString *objectID = [dictionary valueForKeyPath:@"user.sysObjectId"];
                                _keychain[@"SessionID"] = dictionary[@"sysSessionId"];
                                _keychain[@"Username"] = username;
                                _keychain[@"UserObjectID"] = objectID;
                                _currentUser = [[AXUser alloc] initWithUsername:username properties:dictionary[@"user"]];
                                completion(_currentUser, nil);
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
    _apiClient.sessionID = sessionID;
}

- (void)logout {
    if(_apiClient.sessionID) {
        [_apiClient deleteUrl:[_apiClient urlByConcatenatingStrings:@[@"sessions/", _apiClient.sessionID]]
                   completion:nil];
    }
    _keychain[@"SessionID"] = nil;
    _keychain[@"Username"] = nil;
    _currentUser = nil;
    _apiClient.sessionID = nil;
}

- (void)restoreUserFromPreviousSession {
    NSString *sessionID = _keychain[@"SessionID"];
    NSString *username = _keychain[@"Username"];
    NSString *userObjectID = _keychain[@"UserObjectID"];
    if(sessionID != nil && username != nil && userObjectID != nil) {
        [_apiClient setSessionID:sessionID];
        _currentUser = [[AXUser alloc] initWithUsername:username properties:@{@"sysObjectId":userObjectID}];
    }
}

@end
