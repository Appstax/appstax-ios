
#import <XCTest/XCTest.h>
#import "AppstaxInternals.h"
#import "AXAsssertions.h"
#import "OHHTTPStubs.h"
#import "OHHTTPStubsResponse+JSON.h"
#import "AXStubs.h"

@interface AXDataStoreTests : XCTestCase
@property AXJsonApiClient *apiClient;
@end

@implementation AXDataStoreTests

- (void)setUp {
    [super setUp];
    [OHHTTPStubs setEnabled:YES];
    [Appstax setAppKey:@"test-api-key" baseUrl:@"http://localhost:3000/"];
    _apiClient = [[Appstax defaultContext] apiClient];
}

- (void)tearDown {
    [OHHTTPStubs removeAllStubs];
    [super tearDown];
}

#pragma mark - Helpers

- (NSString *)valueOfParameter:(NSString *)parameter inUrl:(NSURL *)url {
    __block NSString *value = @"";
    [[url.query componentsSeparatedByString:@"&"] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSArray *keyValue = [obj componentsSeparatedByString:@"="];
        if([keyValue[0] isEqualToString:parameter]) {
            value = keyValue[1];
        }
    }];
    return value;
}

#pragma mark - Tests

- (void)testShouldCreateObjectWithProperties {
    AXObject *object = [AXObject create:@"character" properties:@{@"name":@"Homer", @"iq":@13}];
    XCTAssertEqual(@"character", object.collectionName);
    XCTAssertEqualObjects(object[@"name"], @"Homer");
    XCTAssertEqualObjects(object[@"iq"], @13);
}

- (void)testShouldPostWhenSavingObject {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block NSDictionary *postData;
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/objects/country"] &&
                [request.HTTPMethod isEqualToString:@"POST"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSData *httpBody = [NSURLProtocol propertyForKey:@"HTTPBody" inRequest:request];
        postData = [NSJSONSerialization JSONObjectWithData:httpBody options:0 error:nil];
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:200 headers:nil];
    }];
    
    AXObject *object = [AXObject create:@"country" properties:@{@"name":@"Norway", @"continent":@"Europe"}];
    [object save:^(NSError *error) {
        [exp1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertTrue([postData isKindOfClass:[NSDictionary class]]);
        XCTAssertEqualObjects(postData[@"name"], @"Norway");
        XCTAssertEqualObjects(postData[@"continent"], @"Europe");
    }];
}

- (void)testShouldSetObjectIDWhenSavingCompletes {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/objects/mycollection"] &&
                [request.HTTPMethod isEqualToString:@"POST"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"sysObjectId":@"1234-5678"}
                                                statusCode:200 headers:nil];
    }];
    
    AXObject *testObject = [AXObject create:@"mycollection"];
    [testObject save:^(NSError *error) {
        [exp1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqualObjects(testObject.objectID, @"1234-5678");
        XCTAssertEqualObjects(testObject[@"sysObjectId"], @"1234-5678");
    }];
}

- (void)testShouldUseCollectionNameInUrlWhenLoadingAllObjectsInACollection {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/objects/MyCollection"] &&
                [request.HTTPMethod isEqualToString:@"GET"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:200 headers:nil];
    }];
    
    [AXObject findAll:@"MyCollection" completion:^(NSArray *objects, NSError *error) {
        XCTAssertNil(error);
        [exp1 fulfill];
    }];
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {}];
}

