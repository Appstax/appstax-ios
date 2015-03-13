
#ifndef Appstax_AXAsssertions_h
#define Appstax_AXAsssertions_h

#define AXAssertContains(haystack, needle) XCTAssertNotNil(haystack); XCTAssertFalse([haystack rangeOfString:needle].location == NSNotFound, "String '%@' does not contain string '%@'", haystack, needle)
#define AXAssertNotContains(haystack, needle) XCTAssertNotNil(haystack); XCTAssertTrue([haystack rangeOfString:needle].location == NSNotFound, "String '%@' does not contain string '%@'", haystack, needle)

#endif
