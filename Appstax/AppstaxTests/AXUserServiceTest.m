
#import <XCTest/XCTest.h>
#import "AppstaxInternals.h"
#import "AXAsssertions.h"
#import "OHHTTPStubs.h"
#import "OHHTTPStubsResponse+JSON.h"
#import "AXStubs.h"

@interface AXUserServiceTest : XCTestCase
@property AXKeychain *keychain;
@property AXJsonApiClient *apiClient;
@end

@implementation AXUserServiceTest

- (void)setUp {
    [super setUp];
    [OHHTTPStubs setEnabled:YES];
    [Appstax setAppKey:@"test-api-key" baseUrl:@"http://localhost:3000/"];
    _apiClient = [[Appstax defaultContext] apiClient];
    _keychain = [[[Appstax defaultContext] userService] keychain];
    [_keychain clear];
}

- (void)tearDown {
    [super tearDown];
    [OHHTTPStubs removeAllStubs];
}

- (void)setupTestUserSessionWithUsename:(NSString *)username userObjectID:(NSString *)userObjectID {
    _keychain[@"SessionID"] = @"fake-session-id";
    _keychain[@"Username"] = username;
    _keychain[@"UserObjectID"] = userObjectID;
}

#pragma mark - Signup

- (void)testShouldSetCurrentUserWhenSignupSucceeds {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block AXUser *signupUser;
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/users"] &&
               [request.HTTPMethod isEqualToString:@"POST"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:200 headers:nil];
    }];

    [AXUser signupWithUsername:@"homer"
                      password:@"springfield"
                    completion:^(AXUser *user, NSError *error) {
                        signupUser = user;
                        [exp1 fulfill];
                    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertNotNil([AXUser currentUser]);
        XCTAssertEqualObjects(signupUser, [AXUser currentUser]);
    }];
}

- (void)testSignupShouldPostToApi {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block NSDictionary *postData;
    __block NSURL *postUrl;
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/users"] &&
               [request.HTTPMethod isEqualToString:@"POST"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSData *httpBody = [NSURLProtocol propertyForKey:@"HTTPBody" inRequest:request];
        postData = [NSJSONSerialization JSONObjectWithData:httpBody options:0 error:nil];
        postUrl = request.URL;
        [exp1 fulfill];
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:200 headers:nil];
    }];
    
    [AXUser signupWithUsername:@"foo" password:@"bar" completion:nil];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        AXAssertContains(postUrl.absoluteString, @"/users");
        XCTAssertEqualObjects(postData[@"sysUsername"], @"foo");
        XCTAssertEqualObjects(postData[@"sysPassword"], @"bar");
    }];
}

- (void)testShouldUseUserObjectIdFromServerWhenSignupSucceeds {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block AXUser *signupUser;
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/users"] &&
        [request.HTTPMethod isEqualToString:@"POST"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"user":@{@"sysObjectId":@"userid001"}}
                                                statusCode:200 headers:nil];
    }];
    
    [AXUser signupWithUsername:@"homer"
                      password:@"springfield"
                    completion:^(AXUser *user, NSError *error) {
                        signupUser = user;
                        [exp1 fulfill];
                    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqualObjects(signupUser.objectID, @"userid001");
    }];
}

- (void)testShouldUseSessionIdFromSignupWhenItSucceeds {
    AXJsonApiClient *apiClient = [[Appstax defaultContext] apiClient];
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/users"] &&
               [request.HTTPMethod isEqualToString:@"POST"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"sysSessionId":@"the-session-id"}
                                                statusCode:200 headers:nil];
    }];

    XCTAssertNil(apiClient.sessionID);
    
    [AXUser signupWithUsername:@"me" password:@"secret" completion:^(AXUser *user, NSError *error) {
        [exp1 fulfill];
    }];
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqualObjects(@"the-session-id", apiClient.sessionID);
    }];
}

