
#import <XCTest/XCTest.h>
#import "AppstaxInternals.h"
#import "AXAsssertions.h"
#import "AXStubs.h"

@interface AXPermissionsTests : XCTestCase
@property AXJsonApiClient *apiClient;
@end

@implementation AXPermissionsTests

- (void)setUp {
    [super setUp];
    [OHHTTPStubs setEnabled:YES];
    [Appstax setAppKey:@"test-api-key" baseUrl:@"http://localhost:3000/"];
    _apiClient = [[Appstax defaultContext] apiClient];
}

- (void)tearDown {
    [super tearDown];
    [OHHTTPStubs removeAllStubs];
}

- (void)testShouldPostPermissionChangesBeforeObjectSaveCompletes {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block XCTestExpectation *exp2 = [self expectationWithDescription:@"async2"];
    __block NSDictionary *data;
    
    [AXStubs method:@"POST" urlPath:@"/objects/foo" response:@{@"sysObjectId":@"id1"} statusCode:200];
    [AXStubs method:@"POST" urlPath:@"/permissions" responding:^OHHTTPStubsResponse *(NSURLRequest *request) {
        NSData *httpBody = [NSURLProtocol propertyForKey:@"HTTPBody" inRequest:request];
        data = [NSJSONSerialization JSONObjectWithData:httpBody options:0 error:nil];
        [exp1 fulfill];
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:200 headers:nil];
    }];
    
    
    AXObject *object = [AXObject create:@"foo"];
    [object grant:@"buddy" permissions:@[@"read",@"update"]];
    [object grant:@"bff" permissions:@[@"read",@"update",@"delete"]];
    [object revoke:@"badboy" permissions:@[@"read"]];
    [object save:^(NSError *error) {
        [exp2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqualObjects(data[@"grants"][0][@"username"], @"buddy");
        XCTAssertEqualObjects(data[@"grants"][0][@"sysObjectId"], @"id1");
        XCTAssertEqualObjects(data[@"grants"][0][@"permissions"][0], @"read");
        XCTAssertEqualObjects(data[@"grants"][0][@"permissions"][1], @"update");
        XCTAssertEqualObjects(data[@"grants"][1][@"username"], @"bff");
        XCTAssertEqualObjects(data[@"grants"][1][@"sysObjectId"], @"id1");
        XCTAssertEqualObjects(data[@"grants"][1][@"permissions"][0], @"read");
        XCTAssertEqualObjects(data[@"grants"][1][@"permissions"][1], @"update");
        XCTAssertEqualObjects(data[@"grants"][1][@"permissions"][2], @"delete");
        XCTAssertEqualObjects(data[@"grants"][1][@"username"], @"bff");
        XCTAssertEqualObjects(data[@"grants"][1][@"sysObjectId"], @"id1");
        XCTAssertEqualObjects(data[@"grants"][1][@"permissions"][0], @"read");
        XCTAssertEqualObjects(data[@"revokes"][0][@"username"], @"badboy");
        XCTAssertEqualObjects(data[@"revokes"][0][@"sysObjectId"], @"id1");
        XCTAssertEqualObjects(data[@"revokes"][0][@"permissions"][0], @"read");
    }];
}

