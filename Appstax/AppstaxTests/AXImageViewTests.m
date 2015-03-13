
#import <XCTest/XCTest.h>
#import "AppstaxInternals.h"
#import "AXAsssertions.h"
#import "OHHTTPStubs.h"
#import "OHHTTPStubsResponse+JSON.h"
#import "AXStubs.h"
#import <mach/mach.h>

@interface AXImageViewTests : XCTestCase
@property AXJsonApiClient *apiClient;
@end

@implementation AXImageViewTests

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

- (void)testShouldBeSubclassOfUIImageView {
    AXImageView *view = [[AXImageView alloc] init];
    XCTAssertTrue([view isKindOfClass:[UIImageView class]]);
}

- (void)testShouldLoadDataAndSetImageProperty {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block NSData *fileData = [NSData dataWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"safari" ofType:@"png"]];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.pathComponents[1] isEqualToString:@"files"];
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [exp1 fulfill];
        });
        return [OHHTTPStubsResponse responseWithData:fileData statusCode:200 headers:@{}];
    }];
    
    AXImageView *view = [[AXImageView alloc] init];
    XCTAssertNil(view.image);
    AXFile *file = [AXFile fileWithUrl:[NSURL URLWithString:@"http://localhost:3000/files/profiles/image/me.png"] name:@"me" status:AXFileStatusSaved];
    [view loadFile:file];

    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        XCTAssertNotNil(view.image);
        XCTAssertTrue([UIImagePNGRepresentation([UIImage imageWithData:fileData])
                       isEqualToData:UIImagePNGRepresentation(view.image)]);
        XCTAssertNil(file.data);
    }];
}

- (void)testShouldLoadResizedDataAndSetImageProperty {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block NSData *fileData = [NSData dataWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"safari" ofType:@"png"]];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.pathComponents[1] isEqualToString:@"images"];
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [exp1 fulfill];
        });
        return [OHHTTPStubsResponse responseWithData:fileData statusCode:200 headers:@{}];
    }];
    
    AXImageView *view = [[AXImageView alloc] init];
    XCTAssertNil(view.image);
    AXFile *file = [AXFile fileWithUrl:[NSURL URLWithString:@"http://localhost:3000/images/resize/100/-/profiles/image/me.png"] name:@"me" status:AXFileStatusSaved];
    [view loadFile:file size:CGSizeMake(100,0) crop:NO];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
        XCTAssertNotNil(view.image);
        XCTAssertTrue([UIImagePNGRepresentation([UIImage imageWithData:fileData])
                       isEqualToData:UIImagePNGRepresentation(view.image)]);
        XCTAssertNil(file.data);
    }];
}

- (void)testShouldLoadDataAndSetImagePropertyAfterInit {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block NSData *fileData = [NSData dataWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"safari" ofType:@"png"]];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.pathComponents[1] isEqualToString:@"files"];
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [exp1 fulfill];
        });
        return [OHHTTPStubsResponse responseWithData:fileData statusCode:200 headers:@{}];
    }];
    
    AXFile *file = [AXFile fileWithUrl:[NSURL URLWithString:@"http://localhost:3000/files/profiles/image/me.png"] name:@"me" status:AXFileStatusSaved];
    AXImageView *view = [AXImageView viewWithFile:file];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
        XCTAssertNotNil(view.image);
        XCTAssertTrue([UIImagePNGRepresentation([UIImage imageWithData:fileData])
                       isEqualToData:UIImagePNGRepresentation(view.image)]);
        XCTAssertNil(file.data);
    }];
}

- (void)testShouldLoadResizedDataAndSetImagePropertyAfterInit {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block NSData *fileData = [NSData dataWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"safari" ofType:@"png"]];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.pathComponents[1] isEqualToString:@"images"];
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [exp1 fulfill];
        });
        return [OHHTTPStubsResponse responseWithData:fileData statusCode:200 headers:@{}];
    }];
    
    AXFile *file = [AXFile fileWithUrl:[NSURL URLWithString:@"http://localhost:3000/files/profiles/image/me.png"] name:@"me" status:AXFileStatusSaved];
    AXImageView *view = [AXImageView viewWithFile:file size:CGSizeMake(100,0) crop:NO];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        XCTAssertNotNil(view.image);
        XCTAssertTrue([UIImagePNGRepresentation([UIImage imageWithData:fileData])
                       isEqualToData:UIImagePNGRepresentation(view.image)]);
        XCTAssertNil(file.data);
    }];
}

