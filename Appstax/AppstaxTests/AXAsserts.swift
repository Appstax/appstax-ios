
import Foundation
import XCTest

func AXAssertNotNil(optional: AnyObject?, file: String = __FILE__, line: UInt = __LINE__, handler: (() -> ())? = nil) {
    AXAssertAllNotNil([optional], file: file, line:line, handler: handler)
}

func AXAssertNil(optional: AnyObject?, file: String = __FILE__, line: UInt = __LINE__, handler: (() -> ())? = nil) {
    AXAssertAllNil([optional], file: file, line:line, handler: handler)
}

func AXAssertAllNotNil(optionals: [AnyObject?], file: String = __FILE__, line: UInt = __LINE__, handler: (() -> ())? = nil) {
    
    var ok = true
    for optional in optionals {
        if let o: AnyObject = optional {
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

func AXAssertAllNil(optionals: [AnyObject?], file: String = __FILE__, line: UInt = __LINE__, handler: (() -> ())? = nil) {
    
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

func AXAssertEqual(o1: AnyObject?, o2: AnyObject?, file: String = __FILE__, line: UInt = __LINE__, handler: (() -> ())? = nil) {
    
    if let a1 = o1 as? NSObject {
        if let a2 = o2 as? NSObject {
            XCTAssertEqual(a1, a2, file: file, line: line)
            return
        }
    }
    XCTFail("Error comparing objects", file: file, line: line)
}

func AXAssertContains(haystack: [String]?, needle: String?, file: String = __FILE__, line: UInt = __LINE__, handler: (() -> ())? = nil) {
    for item in haystack ?? [] {
        if needle == item {
            return
        }
    }
    XCTFail("Did not find \(needle) in \(haystack)", file: file, line: line)
}

func AXAssertNotContains(haystack: [String]?, needle: String?, file: String = __FILE__, line: UInt = __LINE__, handler: (() -> ())? = nil) {
    for item in haystack ?? [] {
        if needle == item {
            XCTFail("Found unexpected \(needle) in \(haystack)", file: file, line: line)
        }
    }
}

func AXAssertStringNotContains(haystack: String?, needle: String?, file: String = __FILE__, line: UInt = __LINE__, handler: (() -> ())? = nil) {
    if needle == nil {
        return
    }
    if haystack?.rangeOfString(needle!) != nil {
        XCTFail("Found unexpected \(needle) in \(haystack)", file: file, line: line)
    }
}

func AXAssertStringContains(haystack: String?, needle: String, file: String = __FILE__, line: UInt = __LINE__, handler: (() -> ())? = nil) {
    if haystack?.rangeOfString(needle) == nil {
        XCTFail("Did not find \(needle) in \(haystack)", file: file, line: line)
    }
}