- (void)testShouldGetArrayOfAXObjectsWhenLoadingAllObjectsInACollection {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/objects/TheCollection"] &&
                [request.HTTPMethod isEqualToString:@"GET"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSDictionary *response = @{@"objects":@[@{@"sysObjectId":@"1234",@"foo":@"bar"},@{@"sysObjectId":@"5678",@"baz":@"gaz"}]};
        return [OHHTTPStubsResponse responseWithJSONObject:response
                                                statusCode:200 headers:nil];
    }];
    
    [AXObject findAll:@"TheCollection" completion:^(NSArray *objects, NSError *error) {
        XCTAssertEqual(2, objects.count);
        AXObject *object1 = objects[0];
        AXObject *object2 = objects[1];
        XCTAssertTrue([object1 isKindOfClass:[AXObject class]]);
        XCTAssertTrue([object2 isKindOfClass:[AXObject class]]);
        XCTAssertEqualObjects(object1.collectionName, @"TheCollection");
        XCTAssertEqualObjects(object1.collectionName, @"TheCollection");
        XCTAssertEqualObjects(object1[@"foo"], @"bar");
        XCTAssertEqualObjects(object2[@"baz"], @"gaz");
        XCTAssertEqualObjects(object1.objectID, @"1234");
        XCTAssertEqualObjects(object2.objectID, @"5678");
        XCTAssertEqual(object1.status, AXObjectStatusSaved);
        XCTAssertEqual(object2.status, AXObjectStatusSaved);
        [exp1 fulfill];
    }];
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {}];
}

- (void)testShouldUseCollectionNameAndObjectIDInUrlWhenLoadingSingleObject {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/objects/contact/1234-5678-9"] &&
                [request.HTTPMethod isEqualToString:@"GET"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"name":@"John"}
                                                statusCode:200 headers:nil];
    }];
    
    [AXObject find:@"contact" withId:@"1234-5678-9" completion:^(AXObject *object, NSError *error) {
        XCTAssertNil(error);
        [exp1 fulfill];
    }];
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {}];
}

- (void)testShouldReturnLoadedObjectAsInstanceOfAXObject {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/objects/city/1001"] &&
                [request.HTTPMethod isEqualToString:@"GET"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSDictionary *response = @{@"sysObjectId":@"1001",@"state":@"California", @"weather":@"Sunny"};
        return [OHHTTPStubsResponse responseWithJSONObject:response
                                                statusCode:200 headers:nil];
    }];
    
    __block AXObject *axObject;
    [AXObject find:@"city" withId:@"1001" completion:^(AXObject *object, NSError *error) {
        axObject = object;
        [exp1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertTrue([axObject isKindOfClass:[AXObject class]]);
        XCTAssertEqualObjects(axObject.collectionName, @"city");
        XCTAssertEqualObjects(axObject[@"state"], @"California");
        XCTAssertEqualObjects(axObject[@"weather"], @"Sunny");
        XCTAssertEqualObjects(axObject.objectID, @"1001");
        XCTAssertEqual(axObject.status, AXObjectStatusSaved);
    }];
}