- (void)testShouldStoreSessionIdUserObjectIdAndUsernameOnKeychainWhenSignupSucceeds {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    AXKeychain *keychain = [[[Appstax defaultContext] userService] keychain];
    [keychain clear];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/users"] &&
        [request.HTTPMethod isEqualToString:@"POST"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"sysSessionId":@"mysession",@"user":@{@"sysObjectId":@"the-user-id"}}
                                                statusCode:200 headers:nil];
    }];
    
    [AXUser signupWithUsername:@"moi" password:@"secret" completion:^(AXUser *user, NSError *error) {
        [exp1 fulfill];
    }];
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqualObjects(@"mysession", keychain[@"SessionID"]);
        XCTAssertEqualObjects(@"the-user-id", keychain[@"UserObjectID"]);
        XCTAssertEqualObjects(@"moi", keychain[@"Username"]);
    }];
}

- (void)testShouldReturnUserObjectWhenSignupSucceeds {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/users"] &&
               [request.HTTPMethod isEqualToString:@"POST"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"sysSessionId":@"sid"}
                                                statusCode:200 headers:nil];
    }];
    
    __block AXUser *signupUser;
    [AXUser signupWithUsername:@"homer"
                      password:@"duff"
                    completion:^(AXUser *user, NSError *error) {
                        signupUser = user;
                        [exp1 fulfill];
                    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqualObjects(signupUser.username, @"homer");
    }];
}

- (void)testShouldReturnErrorWhenSignupFails {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/users"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData:nil statusCode:422 headers:nil];
    }];
    
    __block NSError *signupError;
    __block AXUser *signupUser;
    [AXUser signupWithUsername:@"charlie"
                      password:@"brown"
                    completion:^(AXUser *user, NSError *error) {
                        signupUser = user;
                        signupError = error;
                        [exp1 fulfill];
                    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertNotNil(signupError);
        XCTAssertNil(signupUser);
    }];
}

#pragma mark - Login

- (void)testLoginShouldPostToApi {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block NSDictionary *postData;
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/sessions"] &&
        [request.HTTPMethod isEqualToString:@"POST"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSData *httpBody = [NSURLProtocol propertyForKey:@"HTTPBody" inRequest:request];
        postData = [NSJSONSerialization JSONObjectWithData:httpBody options:0 error:nil];
        [exp1 fulfill];
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:200 headers:nil];
    }];
    
    [AXUser loginWithUsername:@"calvin" password:@"hobbes" completion:nil];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqualObjects(postData[@"sysUsername"], @"calvin");
        XCTAssertEqualObjects(postData[@"sysPassword"], @"hobbes");
    }];
}

- (void)testShouldUseSessionIdFromLoginWhenItSucceeds {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/sessions"] &&
        [request.HTTPMethod isEqualToString:@"POST"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"sysSessionId":@"1234-5678"}
                                                statusCode:200 headers:nil];
    }];
    
    XCTAssertNil(_apiClient.sessionID);
    
    [AXUser loginWithUsername:@"monty" password:@"burns" completion:^(AXUser *user, NSError *error) {
        [exp1 fulfill];
    }];
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqualObjects(@"1234-5678", _apiClient.sessionID);
    }];
}

- (void)testShouldUseUserObjectIdFromServerWhenLoginSucceeds {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block AXUser *loginUser;
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/sessions"] &&
        [request.HTTPMethod isEqualToString:@"POST"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"user":@{@"sysObjectId":@"userid911"}}
                                                statusCode:200 headers:nil];
    }];
    
    [AXUser loginWithUsername:@"homer"
                     password:@"springfield"
                   completion:^(AXUser *user, NSError *error) {
                       loginUser = user;
                       [exp1 fulfill];
                   }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqualObjects(loginUser.objectID, @"userid911");
    }];
}

- (void)testShouldReturnUserObjectWhenLoginSucceeds {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/sessions"] &&
        [request.HTTPMethod isEqualToString:@"POST"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"sysSessionId":@"thesessionid"}
                                                statusCode:200 headers:nil];
    }];
    
    __block AXUser *loginUser;
    [AXUser loginWithUsername:@"burns"
                     password:@"excellent!"
                   completion:^(AXUser *user, NSError *error) {
                       loginUser = user;
                       [exp1 fulfill];
                   }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqualObjects(loginUser.username, @"burns");
    }];
}

