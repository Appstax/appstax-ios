
#import <XCTest/XCTest.h>
@import Appstax;
#import "AXQuery.h"
#import "AppstaxInternals.h"

@interface AXQueryTests : XCTestCase
@property AXQuery *query;
@end

@implementation AXQueryTests

- (void)setUp {
    [super setUp];
    [Appstax setAppKey:@"test-api-key" baseUrl:@"http://localhost:3000/"];
    _query = [AXQuery query];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testShouldCreateEmptyQuery {
    XCTAssertEqualObjects(_query.queryString, @"");
}

- (void)testShouldCreateSimpleQueryWithString {
    _query = [[AXQuery alloc] initWithQueryString:@"foo='bar'"];
    XCTAssertEqualObjects(_query.queryString, @"foo='bar'");
}

- (void)testShouldQueryStringEquals {
    [_query string:@"zoo" equals:@"baz"];
    XCTAssertEqualObjects(_query.queryString, @"zoo='baz'");
}

- (void)testShoulQueryStringContains {
    [_query string:@"mooz" contains:@"oo"];
    XCTAssertEqualObjects(_query.queryString, @"mooz like '%oo%'");
}

- (void)testShouldQueryObjectHasRelationForSingleObject {
    AXObject *object = [AXObject create:@"foo" properties:@{@"sysObjectId":@"1234"}];
    [_query relation:@"bar" hasObject:object];
    XCTAssertEqualObjects(_query.queryString, @"bar has ('1234')");
}

- (void)testShouldQueryObjectHasRelationForMultipleObjects {
    AXObject *object1 = [AXObject create:@"foo" properties:@{@"sysObjectId":@"1234"}];
    AXObject *object2 = [AXObject create:@"foo" properties:@{@"sysObjectId":@"5678"}];
    [_query relation:@"bar" hasObjects:@[object1, object2]];
    XCTAssertEqualObjects(_query.queryString, @"bar has ('1234','5678')");
}

- (void)testShoulJoinPredicatesWithAndByDefault {
    [_query string:@"zoo" equals:@"baz"];
    [_query string:@"mooz" contains:@"oo"];
    XCTAssertEqualObjects(_query.queryString, @"zoo='baz' and mooz like '%oo%'");
}

- (void)testShouldJointPredicatesWithOrWhenSpecified {
    [_query string:@"zoo" equals:@"baz"];
    [_query string:@"mooz" contains:@"oo"];
    [_query setLogicalOperator:@"or"];
    XCTAssertEqualObjects(_query.queryString, @"zoo='baz' or mooz like '%oo%'");
}

@end