- (void)testShouldPutObjectWhenSavingAPreviouslyLoadedAXObject {
    __block __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block NSDictionary *putData;
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/objects/answer/42"] &&
        [request.HTTPMethod isEqualToString:@"GET"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSDictionary *response = @{@"sysObjectId":@"42",@"sysCreated":@"2014-09-11 09:20:18.762809+02",@"foo":@"bar"};
        return [OHHTTPStubsResponse responseWithJSONObject:response
                                                statusCode:200 headers:nil];
    }];
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/objects/answer/42"] &&
        [request.HTTPMethod isEqualToString:@"PUT"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSData *httpBody = [NSURLProtocol propertyForKey:@"HTTPBody" inRequest:request];
        putData = [NSJSONSerialization JSONObjectWithData:httpBody options:0 error:nil];
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:200 headers:nil];
    }];
    
    [AXObject find:@"answer" withId:@"42" completion:^(AXObject *object, NSError *error) {
        object[@"foz"] = @"baz";
        [object save:^(NSError *error) {
            XCTAssertNil(error);
            [exp1 fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqualObjects(putData[@"sysObjectId"], @"42");
        XCTAssertEqualObjects(putData[@"sysCreated"], @"2014-09-11 09:20:18.762809+02");
        XCTAssertEqualObjects(putData[@"foo"], @"bar");
        XCTAssertEqualObjects(putData[@"foz"], @"baz");
    }];
}

- (void)testShouldMarkObjectAsNewWhenCreated {
    AXObject *object = [AXObject create:@"foobar" properties:@{@"foo":@"bar"}];
    XCTAssertEqual(object.status, AXObjectStatusNew);
}


- (void)testShouldMarkObjectAsSavedAfterPostCallCompletes {
    AXObject *object = [AXObject create:@"foobar" properties:@{@"foo":@"bar"}];
    __block __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block AXObjectStatus statusDuringCall;
    __block AXObjectStatus statusAfterCall;
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/objects/foobar"] &&
                [request.HTTPMethod isEqualToString:@"POST"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        statusDuringCall = object.status;
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:200 headers:nil];
    }];
    
    [object save:^(NSError *err) {
        statusAfterCall = object.status;
        [exp1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqual(statusDuringCall, AXObjectStatusSaving);
        XCTAssertEqual(statusAfterCall, AXObjectStatusSaved);
    }];
}

- (void)testShouldMarkObjectAsSavedAfterPutCallCompletes {
    AXObject *object = [AXObject create:@"foobar" properties:@{@"sysObjectId":@"theid",@"foo":@"bar"}];
    __block __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block AXObjectStatus statusDuringCall;
    __block AXObjectStatus statusAfterCall;
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/objects/foobar/theid"] &&
                [request.HTTPMethod isEqualToString:@"PUT"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        statusDuringCall = object.status;
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:200 headers:nil];
    }];
    
    [object save:^(NSError *err) {
        statusAfterCall = object.status;
        [exp1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqual(statusDuringCall, AXObjectStatusSaving);
        XCTAssertEqual(statusAfterCall, AXObjectStatusSaved);
    }];
}

- (void)testShouldMarkPreviouslySavedObjectAsModifiedWhenMakingChanges {
    AXObject *object = [AXObject create:@"foobar" properties:@{@"foo":@"bar"}];
    __block __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/objects/foobar"] &&
                [request.HTTPMethod isEqualToString:@"POST"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:200 headers:nil];
    }];
    
    [object save:^(NSError *err) {
        [exp1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        object[@"foo"] = @"baz";
        XCTAssertEqual(object.status, AXObjectStatusModified);
    }];
}

- (void)testShouldSaveAllObjectsBeforeCallingCompletionHandler {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block int postCallCount = 0;
    __block NSTimeInterval responseTime = 0.1;
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/objects/testobjects"] &&
                [request.HTTPMethod isEqualToString:@"POST"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        responseTime += 0.1;
        postCallCount++;
        return [[OHHTTPStubsResponse responseWithJSONObject:@{}
                                                 statusCode:200 headers:nil] requestTime:0.5 responseTime:responseTime];
    }];
    
    AXObject *object1 = [AXObject create:@"testobjects"];
    AXObject *object2 = [AXObject create:@"testobjects"];
    AXObject *object3 = [AXObject create:@"testobjects"];
    
    __block int completionCallCount = 0;
    [AXObject saveObjects:@[object1, object2, object3]
               completion:^(NSError *error) {
                   completionCallCount++;
                   [exp1 fulfill];
               }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqual(3, postCallCount);
        XCTAssertEqual(1, completionCallCount);
        XCTAssertEqual(object1.status, AXObjectStatusSaved);
        XCTAssertEqual(object2.status, AXObjectStatusSaved);
        XCTAssertEqual(object3.status, AXObjectStatusSaved);
    }];
}

- (void)testShouldDeleteObject {
    __block __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL path] isEqualToString:@"/objects/testobjects/4321"] &&
                [request.HTTPMethod isEqualToString:@"DELETE"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                 statusCode:200 headers:nil];
    }];
    
    AXObject *object = [AXObject create:@"testobjects" properties:@{@"sysObjectId":@"4321"}];
    [object remove:^(NSError *error){
        XCTAssertNil(error);
        [exp1 fulfill];
    }];
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {}];
}

