
#import <XCTest/XCTest.h>
#import "AXQuery.h"
#import "AXObject.h"
#import "AppstaxInternals.h"

@interface AXQueryTests : XCTestCase
@property AXQuery *query;
@end

@implementation AXQueryTests

- (void)setUp {
    [super setUp];
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
