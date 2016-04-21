

#import <XCTest/XCTest.h>
@import Appstax;
#import "AppstaxInternals.h"
#import "AXAsssertions.h"
#import "OHHTTPStubs.h"
#import "OHHTTPStubsResponse+JSON.h"
#import "AXStubs.h"
#import <mach/mach.h>

@interface AXFileTests : XCTestCase
@property AXApiClient *apiClient;
@end

@implementation AXFileTests

- (void)setUp {
    [super setUp];
    [OHHTTPStubs setEnabled:YES];
    [Appstax setAppKey:@"test-api-key" baseUrl:@"http://localhost:3000/"];
    [Appstax setLogLevel:@"trace"];
    _apiClient = [[Appstax defaultContext] apiClient];
}

- (void)tearDown {
    [OHHTTPStubs removeAllStubs];
    [super tearDown];
}

#pragma mark - Helpers

- (UIImage *)imageNamed:(NSString *)name {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:name ofType:nil];
    UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
    return image;
}

- (unsigned long)memoryInUse {
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(),
                                   TASK_BASIC_INFO,
                                   (task_info_t)&info,
                                   &size);
    if(kerr == KERN_SUCCESS) {
        return info.resident_size;
    } else {
        return 0;
    }
}

#pragma mark - Tests

- (void)testShouldCreateFileWithNameAndData {
    NSData *fileData = [@"Doh!" dataUsingEncoding:NSUTF8StringEncoding];
    AXFile *file = [AXFile fileWithData:fileData name:@"textfile.txt"];
    
    XCTAssertEqualObjects(@"textfile.txt", file.filename);
    XCTAssertEqualObjects(@"Doh!", [[NSString alloc] initWithData:file.data encoding:NSUTF8StringEncoding]);
    XCTAssertEqual(file.status, AXFileStatusNew);
}

- (void)testShouldCreateFileFromPngUIImage {
    UIImage *image = [self imageNamed:@"safari.png"];
    AXFile *file = [AXFile fileWithImage:image name:@"safari.png"];
    XCTAssertTrue([file.data isEqualToData:UIImagePNGRepresentation(image)]);
    XCTAssertEqual(file.status, AXFileStatusNew);
}

- (void)testShouldDetermineMimeTypeFromFileName {
    XCTAssertEqualObjects(@"text/plain", [AXFile fileWithData:nil name:@"file.txt"].mimeType);
    XCTAssertEqualObjects(@"text/html",  [AXFile fileWithData:nil name:@"file.html"].mimeType);
    XCTAssertEqualObjects(@"text/html",  [AXFile fileWithData:nil name:@"file.htm"].mimeType);
    XCTAssertEqualObjects(@"image/png",  [AXFile fileWithData:nil name:@"file.png"].mimeType);
    XCTAssertEqualObjects(@"image/gif",  [AXFile fileWithData:nil name:@"file.gif"].mimeType);
    XCTAssertEqualObjects(@"image/jpeg", [AXFile fileWithData:nil name:@"file.jpg"].mimeType);
    XCTAssertEqualObjects(@"image/jpeg", [AXFile fileWithData:nil name:@"file.jpeg"].mimeType);
}

- (void)testShouldHaveDefaultMimeTypeForMissingOrUnknownFileExtensions {
    XCTAssertEqualObjects(@"application/octet-stream", [AXFile fileWithData:nil name:@"file"].mimeType);
    XCTAssertEqualObjects(@"application/octet-stream", [AXFile fileWithData:nil name:@"file.foo"].mimeType);    
}