- (void)testShouldRefreshAPreviouslyLoadedObject {
    __block __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block AXObject *object = [AXObject create:@"foo" properties:@{@"sysObjectId":@"1234", @"bar":@"baz"}];
    
    [AXStubs method:@"GET" urlPath:@"/objects/foo/1234" responding:^OHHTTPStubsResponse *(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"sysObjectId":@"1234", @"bar":@"bazz"}
                                                statusCode:200 headers:nil];
    }];
    
    [object refresh:^(NSError *error) {
        [exp1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqualObjects(object[@"bar"], @"bazz");
    }];
}

- (void)testShouldNotCallServerIfRefreshingANewlyCreatedObject {
    __block __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block AXObject *loaded = [AXObject create:@"foo" properties:@{@"bar":@"baz"}];
    __block BOOL serverCalled = NO;
    
    [loaded refresh:^(NSError *error) {
        [exp1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertFalse(serverCalled);
    }];
}

#pragma mark - Queries

- (void)testShouldSendQueryStringInFilterParameter {
    __block __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block NSString *filterParameter;
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL pathComponents][1] isEqualToString:@"objects"] &&
                [request.HTTPMethod isEqualToString:@"GET"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        filterParameter = [self valueOfParameter:@"filter" inUrl:request.URL];
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:200 headers:nil];
    }];
    
    [AXObject find:@"Friends"
       queryString:@"Name like '%Jo%' and Gender='Female'"
        completion:^(NSArray *objects, NSError *error) {
        [exp1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqualObjects(filterParameter, @"Name+like+%27%25Jo%25%27+and+Gender%3D%27Female%27");
    }];
}

- (void)testShouldReturnQueriedObjectsAsAXObjectInstances {
    __block __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL pathComponents][1] isEqualToString:@"objects"] &&
        [request.HTTPMethod isEqualToString:@"GET"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSDictionary *response = @{@"objects":@[@{@"sysObjectId":@"1234",@"foo":@"bar"},@{@"sysObjectId":@"5678",@"baz":@"gaz"}]};;
        return [OHHTTPStubsResponse responseWithJSONObject:response
                                                statusCode:200 headers:nil];
    }];
    
    [AXObject find:@"myobjects"
       queryString:@"foo='bar'"
        completion:^(NSArray *objects, NSError *error) {
            XCTAssertEqual(2, objects.count);
            AXObject *object1 = objects[0];
            AXObject *object2 = objects[1];
            XCTAssertTrue([object1 isKindOfClass:[AXObject class]]);
            XCTAssertTrue([object2 isKindOfClass:[AXObject class]]);
            XCTAssertEqualObjects(object1.collectionName, @"myobjects");
            XCTAssertEqualObjects(object1.collectionName, @"myobjects");
            XCTAssertEqualObjects(object1[@"foo"], @"bar");
            XCTAssertEqualObjects(object2[@"baz"], @"gaz");
            XCTAssertEqualObjects(object1.objectID, @"1234");
            XCTAssertEqualObjects(object2.objectID, @"5678");
            XCTAssertEqual(object1.status, AXObjectStatusSaved);
            XCTAssertEqual(object2.status, AXObjectStatusSaved);
            [exp1 fulfill];
        }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {}];
}

- (void)testShouldReturnErrorWhenQueryRequestFails {
    __block __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL pathComponents][1] isEqualToString:@"objects"] &&
        [request.HTTPMethod isEqualToString:@"GET"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:500 headers:nil];
    }];
    
    __block NSError *queryError;
    [AXObject find:@"Friends"
       queryString:@"Name like '%Jo%' and Gender='Female'"
        completion:^(NSArray *objects, NSError *error) {
            queryError = error;
            [exp1 fulfill];
        }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertNotNil(queryError);
    }];
}