- (void)testShouldNotPostSamePermissionChangesNextSave {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block int permissionPostCount = 0;
    
    [AXStubs method:@"POST" urlPath:@"/objects/foo" response:@{@"sysObjectId":@"id1"} statusCode:200];
    [AXStubs method:@"PUT"  urlPath:@"/objects/foo/id1" response:@{} statusCode:200];
    [AXStubs method:@"POST" urlPath:@"/permissions" responding:^OHHTTPStubsResponse *(NSURLRequest *request) {
        permissionPostCount++;
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:200 headers:nil];
    }];
    
    
    AXObject *object = [AXObject create:@"foo"];
    [object grant:@"buddy" permissions:@[@"read",@"update"]];
    [object revoke:@"badboy" permissions:@[@"read", @"delete"]];
    [object save:^(NSError *error) {
        [object save:^(NSError *error) {
            [exp1 fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqual(permissionPostCount, 1);
    }];
}

- (void)testShouldReceiveErrorIfSaveSucceedsButPermissionFails {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block NSError *saveError;
    
    [AXStubs method:@"POST" urlPath:@"/objects/foo" response:@{@"sysObjectId":@"id1"} statusCode:200];
    [AXStubs method:@"POST" urlPath:@"/permissions" response:@{@"errorMessage":@"Grant error"} statusCode:422];
    
    AXObject *object = [AXObject create:@"foo"];
    [object grant:@"buddy" permissions:@[@"read",@"update"]];
    [object save:^(NSError *error) {
        saveError = error;
        [exp1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertNotNil(saveError);
        XCTAssertEqualObjects(saveError.userInfo[@"errorMessage"], @"Grant error");
    }];
}

- (void)testShouldGrantPermissionsToMultipleUsersAtOnce {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block XCTestExpectation *exp2 = [self expectationWithDescription:@"async2"];
    __block NSDictionary *data;
    
    [AXStubs method:@"POST" urlPath:@"/objects/foo" response:@{@"sysObjectId":@"id2"} statusCode:200];
    [AXStubs method:@"POST" urlPath:@"/permissions" responding:^OHHTTPStubsResponse *(NSURLRequest *request) {
        NSData *httpBody = [NSURLProtocol propertyForKey:@"HTTPBody" inRequest:request];
        data = [NSJSONSerialization JSONObjectWithData:httpBody options:0 error:nil];
        [exp1 fulfill];
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:200 headers:nil];
    }];
    
    AXObject *object = [AXObject create:@"foo"];
    [object revoke:@[@"ex1", @"ex2"] permissions:@[@"read", @"update", @"delete"]];
    [object grant:@[@"friend1", @"friend2", @"friend3"] permissions:@[@"read",@"update",@"delete"]];
    [object save:^(NSError *error) {
        [exp2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        NSArray *permissions = @[@"read",@"update",@"delete"];
        XCTAssertEqualObjects(data[@"revokes"][0][@"username"], @"ex1");
        XCTAssertEqualObjects(data[@"revokes"][0][@"permissions"], permissions);
        XCTAssertEqualObjects(data[@"revokes"][0][@"sysObjectId"], @"id2");
        XCTAssertEqualObjects(data[@"revokes"][1][@"username"], @"ex2");
        XCTAssertEqualObjects(data[@"revokes"][1][@"permissions"], permissions);
        XCTAssertEqualObjects(data[@"revokes"][1][@"sysObjectId"], @"id2");
        XCTAssertEqualObjects(data[@"grants"][0][@"username"], @"friend1");
        XCTAssertEqualObjects(data[@"grants"][0][@"permissions"], permissions);
        XCTAssertEqualObjects(data[@"grants"][0][@"sysObjectId"], @"id2");
        XCTAssertEqualObjects(data[@"grants"][1][@"username"], @"friend2");
        XCTAssertEqualObjects(data[@"grants"][1][@"permissions"], permissions);
        XCTAssertEqualObjects(data[@"grants"][1][@"sysObjectId"], @"id2");
        XCTAssertEqualObjects(data[@"grants"][2][@"username"], @"friend3");
        XCTAssertEqualObjects(data[@"grants"][2][@"permissions"], permissions);
        XCTAssertEqualObjects(data[@"grants"][2][@"sysObjectId"], @"id2");
    }];
}

- (void)testShouldGrantPublicPermissionsWithAsterisk {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block XCTestExpectation *exp2 = [self expectationWithDescription:@"async2"];
    __block NSDictionary *data;
    
    [AXStubs method:@"POST" urlPath:@"/objects/foo" response:@{@"sysObjectId":@"id1001"} statusCode:200];
    [AXStubs method:@"POST" urlPath:@"/permissions" responding:^OHHTTPStubsResponse *(NSURLRequest *request) {
        NSData *httpBody = [NSURLProtocol propertyForKey:@"HTTPBody" inRequest:request];
        data = [NSJSONSerialization JSONObjectWithData:httpBody options:0 error:nil];
        [exp1 fulfill];
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:200 headers:nil];
    }];
    
    
    AXObject *object = [AXObject create:@"foo"];
    [object grantPublic:@[@"read",@"update"]];
    [object save:^(NSError *error) {
        [exp2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqualObjects(data[@"grants"][0][@"username"], @"*");
        XCTAssertEqualObjects(data[@"grants"][0][@"sysObjectId"], @"id1001");
        XCTAssertEqualObjects(data[@"grants"][0][@"permissions"][0], @"read");
        XCTAssertEqualObjects(data[@"grants"][0][@"permissions"][1], @"update");
    }];
}

- (void)testShouldRevokePublicPermissionsWithAsterisk {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block XCTestExpectation *exp2 = [self expectationWithDescription:@"async2"];
    __block NSDictionary *data;
    
    [AXStubs method:@"POST" urlPath:@"/objects/foo" response:@{@"sysObjectId":@"id1002"} statusCode:200];
    [AXStubs method:@"POST" urlPath:@"/permissions" responding:^OHHTTPStubsResponse *(NSURLRequest *request) {
        NSData *httpBody = [NSURLProtocol propertyForKey:@"HTTPBody" inRequest:request];
        data = [NSJSONSerialization JSONObjectWithData:httpBody options:0 error:nil];
        [exp1 fulfill];
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:200 headers:nil];
    }];
    
    
    AXObject *object = [AXObject create:@"foo"];
    [object revokePublic:@[@"delete"]];
    [object save:^(NSError *error) {
        [exp2 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqualObjects(data[@"revokes"][0][@"username"], @"*");
        XCTAssertEqualObjects(data[@"revokes"][0][@"sysObjectId"], @"id1002");
        XCTAssertEqualObjects(data[@"revokes"][0][@"permissions"][0], @"delete");
    }];
}

@end
