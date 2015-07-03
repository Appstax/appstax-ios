
import UIKit
import XCTest
import Appstax

class AXObjectAccessorsTests: XCTestCase {

    var object: AXObject?
    
    override func setUp() {
        super.setUp()
        OHHTTPStubs.setEnabled(true)
        OHHTTPStubs.removeAllStubs()
        Appstax.setAppKey("test-api-key", baseUrl:"http://localhost:3000/");
        Appstax.setLogLevel("debug");
        
        object = AXObject.create("message", properties:[
            "sysObjectId": "123",
            "content": "Hello World",
            "value": 1023,
            "tags": ["hello", "world"],
            "image": [
                "sysDatatype": "file",
                "filename": "selfie.jpg"
            ],
            "timeline": [
                "sysDatatype": "relation",
                "sysRelationType": "single",
                "sysCollection": "timelines",
                "sysObjects": [[
                    "sysObjectId": "1234",
                    "title": "My timeline!",
                    "likes": 423,
                    "tags": ["music", "photography"],
                    "background": [
                        "sysDatatype": "file",
                        "filename": "panorama.jpg"
                    ]
                ]]
            ],
            "comments": [
                "sysDatatype": "relation",
                "sysRelationType": "array",
                "sysCollection": "comments",
                "sysObjects": [[
                    "sysObjectId": "12345",
                    "content": "First comment"
                ],[
                    "sysObjectId": "123456",
                    "content": "Second comment"
                ]]
            ]
        ])
    }
    
    override func tearDown() {
        super.tearDown()
        OHHTTPStubs.setEnabled(false)
    }

    func testShallowAccessors() {
        AXAssertEqual(object?.string("content"), "Hello World")
        AXAssertEqual(object?.number("value"), 1023)
        AXAssertEqual(object?.array("tags")?[0], "hello")
        AXAssertEqual(object?.array("tags")?[1], "world")
        AXAssertEqual(object?.file("image")?.filename, "selfie.jpg")
        AXAssertEqual(object?.object("timeline")?.objectID, "1234")
        AXAssertEqual(object?.object("timeline")?.string("title"), "My timeline!")
        AXAssertEqual(object?.objects("comments")?[0].objectID, "12345")
        AXAssertEqual(object?.objects("comments")?[0].string("content"), "First comment")
        AXAssertEqual(object?.objects("comments")?[1].objectID, "123456")
        AXAssertEqual(object?.objects("comments")?[1].string("content"), "Second comment")
    }
    
    func testDeepAccessors() {
        AXAssertEqual(object?.string("timeline.title"), "My timeline!")
        AXAssertEqual(object?.number("timeline.likes"), 423)
        AXAssertEqual(object?.array("timeline.tags")?[0], "music")
        AXAssertEqual(object?.array("timeline.tags")?[1], "photography")
        AXAssertEqual(object?.file("timeline.background")?.filename, "panorama.jpg")
    }
    
    func testReturnNilIfWrongType() {
        AXAssertNil(object?.string("value"))
        AXAssertNil(object?.string("tags"))
        AXAssertNil(object?.string("image"))
        AXAssertNil(object?.string("timeline"))
        AXAssertNil(object?.string("comments"))
        
        AXAssertNil(object?.number("content"))
        AXAssertNil(object?.number("tags"))
        AXAssertNil(object?.number("image"))
        AXAssertNil(object?.number("timeline"))
        AXAssertNil(object?.number("comments"))
        
        AXAssertNil(object?.array("content"))
        AXAssertNil(object?.array("value"))
        AXAssertNil(object?.array("image"))
        AXAssertNil(object?.array("timeline"))
        
        AXAssertNil(object?.file("content"))
        AXAssertNil(object?.file("value"))
        AXAssertNil(object?.file("tags"))
        AXAssertNil(object?.file("timeline"))
        AXAssertNil(object?.file("comments"))
        
        AXAssertNil(object?.object("content"))
        AXAssertNil(object?.object("value"))
        AXAssertNil(object?.object("tags"))
        AXAssertNil(object?.object("image"))
        AXAssertNil(object?.object("comments"))
        
        AXAssertNil(object?.objects("content"))
        AXAssertNil(object?.objects("value"))
        AXAssertNil(object?.objects("tags"))
        AXAssertNil(object?.objects("image"))
        AXAssertNil(object?.objects("timeline"))
    }
    
    func testArrayAccessorReturnsRelatedObjectsIfExpanded() {
        AXAssertNotNil(object?.array("comments"))
        AXAssertEqual(object?.array("comments"), object?.objects("comments"))
    }

}