- (void)testShouldSendQueryBlockInFilterParameter {
    __block __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block NSString *filterParameter;
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL pathComponents][1] isEqualToString:@"objects"] &&
        [request.HTTPMethod isEqualToString:@"GET"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        filterParameter = [self valueOfParameter:@"filter" inUrl:request.URL];
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:200 headers:nil];
    }];
    
    [AXObject find:@"Friends" query:^(AXQuery *query) {
        [query string:@"Name" contains:@"lex"];
        [query string:@"Gender" equals:@"Male"];
    } completion:^(NSArray *objects, NSError *error) {
        [exp1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqualObjects(filterParameter, @"Name+like+%27%25lex%25%27+and+Gender%3D%27Male%27");
    }];
}

- (void)testShouldSendPropertyQueryInFilterParameter {
    __block __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block NSString *filterParameter;
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL pathComponents][1] isEqualToString:@"objects"] &&
        [request.HTTPMethod isEqualToString:@"GET"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        filterParameter = [self valueOfParameter:@"filter" inUrl:request.URL];
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:200 headers:nil];
    }];
    
    [AXObject find:@"Friends"
              with:@{@"Gender":@"Female",
                     @"Hometown":@"New York"}
        completion:^(NSArray *objects, NSError *error) {
            [exp1 fulfill];
        }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqualObjects(filterParameter, @"Gender%3D%27Female%27+and+Hometown%3D%27New+York%27");
    }];
}

- (void)testShouldSendPropertySearchInFilterParameter {
    __block __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block NSString *filterParameter;
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL pathComponents][1] isEqualToString:@"objects"] &&
        [request.HTTPMethod isEqualToString:@"GET"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        filterParameter = [self valueOfParameter:@"filter" inUrl:request.URL];
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:200 headers:nil];
    }];
    
    [AXObject find:@"Notes"
            search:@{@"Title":@"music",
                     @"Content":@"music"}
        completion:^(NSArray *objects, NSError *error) {
            [exp1 fulfill];
        }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqualObjects(filterParameter, @"Title+like+%27%25music%25%27+or+Content+like+%27%25music%25%27");
    }];
}

- (void)testShouldSendMultiPropertySearchInFilterParameter {
    __block __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block NSString *filterParameter;
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL pathComponents][1] isEqualToString:@"objects"] &&
        [request.HTTPMethod isEqualToString:@"GET"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        filterParameter = [self valueOfParameter:@"filter" inUrl:request.URL];
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:200 headers:nil];
    }];
    
    [AXObject find:@"Recipes"
            search:@"burger"
        properties:@[@"Title",@"Description",@"Tags"]
        completion:^(NSArray *objects, NSError *error) {
            [exp1 fulfill];
        }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqualObjects(filterParameter, @"Title+like+%27%25burger%25%27+or+Tags+like+%27%25burger%25%27+or+Description+like+%27%25burger%25%27");
    }];
}

- (void)testShouldNotUsePagingForQueries {
    __block int calls = 0;
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [[request.URL pathComponents][1] isEqualToString:@"objects"] &&
                [request.URL query] != nil &&
                [request.HTTPMethod isEqualToString:@"GET"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        AXAssertNotContains([request.URL query], @"paging=yes");
        AXAssertNotContains([request.URL query], @"pagenum=0");
        calls++;
        if(calls == 4) {
            [exp1 fulfill];
        }
        return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                statusCode:200 headers:nil];
    }];
    
    [AXObject find:@"foo1" queryString:@"zoo='boo'" completion:nil];
    [AXObject find:@"foo2" search:@{@"zoo":@"boo"} completion:nil];
    [AXObject find:@"foo3" search:@"boo" properties:@[@"zoo"] completion:nil];
    [AXObject find:@"foo4" query:^(AXQuery *query) {
        [query string:@"zoo" equals:@"boo"];
    } completion:nil];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {}];
}

@end
