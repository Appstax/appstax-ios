
#import <XCTest/XCTest.h>
@import Appstax;
#import "AXAsssertions.h"
#import "OHHTTPStubs.h"
#import "OHHTTPStubsResponse+JSON.h"

@interface AXJsonApiClientTests : XCTestCase
@property AXApiClient *apiClient;
@end

@implementation AXJsonApiClientTests

- (void)setUp {
    [super setUp];
    _apiClient = [[AXApiClient alloc] initWithAppKey:@"appkey" baseUrl:@"http://mybaseurl:1337/base/path/"];
}

- (void)tearDown {
    [OHHTTPStubs removeAllStubs];
    [super tearDown];
}

- (void)testShouldBuildUrlsWithBaseUrl {
    NSURL *url = [_apiClient urlByConcatenatingStrings:@[@"resource/", @"1002"]];
    XCTAssertEqualObjects([url absoluteString], @"http://mybaseurl:1337/base/path/resource/1002");
}

- (void)testShouldBuildUrlsWithTemplates {
    NSURL *url = [_apiClient urlFromTemplate:@"/resource/:id" parameters:@{@"id":@"1002"} queryParameters:@{}];
    XCTAssertEqualObjects([url absoluteString], @"http://mybaseurl:1337/base/path/resource/1002");
}

- (void)testShoulUrlEncodeParametersForTemplates {
    NSURL *url = [_apiClient urlFromTemplate:@"/objects/:collection?filter=:filter"
                                  parameters:@{@"collection":@"Møbler",
                                               @"filter":@"Navn='%tärnö%'"}
                             queryParameters:@{}];
    XCTAssertEqualObjects([url absoluteString],
                          @"http://mybaseurl:1337/base/path/objects/M%C3%B8bler?filter=Navn%3D%27%25t%C3%A4rn%C3%B6%25%27");
}

- (void)testShouldAppendQueryParameters {
    NSURL *url = [_apiClient urlFromTemplate:@"/hello/:who"
                                  parameters:@{@"who":@"world"}
                             queryParameters:@{@"knock":@"true"}];
    XCTAssertEqualObjects([url absoluteString], @"http://mybaseurl:1337/base/path/hello/world?knock=true");
}

- (void)testShouldAppendQueryParametersToExistingQuery {
    NSURL *url = [_apiClient urlFromTemplate:@"/hello/:who?woods=yes"
                                  parameters:@{@"who":@"world"}
                             queryParameters:@{@"knock":@"true"}];
    XCTAssertEqualObjects([url absoluteString], @"http://mybaseurl:1337/base/path/hello/world?woods=yes&knock=true");
}

- (void)testShouldEncodeQueryParameters {
    NSURL *url = [_apiClient urlFromTemplate:@"/hello"
                                  parameters:@{}
                             queryParameters:@{@"who":@"w ø r l d"}];
    XCTAssertEqualObjects([url absoluteString], @"http://mybaseurl:1337/base/path/hello?who=w%20%C3%B8%20r%20l%20d");
}

- (void)testShouldStorePostBodyInRequestProperty {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block NSData *httpBody;
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        httpBody = [NSURLProtocol propertyForKey:@"HTTPBody" inRequest:request];
        [exp1 fulfill];
        return nil;
    }];
    
    [_apiClient postDictionary:@{@"prop1":@"value1"}
                         toUrl:[NSURL URLWithString:@"http://example1.com"]
                    completion:nil];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        NSDictionary *bodyDictionary = [NSJSONSerialization JSONObjectWithData:httpBody options:0 error:nil];
        XCTAssertEqualObjects(@"value1", bodyDictionary[@"prop1"]);
    }];
}

- (void)testShouldStorePutBodyInRequestProperty {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block NSData *httpBody;
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        httpBody = [NSURLProtocol propertyForKey:@"HTTPBody" inRequest:request];
        [exp1 fulfill];
        return nil;
    }];
    
    [_apiClient putDictionary:@{@"prop2":@"value2"}
                        toUrl:[NSURL URLWithString:@"http://example2.com"]
                   completion:nil];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        NSDictionary *bodyDictionary = [NSJSONSerialization JSONObjectWithData:httpBody options:0 error:nil];
        XCTAssertEqualObjects(@"value2", bodyDictionary[@"prop2"]);
    }];
}

- (void)testArrayFromUrlShouldReturnErrorForNon2XXResponses {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"errorMessage":@"Foo"}
                                                statusCode:500 headers:nil];
    }];
    
    __block NSError *resultError;
    __block NSArray *resultArray;
    [_apiClient arrayFromUrl:[NSURL URLWithString:@"http://something.com/"]
                  completion:^(NSArray *array, NSError *error) {
                      resultError = error;
                      resultArray = array;
                      [exp1 fulfill];
                  }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertNil(resultArray);
        XCTAssertNotNil(resultError);
        XCTAssertEqualObjects(resultError.userInfo[@"errorMessage"], @"Foo");
    }];
}

- (void)testDictionaryFromUrlShouldReturnErrorForNon2XXResponses {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"errorMessage":@"FooBar"}
                                                statusCode:401 headers:nil];
    }];
    
    __block NSError *resultError;
    __block NSDictionary *resultDictionary;
    [_apiClient dictionaryFromUrl:[NSURL URLWithString:@"http://somethingelse.com/"]
                       completion:^(NSDictionary *dictionary, NSError *error) {
                           resultError = error;
                           resultDictionary = dictionary;
                           [exp1 fulfill];
                       }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertNil(resultDictionary);
        XCTAssertNotNil(resultError);
        XCTAssertEqualObjects(resultError.userInfo[@"errorMessage"], @"FooBar");
    }];
}

- (void)testPostDictionaryToUrlShouldReturnErrorForNon2XXResponses {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"errorMessage":@"WTF"}
                                                statusCode:422 headers:nil];
    }];
    
    __block NSError *resultError;
    __block NSDictionary *resultDictionary;
    [_apiClient postDictionary:@{}
                         toUrl:[NSURL URLWithString:@"http://nothing.com/"]
                    completion:^(NSDictionary *dictionary, NSError *error) {
                        resultError = error;
                        resultDictionary = dictionary;
                        [exp1 fulfill];
                    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertNil(resultDictionary);
        XCTAssertNotNil(resultError);
        XCTAssertEqualObjects(resultError.userInfo[@"errorMessage"], @"WTF");
    }];
}

- (void)testPutDictionaryToUrlShouldReturnErrorForNon2XXResponses {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithJSONObject:@{@"errorMessage":@"rly?"}
                                                statusCode:422 headers:nil];
    }];
    
    __block NSError *resultError;
    __block NSDictionary *resultDictionary;
    [_apiClient putDictionary:@{}
                        toUrl:[NSURL URLWithString:@"http://wut.no/"]
                   completion:^(NSDictionary *dictionary, NSError *error) {
                       resultError = error;
                       resultDictionary = dictionary;
                       [exp1 fulfill];
                   }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertNil(resultDictionary);
        XCTAssertNotNil(resultError);
        XCTAssertEqualObjects(resultError.userInfo[@"errorMessage"], @"rly?");
    }];
}

@end
