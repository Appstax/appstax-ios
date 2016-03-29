
import Foundation
import XCTest

func AXAssertNotNil(optional: AnyObject?, file: StaticString = #file, line: UInt = #line, handler: (() -> ())? = nil) {
    AXAssertAllNotNil([optional], file: file, line:line, handler: handler)
}

func AXAssertNil(optional: AnyObject?, file: StaticString = #file, line: UInt = #line, handler: (() -> ())? = nil) {
    AXAssertAllNil([optional], file: file, line:line, handler: handler)
}

func AXAssertAllNotNil(optionals: [AnyObject?], file: StaticString = #file, line: UInt = #line, handler: (() -> ())? = nil) {
    
    var ok = true
    for optional in optionals {
        if let _: AnyObject = optional {
            //
        } else {
            ok = false
            XCTFail("Unexpected nil", file: file, line: line)
        }
    }
    if ok {
        handler?()
    }
}

func AXAssertAllNil(optionals: [AnyObject?], file: StaticString = #file, line: UInt = #line, handler: (() -> ())? = nil) {
    
    var ok = true
    for optional in optionals {
        if let o: AnyObject = optional {
            ok = false
            XCTFail("Not nil: \(o)", file: file, line: line)
        }
    }
    if ok {
        handler?()
    }
}

func AXAssertEqual(o1: AnyObject?, _ o2: AnyObject?, file: StaticString = #file, line: UInt = #line, handler: (() -> ())? = nil) {
    
    if let a1 = o1 as? NSObject {
        if let a2 = o2 as? NSObject {
            XCTAssertEqual(a1, a2, file: file, line: line)
            return
        }
    }
    XCTFail("\(o1) is not equal to \(o2)", file: file, line: line)
}

func AXAssertContains(haystack: [String]?, needle: String?, file: StaticString = #file, line: UInt = #line, handler: (() -> ())? = nil) {
    for item in haystack ?? [] {
        if needle == item {
            return
        }
    }
    XCTFail("Did not find \(needle) in \(haystack)", file: file, line: line)
}

func AXAssertNotContains(haystack: [String]?, needle: String?, file: StaticString = #file, line: UInt = #line, handler: (() -> ())? = nil) {
    for item in haystack ?? [] {
        if needle == item {
            XCTFail("Found unexpected \(needle) in \(haystack)", file: file, line: line)
        }
    }
}

func AXAssertStringNotContains(haystack: String?, needle: String?, file: StaticString = #file, line: UInt = #line, handler: (() -> ())? = nil) {
    if needle == nil {
        return
    }
    if haystack?.rangeOfString(needle!) != nil {
        XCTFail("Found unexpected \(needle) in \(haystack)", file: file, line: line)
    }
}

func AXAssertStringContains(haystack: String?, needle: String, file: StaticString = #file, line: UInt = #line, handler: (() -> ())? = nil) {
    if haystack?.rangeOfString(needle) == nil {
        XCTFail("Did not find \(needle) in \(haystack)", file: file, line: line)
    }
}

func AXAssertCount(array: AnyObject?, _ count: Int, file: StaticString = #file, line: UInt = #line, handler: (() -> ())? = nil) {
    if let array = array as? [AnyObject] {
        if array.count != count {
            XCTFail("Expected count \(count), found \(array.count)", file: file, line: line)
        }
    } else {
        XCTFail("Expected count \(count), found \(array)", file: file, line: line)
    }
}