- (void)testShouldReturnErrorWhenLoginFails {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/sessions"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData:nil statusCode:500 headers:nil];
    }];
    
    __block NSError *signupError;
    __block AXUser *signupUser;
    [AXUser loginWithUsername:@"snoopy"
                     password:@"redbaron"
                   completion:^(AXUser *user, NSError *error) {
                       signupUser = user;
                       signupError = error;
                       [exp1 fulfill];
                   }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertNotNil(signupError);
        XCTAssertNil(signupUser);
    }];
}

- (void)testShouldSetCurrentUserWhenLoginSucceeds {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block AXUser *loginUser;
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/sessions"] &&
        [request.HTTPMethod isEqualToString:@"POST"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:200 headers:nil];
    }];
    
    [AXUser loginWithUsername:@"marge"
                     password:@"maggie"
                   completion:^(AXUser *user, NSError *error) {
                       loginUser = user;
                       [exp1 fulfill];
                   }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertNotNil([AXUser currentUser]);
        XCTAssertEqualObjects(loginUser, [AXUser currentUser]);
    }];
}


- (void)testShouldStoreSessionIdUserObjectIdAndUsernameOnKeychainWhenLoginSucceeds {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/sessions"] &&
        [request.HTTPMethod isEqualToString:@"POST"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"sysSessionId":@"session001",@"user":@{@"sysObjectId":@"a-user-id"}}
                                                statusCode:200 headers:nil];
    }];
    
    [AXUser loginWithUsername:@"tintin" password:@"secret" completion:^(AXUser *user, NSError *error) {
        [exp1 fulfill];
    }];
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqualObjects(@"session001", _keychain[@"SessionID"]);
        XCTAssertEqualObjects(@"a-user-id", _keychain[@"UserObjectID"]);
        XCTAssertEqualObjects(@"tintin", _keychain[@"Username"]);
    }];
}

#pragma mark - Logout

- (void)testLogoutShouldSendDeleteRequest {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    [[[Appstax defaultContext] apiClient] setSessionID:@"session1234"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/sessions/session1234"] &&
        [request.HTTPMethod isEqualToString:@"DELETE"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        [exp1 fulfill];
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:204 headers:nil];
    }];
    
    [AXUser logout];
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {}];
}

- (void)testLogoutShouldRemoveCurrentUserAndSession {
    AXUser *user = [[AXUser alloc] initWithUsername:@"myuser" properties:@{@"sysObjectId":@"theobjectid"}];
    [[[Appstax defaultContext] userService] setCurrentUser:user];
    [[[Appstax defaultContext] apiClient] setSessionID:@"session911"];
    
    XCTAssertEqualObjects(user, [AXUser currentUser]);
    
    [AXUser logout];
    XCTAssertNil([AXUser currentUser]);
    XCTAssertNil([[[Appstax defaultContext] apiClient] sessionID]);
}

#pragma mark - Restore user session

- (void)testCurrentUserIsNilAtFirst {
    XCTAssertNil([AXUser currentUser]);
}

- (void)testShouldRestorePreviousSessionFromKeychain {
    _keychain[@"SessionID"] = @"previous-session-id";
    _keychain[@"Username"] = @"kilroy";
    _keychain[@"UserObjectID"] = @"TheUserObjectID";
    XCTAssertEqualObjects(@"kilroy", [[AXUser currentUser] username]);
    XCTAssertEqualObjects(@"previous-session-id", _apiClient.sessionID);
    XCTAssertEqualObjects(@"TheUserObjectID", [[AXUser currentUser] objectID]);
}

#pragma mark - Custom properties on user object

- (void)testSavingUserShouldPutToUsersCollection {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block NSDictionary *putData;
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/objects/Users/homer-id"] &&
        [request.HTTPMethod isEqualToString:@"PUT"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSData *httpBody = [NSURLProtocol propertyForKey:@"HTTPBody" inRequest:request];
        putData = [NSJSONSerialization JSONObjectWithData:httpBody options:0 error:nil];
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:200 headers:nil];
    }];
    
    [self setupTestUserSessionWithUsename:@"homer" userObjectID:@"homer-id"];
    AXUser *user = [AXUser currentUser];
    [user save:^(NSError *error) {
        [exp1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertTrue([putData isKindOfClass:[NSDictionary class]]);
    }];
}