- (void)testShouldStoreFilePropertiesInObjects {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block NSString *postData;

    [AXStubs method:@"POST"
            urlPath:@"/objects/messages"
         responding:^OHHTTPStubsResponse *(NSURLRequest *request) {
             NSData *httpBody = [NSURLProtocol propertyForKey:@"HTTPBody" inRequest:request];
             postData = [[NSString alloc] initWithData:httpBody encoding:NSUTF8StringEncoding];
             return [OHHTTPStubsResponse responseWithJSONObject:@{@"sysObjectId":@"objid"}
                                                     statusCode:200 headers:nil];
         }];
    
    NSData *fileData = [@"Test!" dataUsingEncoding:NSUTF8StringEncoding];
    AXFile *file = [AXFile fileWithData:fileData name:@"test.txt"];
    AXObject *object = [AXObject create:@"messages"];
    object[@"title"] = @"The title!";
    object[@"attachment"] = file;
    [object save:^(NSError *error) {
        [exp1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        AXAssertContains(postData, @"\"title\":\"The title!\"");
        AXAssertContains(postData, @"\"filename\":\"test.txt\"");
        AXAssertContains(postData, @"\"sysDatatype\":\"file\"");
    }];
}

- (void)testShouldMultipartPostObjectWithFilesAndUpdateStatusWhileSaving {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block NSString *postBody;
    __block NSDictionary *postHeaders;
    __block NSData *fileData1 = [@"The attachment1 content" dataUsingEncoding:NSUTF8StringEncoding];
    __block NSData *fileData2 = [@"The attachment2 content" dataUsingEncoding:NSUTF8StringEncoding];
    __block AXFile *file1 = [AXFile fileWithData:fileData1 name:@"text.txt"];
    __block AXFile *file2 = [AXFile fileWithData:fileData2 name:@"picture.png"];
    __block AXFileStatus status1WhileSavingObject;
    __block AXFileStatus status2WhileSavingObject;
    __block BOOL file1PutFound = NO;
    __block BOOL file2PutFound = NO;
    
    [AXStubs method:@"POST"
            urlPath:@"/objects/messages"
         responding:^OHHTTPStubsResponse *(NSURLRequest *request) {
             status1WhileSavingObject = file1.status;
             status2WhileSavingObject = file2.status;
             NSData *body = [NSURLProtocol propertyForKey:@"HTTPBody" inRequest:request];
             postBody = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
             postHeaders = [NSDictionary dictionaryWithDictionary:request.allHTTPHeaderFields];
             return [OHHTTPStubsResponse responseWithJSONObject:@{@"sysObjectId":@"id1234"}
                                                     statusCode:200 headers:nil];
         }];
    
    [AXStubs method:@"PUT"
            urlPath:@"/files/messages/id1234/attachment1/text.txt"
         responding:^OHHTTPStubsResponse *(NSURLRequest *request) {
             file1PutFound = YES;
             return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                     statusCode:200 headers:nil];
         }];
    
    [AXStubs method:@"PUT"
            urlPath:@"/files/messages/id1234/attachment2/picture.png"
         responding:^OHHTTPStubsResponse *(NSURLRequest *request) {
             file2PutFound = YES;
             return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                     statusCode:200 headers:nil];
         }];
    
    AXObject *object = [AXObject create:@"messages"];
    object[@"title"] = @"The title!";
    object[@"attachment1"] = file1;
    object[@"attachment2"] = file2;
    [object save:^(NSError *error) {
        [exp1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        AXAssertContains(postHeaders[@"Content-Type"], @"multipart/form-data; boundary=");
        AXAssertContains(postBody, @"Content-Disposition: form-data; name=\"attachment1\"; filename=\"text.txt\"");
        AXAssertContains(postBody, @"Content-Disposition: form-data; name=\"attachment2\"; filename=\"picture.png\"");
        AXAssertContains(postBody, @"Content-Type: text/plain");
        AXAssertContains(postBody, @"Content-Type: image/png");
        AXAssertContains(postBody, @"The attachment1 content");
        AXAssertContains(postBody, @"The attachment2 content");
        XCTAssertEqual(status1WhileSavingObject, AXFileStatusSaving);
        XCTAssertEqual(status2WhileSavingObject, AXFileStatusSaving);
        XCTAssertEqual(file1.status, AXFileStatusSaved);
        XCTAssertEqual(file2.status, AXFileStatusSaved);
        XCTAssertFalse(file1PutFound);
        XCTAssertFalse(file2PutFound);
    }];
}

