
#import <XCTest/XCTest.h>
#import "AXKeychain.h"

@interface AXKeychainTests : XCTestCase
@property AXKeychain *keychain;
@end

@implementation AXKeychainTests

- (void)setUp {
    [super setUp];
    _keychain = [[AXKeychain alloc] initWithService:@"com.appstax.keychain.test"];
}

- (void)tearDown {
    [super tearDown];
    [_keychain clear];
}

- (void)testShouldKnowValueDoesNotExist {
    XCTAssertFalse([_keychain containsValueForKey:@"foo"]);
    XCTAssertNil(_keychain.error);
    XCTAssertNil(_keychain[@"foo"]);
    XCTAssertNil(_keychain.error);
}

- (void)testShouldStoreValue {
    _keychain[@"zoo"] = @"baz";
    XCTAssertNil(_keychain.error);
    XCTAssertTrue([_keychain containsValueForKey:@"zoo"]);
    XCTAssertNil(_keychain.error);
}

- (void)testShouldGetStoredValue {
    _keychain[@"xoo"] = @"bax";
    XCTAssertEqualObjects(@"bax", _keychain[@"xoo"]);
    XCTAssertNil(_keychain.error);
}

- (void)testShouldRemoveSingleValue {
    _keychain[@"yoo"] = @"bay";
    _keychain[@"woo"] = @"baw";
    XCTAssertTrue([_keychain containsValueForKey:@"yoo"]);
    XCTAssertTrue([_keychain containsValueForKey:@"woo"]);
    
    _keychain[@"yoo"] = nil;
    
    XCTAssertFalse([_keychain containsValueForKey:@"yoo"]);
    XCTAssertNil(_keychain[@"yoo"]);
    
    XCTAssertTrue([_keychain containsValueForKey:@"woo"]);
    XCTAssertEqualObjects(@"baw", _keychain[@"woo"]);
}

- (void)testShouldUpdateExistingValue {
    _keychain[@"moo"] = @"bam";
    _keychain[@"moo"] = @"zam";
    XCTAssertEqualObjects(@"zam", _keychain[@"moo"]);
}

@end