- (void)testSavingUserShouldPutCustomPropertiesAndSystemProperties {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block NSDictionary *putData;
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/objects/Users/homer-id"] &&
        [request.HTTPMethod isEqualToString:@"PUT"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSData *httpBody = [NSURLProtocol propertyForKey:@"HTTPBody" inRequest:request];
        putData = [NSJSONSerialization JSONObjectWithData:httpBody options:0 error:nil];
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:200 headers:nil];
    }];
    
    [self setupTestUserSessionWithUsename:@"homer" userObjectID:@"homer-id"];
    AXUser *user = [AXUser currentUser];
    user[@"FullName"] = @"Homer Simpson";
    user[@"Hometown"] = @"Springfield";
    [user save:^(NSError *error) {
        [exp1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertTrue([putData isKindOfClass:[NSDictionary class]]);
        XCTAssertEqualObjects(putData[@"FullName"], @"Homer Simpson");
        XCTAssertEqualObjects(putData[@"Hometown"], @"Springfield");
        XCTAssertEqualObjects(putData[@"sysUsername"], @"homer");
    }];
}

- (void)testSavingUserShouldReportErrors {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/objects/Users/homer-id"] &&
        [request.HTTPMethod isEqualToString:@"PUT"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"errorMessage":@"The save error"}
                                                statusCode:422 headers:nil];
    }];
    
    __block NSError *saveError;
    [self setupTestUserSessionWithUsename:@"homer" userObjectID:@"homer-id"];
    [[AXUser currentUser] save:^(NSError *error) {
        saveError = error;
        [exp1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertNotNil(saveError);
        XCTAssertEqualObjects(saveError.userInfo[@"errorMessage"], @"The save error");
    }];
}

- (void)testShouldIncludeCustomPropertiesOnUserWhenLoginSucceeds {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/sessions"] &&
        [request.HTTPMethod isEqualToString:@"POST"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"sysSessionId":@"thesessionid",@"user":@{@"sysObjectId":@"the-user-id",@"FullName":@"Montgomery Burns"}}
                                                statusCode:200 headers:nil];
    }];
    
    __block AXUser *loginUser;
    [AXUser loginWithUsername:@"burns"
                     password:@"excellent!"
                   completion:^(AXUser *user, NSError *error) {
                       loginUser = user;
                       [exp1 fulfill];
                   }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqualObjects(loginUser.objectID, @"the-user-id");
        XCTAssertEqualObjects(loginUser[@"FullName"], @"Montgomery Burns");
    }];
}


- (void)testShouldRefreshAUserObject {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block XCTestExpectation *exp2 = [self expectationWithDescription:@"async2"];
    
    [AXStubs method:@"POST" urlPath:@"/users" response:@{@"sysSessionId":@"sess",@"user":@{@"sysObjectId":@"user-id",@"FullName":@"Montgomery Burns"}} statusCode:200];
    [AXStubs method:@"GET" urlPath:@"/objects/Users/user-id" response:@{@"sysObjectId":@"user-id",@"FullName":@"Monty"} statusCode:200];
    
    __block AXUser *signupUser;
    [AXUser signupWithUsername:@"monty" password:@"money" completion:^(AXUser *user, NSError *error) {
        [exp1 fulfill];
        signupUser = user;
        [signupUser refresh:^(NSError *error) {
            [exp2 fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqualObjects(signupUser[@"FullName"], @"Monty");
    }];
}


- (void)testShouldRefreshUserObjectWhenRestoringSession {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [AXStubs method:@"GET" urlPath:@"/objects/Users/TheUserObjectID" response:@{@"sysObjectId":@"TheUserObjectID",@"FullName":@"Kimberly Royal"} statusCode:200];
    
    _keychain[@"SessionID"] = @"previous-session-id";
    _keychain[@"Username"] = @"kilroy";
    _keychain[@"UserObjectID"] = @"TheUserObjectID";
    
    [AXUser requireLogin:^(AXUser *user) {
        [exp1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqualObjects([AXUser currentUser][@"FullName"], @"Kimberly Royal");
        XCTAssertEqualObjects([[AXUser currentUser] objectID], @"TheUserObjectID");
    }];
}


@end