- (void)testFileShouldHaveUrlAfterSaving {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [AXStubs method:@"POST" urlPath:@"/objects/notes"
           response:@{@"sysObjectId":@"id1234"} statusCode:200];
    
    AXObject *object = [AXObject create:@"notes"];
    AXFile *file1 = [AXFile fileWithData:[NSData data] name:@"text.txt"];
    AXFile *file2 = [AXFile fileWithData:[NSData data] name:@"picture.png"];
    object[@"title"] = @"The title!";
    object[@"attachment1"] = file1;
    object[@"attachment2"] = file2;
    [object save:^(NSError *error) {
        [exp1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertEqualObjects(file1.url.absoluteString, @"http://localhost:3000/files/notes/id1234/attachment1/text.txt");
        XCTAssertEqualObjects(file2.url.absoluteString, @"http://localhost:3000/files/notes/id1234/attachment2/picture.png");
    }];
}

- (void)testShouldCreateFilesWhenLoadingExistingObject {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    
    [AXStubs method:@"GET" urlPath:@"/objects/notes"
           response:@{@"objects":@[@{@"sysObjectId":@"1001",
                                     @"prop1": @{@"sysDatatype":@"file",
                                                 @"url":@"/files/notes/1001/prop1/name1.ext",
                                                 @"filename":@"name1.ext"},
                                     @"prop2": @{@"sysDatatype":@"file",
                                                 @"url":@"/files/notes/1001/prop2/name2.ext",
                                                 @"filename":@"name2.ext"}},
                                   @{@"sysObjectId":@"1002",
                                     @"prop1": @{@"sysDatatype":@"file",
                                                 @"url":@"/files/notes/1002/prop1/name3.ext",
                                                 @"filename":@"name3.ext"},
                                     @"prop2": @{@"sysDatatype":@"file",
                                                 @"url":@"/files/notes/1002/prop2/name4.ext",
                                                 @"filename":@"name4.ext"}}
                                   ]} statusCode:200];
    
    __block AXFile *file1;
    __block AXFile *file2;
    __block AXFile *file3;
    __block AXFile *file4;
    [AXObject findAll:@"notes" completion:^(NSArray *objects, NSError *error) {
        file1 = objects[0][@"prop1"];
        file2 = objects[0][@"prop2"];
        file3 = objects[1][@"prop1"];
        file4 = objects[1][@"prop2"];
        [exp1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertTrue([file1 isKindOfClass:[AXFile class]]);
        XCTAssertTrue([file2 isKindOfClass:[AXFile class]]);
        XCTAssertTrue([file3 isKindOfClass:[AXFile class]]);
        XCTAssertTrue([file4 isKindOfClass:[AXFile class]]);
        XCTAssertEqualObjects(file1.url.absoluteString, @"http://localhost:3000/files/notes/1001/prop1/name1.ext");
        XCTAssertEqualObjects(file2.url.absoluteString, @"http://localhost:3000/files/notes/1001/prop2/name2.ext");
        XCTAssertEqualObjects(file3.url.absoluteString, @"http://localhost:3000/files/notes/1002/prop1/name3.ext");
        XCTAssertEqualObjects(file4.url.absoluteString, @"http://localhost:3000/files/notes/1002/prop2/name4.ext");
        XCTAssertEqualObjects(file1.filename, @"name1.ext");
        XCTAssertEqualObjects(file2.filename, @"name2.ext");
        XCTAssertEqualObjects(file3.filename, @"name3.ext");
        XCTAssertEqualObjects(file4.filename, @"name4.ext");
        XCTAssertEqual(file1.status, AXFileStatusSaved);
        XCTAssertEqual(file2.status, AXFileStatusSaved);
        XCTAssertEqual(file3.status, AXFileStatusSaved);
        XCTAssertEqual(file4.status, AXFileStatusSaved);
    }];
}

- (void)testShouldNotSaveUnchangedFilesWhenSavingChangedObject {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block BOOL objectRequestFound = NO;
    __block BOOL fileRequestFound = NO;
    
    [AXStubs method:@"GET" urlPath:@"/objects/notes/001"
           response:@{@"sysObjectId":@"001",
                      @"title": @"hello",
                      @"file": @{@"sysDatatype":@"file",
                                 @"url":@"/files/1",
                                 @"filename":@"name1"}} statusCode:200];
    
    [AXStubs method:@"PUT"
            urlPath:@"/objects/notes/001"
         responding:^OHHTTPStubsResponse *(NSURLRequest *request) {
             objectRequestFound = YES;
             return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                     statusCode:200 headers:nil];
         }];
    
    [AXStubs method:@"PUT"
            urlPath:@"/files/notes/001/file/name1"
         responding:^OHHTTPStubsResponse *(NSURLRequest *request) {
             fileRequestFound = YES;
             return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                     statusCode:200 headers:nil];
         }];
    
    [AXObject find:@"notes" withId:@"001" completion:^(AXObject *object, NSError *error) {
        object[@"title"] = @"hello2";
        [object save:^(NSError *error) {
            [exp1 fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertTrue(objectRequestFound);
        XCTAssertFalse(fileRequestFound);
    }];
}

- (void)testShouldSaveChangedFilesAndUpdateStatusWhenSavingOtherwiseUnchangedObject {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block BOOL objectRequestFound = NO;
    __block BOOL fileRequestFound = NO;
    __block AXFile *file = [AXFile fileWithData:[NSData data] name:@"name1"];
    __block AXFileStatus statusWhileSavingObject;
    __block AXFileStatus statusWhileSavingFile;
    
    [AXStubs method:@"GET" urlPath:@"/objects/notes/001"
           response:@{@"sysObjectId":@"001",
                      @"title": @"hello",
                      @"file": @{@"sysDatatype":@"file",
                                 @"url":@"/files/1",
                                 @"filename":@"name1"}} statusCode:200];
    
    [AXStubs method:@"PUT"
            urlPath:@"/objects/notes/001"
         responding:^OHHTTPStubsResponse *(NSURLRequest *request) {
             objectRequestFound = YES;
             statusWhileSavingObject = file.status;
             return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                     statusCode:200 headers:nil];
         }];
    
    [AXStubs method:@"PUT"
            urlPath:@"/files/notes/001/file/name1"
         responding:^OHHTTPStubsResponse *(NSURLRequest *request) {
             fileRequestFound = YES;
             statusWhileSavingFile = file.status;
             return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                     statusCode:200 headers:nil];
         }];
    
    [AXObject find:@"notes" withId:@"001" completion:^(AXObject *object, NSError *error) {
        object[@"file"] = file;
        [object save:^(NSError *error) {
            [exp1 fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertTrue(objectRequestFound);
        XCTAssertTrue(fileRequestFound);
        XCTAssertEqual(statusWhileSavingObject, AXFileStatusNew);
        XCTAssertEqual(statusWhileSavingFile, AXFileStatusSaving);
        XCTAssertEqual(file.status, AXFileStatusSaved);
    }];
}

- (void)testShouldCreateAndSaveFileFromPathWithoutKeepingDataIntoMemory {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block NSData *filePutBody;
    
    [AXStubs method:@"PUT"
            urlPath:@"/objects/profiles/id1234"
         responding:^OHHTTPStubsResponse *(NSURLRequest *request) {
             return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                     statusCode:200 headers:nil];
         }];
    
    [AXStubs method:@"PUT"
            urlPath:@"/files/profiles/id1234/background/clouds.jpg"
         responding:^OHHTTPStubsResponse *(NSURLRequest *request) {
             filePutBody = [NSURLProtocol propertyForKey:@"HTTPBody" inRequest:request];
             return [OHHTTPStubsResponse responseWithJSONObject:@{}
                                                     statusCode:200 headers:nil];
         }];
    
    //unsigned long memoryBefore = [self memoryInUse];
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"clouds" ofType:@"jpg"];
    AXFile *file = [AXFile fileWithPath:path];
    
    AXObject *profile = [AXObject create:@"profiles" properties:@{@"sysObjectId":@"id1234"}];
    profile[@"background"] = file;
    [profile save:^(NSError *error) {
        [exp1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        //unsigned long memoryAfter = [self memoryInUse];
        XCTAssertEqualObjects(file.dataPath, path);
        XCTAssertNil(file.data);
        XCTAssertGreaterThan(filePutBody.length, [NSData dataWithContentsOfFile:path].length);
        // TODO: Find way to check that data is not retained
        // XCTAssertLessThan(memoryAfter, memoryBefore + 10000);
    }];
}

- (void)testShouldLoadFileDataOnRequest {
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block NSData *realFileData = [NSData dataWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"clouds" ofType:@"jpg"]];
    __block NSData *fileDataAfterObjectLoad = nil;
    __block NSData *fileDataAfterFileLoad = nil;
    
    [AXStubs method:@"GET" urlPath:@"/objects/notes/001"
           response:@{@"sysObjectId":@"001",
                      @"title": @"hello",
                      @"attachment": @{@"sysDatatype":@"file",
                                       @"url":@"/files/notes/001/attachment/clouds.jpg",
                                       @"filename":@"clouds.jpg"}} statusCode:200];
    
    [AXStubs method:@"GET"
            urlPath:@"/files/notes/001/attachment/clouds.jpg"
         responding:^OHHTTPStubsResponse *(NSURLRequest *request) {
             return [OHHTTPStubsResponse responseWithData:realFileData statusCode:200 headers:@{}];
         }];
    
    [AXObject find:@"notes" withId:@"001" completion:^(AXObject *object, NSError *error) {
        AXFile *attachment = object[@"attachment"];
        fileDataAfterObjectLoad = attachment.data;
        
        [attachment load:^(NSError *error) {
            fileDataAfterFileLoad = attachment.data;
            [exp1 fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:3 handler:^(NSError *error) {
        XCTAssertNil(fileDataAfterObjectLoad);
        XCTAssertNotNil(fileDataAfterFileLoad);
        XCTAssertTrue([fileDataAfterFileLoad isEqualToData:realFileData]);
    }];
}

- (void)testShouldUnloadFileData {
    AXFile *file = [AXFile fileWithData:[NSData data] name:@"test.dat"];
    XCTAssertNotNil(file.data);
    [file unload];
    XCTAssertNil(file.data);
}

- (void)testShouldLoadResizedImage {
    __block int exp1Count = 0;
    __block XCTestExpectation *exp1 = [self expectationWithDescription:@"async1"];
    __block XCTestExpectation *exp2 = [self expectationWithDescription:@"async2"];
    __block NSMutableArray *imageRequests = [NSMutableArray array];
    __block NSData *fileData = [NSData dataWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"clouds" ofType:@"jpg"]];
    __block AXFile *file;
    
    [AXStubs method:@"GET" urlPath:@"/objects/notes/001"
           response:@{@"sysObjectId":@"001",
                      @"title": @"hello",
                      @"attachment": @{@"sysDatatype":@"file",
                                       @"url":@"/files/notes/001/attachment/clouds.jpg",
                                       @"filename":@"clouds.jpg"}} statusCode:200];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.pathComponents[1] isEqualToString:@"images"];
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        [imageRequests addObject:request];
        exp1Count++;
        if(exp1Count == 6) {
            [exp1 fulfill];
        }
        return [OHHTTPStubsResponse responseWithData:fileData statusCode:200 headers:@{}];
    }];
    
    [AXObject find:@"notes" withId:@"001" completion:^(AXObject *object, NSError *error) {
        file = object[@"attachment"];
        [file loadImageSize:CGSizeMake(200,   0) crop:NO  completion:nil];
        [NSThread sleepForTimeInterval:0.2];
        [file loadImageSize:CGSizeMake(  0, 300) crop:NO  completion:nil];
        [NSThread sleepForTimeInterval:0.2];
        [file loadImageSize:CGSizeMake(400, 500) crop:NO  completion:nil];
        [NSThread sleepForTimeInterval:0.2];
        [file loadImageSize:CGSizeMake(200,   0) crop:YES completion:nil];
        [NSThread sleepForTimeInterval:0.2];
        [file loadImageSize:CGSizeMake(  0, 300) crop:YES completion:nil];
        [NSThread sleepForTimeInterval:0.2];
        [file loadImageSize:CGSizeMake(400, 500) crop:YES completion:^(NSError *error) {
            [exp2 fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
        XCTAssertNotNil(file.data);
        XCTAssertTrue([file.data isEqualToData:fileData]);
        XCTAssertEqualObjects(@"http://localhost:3000/images/resize/200/-/notes/001/attachment/clouds.jpg", ((NSURLRequest *)imageRequests[0]).URL.absoluteString);
        XCTAssertEqualObjects(@"http://localhost:3000/images/resize/-/300/notes/001/attachment/clouds.jpg", ((NSURLRequest *)imageRequests[1]).URL.absoluteString);
        XCTAssertEqualObjects(@"http://localhost:3000/images/resize/400/500/notes/001/attachment/clouds.jpg", ((NSURLRequest *)imageRequests[2]).URL.absoluteString);
        XCTAssertEqualObjects(@"http://localhost:3000/images/crop/200/-/notes/001/attachment/clouds.jpg", ((NSURLRequest *)imageRequests[3]).URL.absoluteString);
        XCTAssertEqualObjects(@"http://localhost:3000/images/crop/-/300/notes/001/attachment/clouds.jpg", ((NSURLRequest *)imageRequests[4]).URL.absoluteString);
        XCTAssertEqualObjects(@"http://localhost:3000/images/crop/400/500/notes/001/attachment/clouds.jpg", ((NSURLRequest *)imageRequests[5]).URL.absoluteString);
    }];

}

@end