- (void)testShouldLoadLatestFileInRaceConditions {
    __block int exp1Count = 0;
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block NSData *fileData1 = [NSData dataWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"safari" ofType:@"png"]];
    __block NSData *fileData2 = [NSData dataWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"safari_green" ofType:@"png"]];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.pathComponents[1] isEqualToString:@"files"];
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            exp1Count++;
            if(exp1Count == 2) {
                [exp1 fulfill];
            }
        });
        if([request.URL.absoluteString containsString:@"file1.png"]) {
            return [[OHHTTPStubsResponse responseWithData:fileData1 statusCode:200 headers:@{}] requestTime:0 responseTime:3];
        } else {
            return [[OHHTTPStubsResponse responseWithData:fileData2 statusCode:200 headers:@{}] requestTime:0 responseTime:1];
        }
        
    }];
    
    AXImageView *view = [[AXImageView alloc] init];
    XCTAssertNil(view.image);
    AXFile *file1 = [AXFile fileWithUrl:[NSURL URLWithString:@"http://localhost:3000/files/profiles/image/file1.png"] name:@"me" status:AXFileStatusSaved];
    AXFile *file2 = [AXFile fileWithUrl:[NSURL URLWithString:@"http://localhost:3000/files/profiles/image/file2.png"] name:@"me" status:AXFileStatusSaved];
    [view loadFile:file1];
    [view loadFile:file2];
    
    [self waitForExpectationsWithTimeout:15 handler:^(NSError *error) {
        XCTAssertNotNil(view.image);
        XCTAssertTrue([UIImagePNGRepresentation([UIImage imageWithData:fileData2])
                       isEqualToData:UIImagePNGRepresentation(view.image)]);
        XCTAssertNil(file1.data);
        XCTAssertNil(file2.data);
    }];
}

- (void)testShouldLoadLatestResizedImageInRaceConditions {
    __block int exp1Count = 0;
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block NSData *fileData1 = [NSData dataWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"safari" ofType:@"png"]];
    __block NSData *fileData2 = [NSData dataWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"safari_green" ofType:@"png"]];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.pathComponents[1] isEqualToString:@"images"];
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            exp1Count++;
            if(exp1Count == 2) {
                [exp1 fulfill];
            }
        });
        if([request.URL.absoluteString containsString:@"file1.png"]) {
            return [[OHHTTPStubsResponse responseWithData:fileData1 statusCode:200 headers:@{}] requestTime:0 responseTime:3];
        } else {
            return [[OHHTTPStubsResponse responseWithData:fileData2 statusCode:200 headers:@{}] requestTime:0 responseTime:1];
        }
        
    }];
    
    AXImageView *view = [[AXImageView alloc] init];
    XCTAssertNil(view.image);
    AXFile *file1 = [AXFile fileWithUrl:[NSURL URLWithString:@"http://localhost:3000/files/profiles/image/file1.png"] name:@"me" status:AXFileStatusSaved];
    AXFile *file2 = [AXFile fileWithUrl:[NSURL URLWithString:@"http://localhost:3000/files/profiles/image/file2.png"] name:@"me" status:AXFileStatusSaved];
    [view loadFile:file1 size:CGSizeMake(100, 100) crop:YES];
    [view loadFile:file2 size:CGSizeMake(100, 100) crop:YES];
    
    [self waitForExpectationsWithTimeout:15 handler:^(NSError *error) {
        XCTAssertNotNil(view.image);
        XCTAssertTrue([UIImagePNGRepresentation([UIImage imageWithData:fileData2])
                       isEqualToData:UIImagePNGRepresentation(view.image)]);
        XCTAssertNil(file1.data);
        XCTAssertNil(file2.data);
    }];
}

@end
