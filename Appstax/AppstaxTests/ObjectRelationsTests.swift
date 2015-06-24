
import Foundation
import XCTest
import Appstax

@objc class ObjectRelationsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        OHHTTPStubs.setEnabled(true)
        OHHTTPStubs.removeAllStubs()
        Appstax.setAppKey("test-api-key", baseUrl:"http://localhost:3000/");
        Appstax.setLogLevel("debug");
    }
    
    override func tearDown() {
        super.tearDown()
        OHHTTPStubs.setEnabled(false)
    }
    
    func dictionaryFromRequestBody(request: NSURLRequest) -> [String:AnyObject]? {
        let httpBody = NSURLProtocol.propertyForKey("HTTPBody", inRequest: request) as? NSData
        return NSJSONSerialization.JSONObjectWithData(httpBody!, options: NSJSONReadingOptions(0), error: nil) as? [String:AnyObject]
    }
    
    func relationChangesFromBody(body: [String:AnyObject]?, property: String) -> [String:[String]]? {
        return body?[property]?["sysRelationChanges"] as? [String:[String]]
    }

    func testShouldHaveObjectIDsAsValuesForUnexpandedProperties() {
        let object = AXObject.create("foo", properties: [
            "prop1": [
                "sysDatatype": "relation",
                "sysRelationType": "single",
                "sysObjects": ["id1"]
            ],
            "prop2": [
                "sysDatatype": "relation",
                "sysRelationType": "array",
                "sysObjects": ["id2","id3"]
            ],
            "prop3": [
                "sysDatatype": "relation",
                "sysRelationType": "single",
                "sysObjects": []
            ],
            "prop4": [
                "sysDatatype": "relation",
                "sysRelationType": "array",
                "sysObjects": []
            ],
        ])
        
        AXAssertEqual(object["prop1"], "id1")
        AXAssertEqual(object["prop2"]?.count, 2)
        AXAssertEqual(object["prop2"]?[0], "id2")
        AXAssertEqual(object["prop2"]?[1], "id3")
        AXAssertNil(object["prop3"])
        AXAssertEqual(object["prop4"]?.count, 0)
    }
    
    func testShouldIncludeRelatedObjectsAsExpandedProperties() {
        let object = AXObject.create("collection1", properties: [
            "prop1": [
                "sysDatatype": "relation",
                "sysRelationType": "single",
                "sysCollection": "collection2",
                "sysObjects": [[
                    "sysObjectId": "id1",
                    "prop3": "value3"
                ]]
            ],
            "prop2": [
                "sysDatatype": "relation",
                "sysRelationType": "array",
                "sysCollection": "collection3",
                "sysObjects": [
                    [
                        "sysObjectId": "id2",
                        "prop4": "value4a"
                    ], [
                        "sysObjectId": "id3",
                        "prop4": "value4b"
                    ]
                ]
            ],
        ])
        
        XCTAssertTrue(object["prop1"] is AXObject)
        XCTAssertTrue(object["prop2"] is [AXObject])
        
        var prop1 = object["prop1"] as! AXObject
        var prop2 = object["prop2"] as! [AXObject]
        AXAssertEqual(prop1.objectID, "id1")
        AXAssertEqual(prop1.collectionName, "collection2")
        AXAssertEqual(prop1["prop3"], "value3")
        AXAssertEqual(prop2.count, 2)
        AXAssertEqual(prop2[0].objectID, "id2")
        AXAssertEqual(prop2[0].collectionName, "collection3")
        AXAssertEqual(prop2[0]["prop4"], "value4a")
        AXAssertEqual(prop2[1].objectID, "id3")
        AXAssertEqual(prop2[1].collectionName, "collection3")
        AXAssertEqual(prop2[1]["prop4"], "value4b")
    }
    
    func testShouldFailWhenObjectHasUnsavedObjectsInRelations() {
        let async = expectationWithDescription("async")
        
        let invoice  = AXObject.create("invoices",  properties: ["amount": 149])
        let customer = AXObject.create("customers", properties: ["name": "Bill Buyer"])
        
        invoice["customer"] = customer
        
        var saveError: NSError?
        invoice.save() {
            saveError = $0
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertNotNil(saveError)
            AXAssertEqual(saveError?.localizedDescription, "Error saving object. Found unsaved related objects. Save related objects first or consider using saveAll instead.")
        }
    }
    
    func testSaveAllShouldSaveNewlyCreatedRelatedSingleObjects() {
        let async = expectationWithDescription("async")
        
        var postBody1: [String:AnyObject]?
        var postBody2: [String:AnyObject]?
        AXStubs.method("POST", urlPath: "/objects/customers") { request in
            postBody1 = self.dictionaryFromRequestBody(request)
            return OHHTTPStubsResponse(JSONObject: ["sysObjectId":"customer-id-1"], statusCode: 200, headers: [:])
        }
        AXStubs.method("POST", urlPath: "/objects/invoices") { request in
            postBody2 = self.dictionaryFromRequestBody(request)
            return OHHTTPStubsResponse(JSONObject: ["sysObjectId":"invoice-id-1"], statusCode: 200, headers: [:])
        }
        
        let invoice  = AXObject.create("invoices",  properties: ["amount": 149])
        let customer = AXObject.create("customers", properties: ["name": "Bill Buyer"])
        
        invoice["customer"] = customer
        invoice.saveAll() { error in
            AXAssertNil(error)
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertNotNil(postBody1)
            AXAssertNotNil(postBody2)
            AXAssertEqual(postBody1?["name"], "Bill Buyer")
            let changes = self.relationChangesFromBody(postBody2, property: "customer")
            AXAssertNotNil(changes)
            AXAssertEqual(changes?["additions"]?.count, 1)
            AXAssertContains(changes?["additions"], "customer-id-1")
        }
    }
    
    func testSaveShouldHangleSettingRelationWithPreviouslyCreatedSingleObjects() {
        let async = expectationWithDescription("async")
        
        var postBody: [String:AnyObject]?
        AXStubs.method("PUT", urlPath: "/objects/customers") { request in
            XCTFail("Unexpected request")
            return nil
        }
        AXStubs.method("POST", urlPath: "/objects/invoices") { request in
            postBody = self.dictionaryFromRequestBody(request)
            return OHHTTPStubsResponse(JSONObject: ["sysObjectId":"invoice-id-1"], statusCode: 200, headers: [:])
        }
        
        let invoice  = AXObject.create("invoices",  properties: ["amount": 149])
        let customer = AXObject.create("customers", properties: ["name": "Bill Buyer", "sysObjectId": "customer-id-1001"])
        
        invoice["customer"] = customer
        invoice.save() { error in
            AXAssertNil(error)
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertNotNil(postBody)
            let changes = self.relationChangesFromBody(postBody, property: "customer")
            AXAssertNotNil(changes)
            AXAssertEqual(changes?["additions"]?.count, 1)
            AXAssertContains(changes?["additions"], "customer-id-1001")
        }
    }
    
    func testShouldHandleRemovingSingleRelation() {
        let async = expectationWithDescription("async")
        
        var postBody: [String:AnyObject]?
        AXStubs.method("PUT", urlPath: "/objects/invoices/invoice-id-1") { request in
            postBody = self.dictionaryFromRequestBody(request)
            return OHHTTPStubsResponse(JSONObject: [:], statusCode: 200, headers: [:])
        }
        
        let invoice = AXObject.create("invoices", properties: [
            "amount": 149,
            "sysObjectId": "invoice-id-1",
            "customer": [
                "sysDatatype": "relation",
                "sysRelationType": "single",
                "sysObjects": ["customer-1"]
            ]
        ])
        
        invoice["customer"] = nil
        invoice.save() { error in
            AXAssertNil(error)
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertNotNil(postBody)
            let changes = self.relationChangesFromBody(postBody, property: "customer")
            AXAssertNotNil(changes)
            AXAssertEqual(changes?["additions"]?.count, 0)
            AXAssertEqual(changes?["removals"]?.count, 1)
            AXAssertContains(changes?["removals"], "customer-1")
        }
    }
    
    func testShouldHandleReplacingSingleRelationWithOtherExistingObject() {
        let async = expectationWithDescription("async")
        
        var putBody: [String:AnyObject]?
        AXStubs.method("PUT", urlPath: "/objects/invoices/invoice-id-1") { request in
            putBody = self.dictionaryFromRequestBody(request)
            return OHHTTPStubsResponse(JSONObject: [:], statusCode: 200, headers: [:])
        }
        
        let invoice = AXObject.create("invoices", properties: [
            "amount": 149,
            "sysObjectId": "invoice-id-1",
            "customer": [
                "sysDatatype": "relation",
                "sysRelationType": "single",
                "sysObjects": ["customer-1"]
            ]
        ])
        
        invoice["customer"] = AXObject.create("customer", properties: ["sysObjectId": "customer-2"])
        invoice.save() { error in
            AXAssertNil(error)
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertNotNil(putBody)
            let changes = self.relationChangesFromBody(putBody, property: "customer")
            AXAssertNotNil(changes)
            AXAssertEqual(changes?["additions"]?.count, 1)
            AXAssertContains(changes?["additions"], "customer-2")
            AXAssertEqual(changes?["removals"]?.count, 1)
            AXAssertContains(changes?["removals"], "customer-1")
        }
    }
    
    func testShouldOnlySendNewRelationChangesForSingleRelation() {
        let async = expectationWithDescription("async")
        
        var putBody: [String:AnyObject]?
        AXStubs.method("PUT", urlPath: "/objects/invoices/invoice-1") { request in
            putBody = self.dictionaryFromRequestBody(request)
            return OHHTTPStubsResponse(JSONObject: [:], statusCode: 200, headers: [:])
        }
        
        let invoice = AXObject.create("invoices", properties: [
            "amount": 149,
            "sysObjectId": "invoice-1",
            "customer": [
                "sysDatatype": "relation",
                "sysRelationType": "single",
                "sysObjects": ["customer-1"]
            ]
        ])
        
        invoice["customer"] = AXObject.create("customer", properties: ["sysObjectId": "customer-2"])
        invoice.save() { error in
            AXAssertNil(error)
            
            invoice["customer"] = AXObject.create("customer", properties: ["sysObjectId": "customer-3"])
            invoice.save() { error in
                AXAssertNil(error)
                async.fulfill()
            }
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertNotNil(putBody)
            let changes = self.relationChangesFromBody(putBody, property: "customer")
            AXAssertNotNil(changes)
            AXAssertEqual(changes?["additions"]?.count, 1)
            AXAssertContains(changes?["additions"], "customer-3")
            AXAssertEqual(changes?["removals"]?.count, 1)
            AXAssertContains(changes?["removals"], "customer-2")
        }
    }
    
    func testSaveShouldFailWhenThereAreUnsavedRelatedArrayObjects() {
        let async = expectationWithDescription("async")
        
        let blog  = AXObject.create("blogs", properties: ["title": "Zen"])
        let post1 = AXObject.create("posts", properties: ["title": "Post 1"])
        let post2 = AXObject.create("posts", properties: ["title": "Post 2"])
        
        blog["posts"] = [post1, post2]
        
        var saveError: NSError?
        blog.save() {
            saveError = $0
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertNotNil(saveError)
            AXAssertEqual(saveError?.localizedDescription, "Error saving object. Found unsaved related objects. Save related objects first or consider using saveAll instead.")
        }
    }
    
    func testSaveAllShouldCreateAndSaveNewlyCreatedRelatedArrayObjects() {
        let async = expectationWithDescription("async")
        
        var postBody: [[String:AnyObject]?] = []
        AXStubs.method("POST", urlPath: "/objects/posts") { request in
            postBody.append(self.dictionaryFromRequestBody(request))
            return OHHTTPStubsResponse(JSONObject: ["sysObjectId":"post-id-\(postBody.count)"], statusCode: 200, headers: [:])
        }
        AXStubs.method("POST", urlPath: "/objects/blogs") { request in
            postBody.append(self.dictionaryFromRequestBody(request))
            return OHHTTPStubsResponse(JSONObject: ["sysObjectId":"blog-id-1"], statusCode: 200, headers: [:])
        }
        
        let blog  = AXObject.create("blogs", properties: ["title": "Zen"])
        let post1 = AXObject.create("posts", properties: ["title": "Post 1"])
        let post2 = AXObject.create("posts", properties: ["title": "Post 2"])
        
        blog["posts"] = [post1, post2]
        
        var saveError: NSError?
        blog.saveAll() { error in
            AXAssertNil(error)
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertNotNil(postBody[0])
            AXAssertNotNil(postBody[1])
            AXAssertNotNil(postBody[2])
            AXAssertEqual(postBody[0]?["title"], "Post 1")
            AXAssertEqual(postBody[1]?["title"], "Post 2")
            AXAssertEqual(postBody[2]?["title"], "Zen")
            let changes = self.relationChangesFromBody(postBody[2], property: "posts")
            AXAssertNotNil(changes)
            AXAssertEqual(changes?["additions"]?.count, 2)
            AXAssertContains(changes?["additions"], "post-id-1")
            AXAssertContains(changes?["additions"], "post-id-2")
        }
    }
    
    func testSaveAllShouldHandleAddingMoreObjectsToArrayRelations() {
        let async = expectationWithDescription("async")
        
        var httpBody: [[String:AnyObject]?] = []
        AXStubs.method("POST", urlPath: "/objects/posts") { request in
            httpBody.append(self.dictionaryFromRequestBody(request))
            return OHHTTPStubsResponse(JSONObject: ["sysObjectId":"post-id-\(httpBody.count)"], statusCode: 200, headers: [:])
        }
        AXStubs.method("PUT", urlPath: "/objects/blogs/1234") { request in
            httpBody.append(self.dictionaryFromRequestBody(request))
            return OHHTTPStubsResponse(JSONObject: [:], statusCode: 200, headers: [:])
        }
        
        let blog  = AXObject.create("blogs", properties: [
            "title": "Zen",
            "sysObjectId": "1234",
            "posts": ["sysDatatype":"relation", "sysRelationType":"array"]
        ])
        let post1 = AXObject.create("posts", properties: ["title": "Post 1"])
        let post2 = AXObject.create("posts", properties: ["title": "Post 2"])
        blog["posts"]?.addObject(post1)
        blog["posts"]?.addObject(post2)
        
        blog.saveAll() { error in
            AXAssertNil(error)
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertNotNil(httpBody[0])
            AXAssertNotNil(httpBody[1])
            AXAssertNotNil(httpBody[2])
            AXAssertEqual(httpBody[0]?["title"], "Post 1")
            AXAssertEqual(httpBody[1]?["title"], "Post 2")
            AXAssertEqual(httpBody[2]?["title"], "Zen")
            let changes = self.relationChangesFromBody(httpBody[2], property: "posts")
            AXAssertNotNil(changes)
            AXAssertEqual(changes?["additions"]?.count, 2)
            AXAssertContains(changes?["additions"], "post-id-1")
            AXAssertContains(changes?["additions"], "post-id-2")
        }
    }
    
    func testSaveAllShouldFailOnHttpErrors() {
        let async = expectationWithDescription("async")
        
        var blogsCalled = false
        var postzCalled = false
        AXStubs.method("POST", urlPath: "/objects/blogs") { request in
            blogsCalled = true
            return OHHTTPStubsResponse(JSONObject: ["sysObjectId":"postid"], statusCode: 200, headers: [:])
        }
        AXStubs.method("POST", urlPath: "/objects/postz") { request in
            postzCalled = true
            return OHHTTPStubsResponse(JSONObject: ["errorMessage":"Collection not found"], statusCode: 404, headers: [:])
        }
        
        let blog  = AXObject.create("blogs", properties: ["title": "Zen"])
        let post1 = AXObject.create("postz", properties: ["title": "Post 1"])
        let post2 = AXObject.create("postz", properties: ["title": "Post 2"])
        blog["posts"] = [post1, post2]
        
        var saveError: NSError?
        blog.saveAll() { error in
            saveError = error
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
            XCTAssertTrue(postzCalled)
            AXAssertNotNil(saveError)
            XCTAssertFalse(blogsCalled)
        }
    }
    
    func testSaveShouldHandleAddingAndRemovingObjectsInArrayRelation() {
        let async = expectationWithDescription("async")
        
        var httpBody: [[String:AnyObject]?] = []
        AXStubs.method("PUT", urlPath: "/objects/blogs/blog-1") { request in
            httpBody.append(self.dictionaryFromRequestBody(request))
            return OHHTTPStubsResponse(JSONObject: [:], statusCode: 200, headers: [:])
        }
        
        let blog  = AXObject.create("blogs", properties: [
            "sysObjectId": "blog-1",
            "posts": [
                "sysDatatype":"relation",
                "sysRelationType":"array",
                "sysObjects": ["post-1", "post-2"]
            ]
        ])
        blog["posts"]?.removeObjectAtIndex(0)
        blog["posts"]?.addObject(AXObject.create("posts", properties: ["sysObjectId": "post-3"]))
        
        blog.save() { error in
            AXAssertNil(error)
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertNotNil(httpBody[0])
            let changes = self.relationChangesFromBody(httpBody[0], property: "posts")
            AXAssertNotNil(changes)
            AXAssertEqual(changes?["additions"]?.count, 1)
            AXAssertContains(changes?["additions"], "post-3")
            AXAssertEqual(changes?["removals"]?.count, 1)
            AXAssertContains(changes?["removals"], "post-1")
        }
    }
    
    func testSaveShouldOnlySendNewArrayRelationChangesForEachSave() {
        let async = expectationWithDescription("async")
        
        var httpBody: [[String:AnyObject]?] = []
        AXStubs.method("PUT", urlPath: "/objects/blogs/blog-1") { request in
            httpBody.append(self.dictionaryFromRequestBody(request))
            return OHHTTPStubsResponse(JSONObject: [:], statusCode: 200, headers: [:])
        }
        
        let blog  = AXObject.create("blogs", properties: [
            "sysObjectId": "blog-1",
            "posts": [
                "sysDatatype":"relation",
                "sysRelationType":"array",
                "sysObjects": ["post-1", "post-2"]
            ]
        ])
        blog["posts"]?.removeObjectAtIndex(0) // remove post-1
        blog["posts"]?.addObject(AXObject.create("posts", properties: ["sysObjectId": "post-3"]))
        
        blog.save() { error in
            AXAssertNil(error)
            
            blog["posts"]?.removeObjectAtIndex(1) // remove post-3
            blog["posts"]?.addObject(AXObject.create("posts", properties: ["sysObjectId": "post-4"]))

            blog.save() { error in
                AXAssertNil(error)
                async.fulfill()
            }
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertNotNil(httpBody[0])
            AXAssertNotNil(httpBody[1])
            let changes = self.relationChangesFromBody(httpBody[1], property: "posts")
            AXAssertNotNil(changes)
            AXAssertEqual(changes?["additions"]?.count, 1)
            AXAssertContains(changes?["additions"], "post-4")
            AXAssertEqual(changes?["removals"]?.count, 1)
            AXAssertContains(changes?["removals"], "post-3")
        }
    }
    
    func testSaveAllShouldHandleCircularReferencesForSingleRelationsInNewObjects() {
        let async = expectationWithDescription("async")
        
        var object1Body: [[String:AnyObject]?] = []
        var object2Body: [[String:AnyObject]?] = []
        AXStubs.method("POST", urlPath: "/objects/collection1") { request in
            object1Body.append(self.dictionaryFromRequestBody(request))
            return OHHTTPStubsResponse(JSONObject: ["sysObjectId":"id1"], statusCode: 200, headers: [:])
        }
        AXStubs.method("POST", urlPath: "/objects/collection2") { request in
            object2Body.append(self.dictionaryFromRequestBody(request))
            return OHHTTPStubsResponse(JSONObject: ["sysObjectId":"id2"], statusCode: 200, headers: [:])
        }
        AXStubs.method("PUT", urlPath: "/objects/collection1/id1") { request in
            object1Body.append(self.dictionaryFromRequestBody(request))
            return OHHTTPStubsResponse(JSONObject: [:], statusCode: 200, headers: [:])
        }
        AXStubs.method("PUT", urlPath: "/objects/collection2/id2") { request in
            object2Body.append(self.dictionaryFromRequestBody(request))
            return OHHTTPStubsResponse(JSONObject: [:], statusCode: 200, headers: [:])
        }
        
        var object1 = AXObject.create("collection1")
        var object2 = AXObject.create("collection2")
        object1["property1"] = object2;
        object2["property2"] = object1;
        
        object1.saveAll() { error in
            AXAssertNil(error)
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertNotNil(object1Body[0])
            AXAssertNotNil(object1Body[1])
            AXAssertNotNil(object2Body[0])
            AXAssertNotNil(object2Body[1])
            
            let changes1 = self.relationChangesFromBody(object1Body[0], property: "property1")
            AXAssertNotNil(changes1)
            AXAssertEqual(changes1?["additions"]?.count, 0)
            AXAssertEqual(changes1?["removals"]?.count, 0)
            
            let changes2 = self.relationChangesFromBody(object2Body[0], property: "property2")
            AXAssertNotNil(changes2)
            AXAssertEqual(changes2?["additions"]?.count, 0)
            AXAssertEqual(changes2?["removals"]?.count, 0)
            
            let changes1b = self.relationChangesFromBody(object1Body[1], property: "property1")
            AXAssertNotNil(changes1b)
            AXAssertEqual(changes1b?["additions"]?.count, 1)
            AXAssertEqual(changes1b?["removals"]?.count, 0)
            AXAssertContains(changes1b?["additions"], "id2")
            
            let changes2b = self.relationChangesFromBody(object2Body[1], property: "property2")
            AXAssertNotNil(changes2b)
            AXAssertEqual(changes2b?["additions"]?.count, 1)
            AXAssertEqual(changes2b?["removals"]?.count, 0)
            AXAssertContains(changes2b?["additions"], "id1")
        }
    }
    
    func testSaveAllShouldAlsoSaveObjectsWithoutRelationChanges() {
        let async = expectationWithDescription("async")
        
        var httpBody: [[String:AnyObject]?] = []
        AXStubs.method("POST", urlPath: "/objects/invoices") { request in
            httpBody.append(self.dictionaryFromRequestBody(request))
            return OHHTTPStubsResponse(JSONObject: ["sysObjectId":"id1"], statusCode: 200, headers: [:])
        }
        AXStubs.method("PUT", urlPath: "/objects/customers/customer-id-1001") { request in
            httpBody.append(self.dictionaryFromRequestBody(request))
            return OHHTTPStubsResponse(JSONObject: [:], statusCode: 200, headers: [:])
        }
        
        let invoice  = AXObject.create("invoices", properties:["amount": 149])
        let customer = AXObject.create("customers", properties:["name":"Bill Buyer", "sysObjectId":"customer-id-1001"])
        
        invoice["customer"] = customer
        customer["name"] = "Bill N. Buyer"
        
        invoice.saveAll() {
            error in
            AXAssertNil(error)
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertNotNil(httpBody[0])
            AXAssertNotNil(httpBody[1])
            
            let changes = self.relationChangesFromBody(httpBody[0], property: "customer")
            AXAssertNotNil(changes)
            AXAssertEqual(changes?["additions"]?.count, 1)
            AXAssertEqual(changes?["removals"]?.count, 0)
            AXAssertContains(changes?["additions"], "customer-id-1001")
            
            AXAssertEqual(httpBody[1]?["name"], "Bill N. Buyer")
        }
    }
    
    func testSaveAllShouldAlsoSaveObjectsWithoutRelations() {
        let async = expectationWithDescription("async")
        
        var httpBody: [[String:AnyObject]?] = []
        AXStubs.method("POST", urlPath: "/objects/foo") { request in
            httpBody.append(self.dictionaryFromRequestBody(request))
            return OHHTTPStubsResponse(JSONObject: ["sysObjectId":"id1"], statusCode: 200, headers: [:])
        }
        
        let foo = AXObject.create("foo")
        foo["bar"] = "baz"
        foo.saveAll() {
            error in
            AXAssertNil(error)
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertNotNil(httpBody[0])
            AXAssertEqual(httpBody[0]?["bar"], "baz")
            AXAssertEqual(foo.objectID, "id1")
        }
    }
    
    func testShouldSendExpandParameterInQueries() {
        let async = expectationWithDescription("async")
        
        var urls: [NSURL?] = []
        AXStubs.method("GET", urlPath: "/objects/invoices") { request in
            urls.append(request.URL)
            return OHHTTPStubsResponse(JSONObject: [:], statusCode: 200, headers: [:])
        }
        AXStubs.method("GET", urlPath: "/objects/invoices/1234") { request in
            urls.append(request.URL)
            return OHHTTPStubsResponse(JSONObject: [:], statusCode: 200, headers: [:])
        }
        
        AXObject.findAll("invoices") { error in
        AXObject.findAll("invoices", options: ["expand": true]) { error in
        AXObject.findAll("invoices", options: ["expand": 2]) { error in
        AXObject.find("invoices", withId: "1234", options: ["expand": true]) { error in
        AXObject.find("invoices", query: { query in }, options: ["expand": 2]) { error in
        AXObject.find("invoices", with: ["amount": 1001], options: ["expand": 3]) { error in
        AXObject.find("invoices", search: ["description": "discount"], options: ["expand": 4]) { error in
        AXObject.find("invoices", search: "discount", properties: ["description", "other"], options: ["expand": 5]) { error in
            async.fulfill()
        }}}}}}}}
               
        waitForExpectationsWithTimeout(3) { error in
            AXAssertEqual(urls.count, 8)
            AXAssertStringNotContains(urls[0]?.absoluteString, "expanddepth=")
            AXAssertStringContains(urls[1]?.absoluteString, "expanddepth=1")
            AXAssertStringContains(urls[2]?.absoluteString, "expanddepth=2")
            AXAssertStringContains(urls[3]?.absoluteString, "expanddepth=1")
            AXAssertStringContains(urls[4]?.absoluteString, "expanddepth=2")
            AXAssertStringContains(urls[5]?.absoluteString, "expanddepth=3")
            AXAssertStringContains(urls[6]?.absoluteString, "expanddepth=4")
            AXAssertStringContains(urls[7]?.absoluteString, "expanddepth=5")
        }
        
    }
    
    func testShouldSendObjectQuerWithExpansionDepthWhenCallingExpand() {
        let async = expectationWithDescription("async")
        
        var urls: [NSURL?] = []
        AXStubs.method("GET", urlPath: "/objects/blogs/1234") { request in
            urls.append(request.URL)
            return OHHTTPStubsResponse(JSONObject: [:], statusCode: 200, headers: [:])
        }
        
        let object = AXObject.create("blogs", properties: ["sysObjectId": "1234"])
        object.expand()
        object.expand(2) { error in
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertEqual(urls.count, 2)
            AXAssertEqual(urls[0]?.absoluteString, "http://localhost:3000/objects/blogs/1234?expanddepth=1")
            AXAssertEqual(urls[1]?.absoluteString, "http://localhost:3000/objects/blogs/1234?expanddepth=2")
        }
    }
    
    func testShouldReloadObjectWithExpandedPropertiesWhenCallingExpand() {
        let async = expectationWithDescription("async")
        
        var urls: [NSURL?] = []
        AXStubs.method("GET", urlPath: "/objects/blogs/1234") { request in
            urls.append(request.URL)
            let response = [
                "sysObjectId": "1234",
                "posts": [
                    "sysDatatype": "relation",
                    "sysRelationType": "array",
                    "sysCollection": "posts",
                    "sysObjects": [["title":"Zen"], ["title":"Flow"]]
                ],
                "owner": [
                    "sysDatatype": "relation",
                    "sysRelationType": "single",
                    "sysCollection": "users",
                    "sysObjects": [["name":"Mr. Blogger"]]
                ]
            ]
            return OHHTTPStubsResponse(JSONObject: response, statusCode: 200, headers: [:])
        }
        
        let blog = AXObject.create("blogs", properties: [
            "sysObjectId": "1234",
            "posts": [
                "sysDatatype": "relation",
                "sysRelationType": "array",
                "sysObjects": ["id1", "id2"]
            ],
            "owner": [
                "sysDatatype": "relation",
                "sysRelationType": "single",
                "sysObjects": ["id3"]
            ]
        ])
        
        blog.expand() { error in
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertEqual(urls.count, 1)
            AXAssertEqual(urls[0]?.absoluteString, "http://localhost:3000/objects/blogs/1234?expanddepth=1")
            let owner = blog["owner"] as? AXObject
            let posts = blog["posts"] as? [AXObject]
            AXAssertEqual(owner?["name"], "Mr. Blogger")
            AXAssertEqual(posts?[0]["title"], "Zen")
            AXAssertEqual(posts?[1]["title"], "Flow")
        }
    }
    
    func testShouldFailWhenCallingExpandOnUnsavedObject() {
        let async = expectationWithDescription("async")
        
        let blog = AXObject.create("blogs")
        var expandError: NSError?
        blog.expand() {
            expandError = $0
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertNotNil(expandError)
            AXAssertEqual(expandError?.localizedDescription, "Error calling expand() on unsaved object")
        }
    }
    
    func testShouldIncludeRelatedObjectsInQueries() {
        let async = expectationWithDescription("async")
        
        var urls: [NSURL?] = []
        AXStubs.method("GET", urlPath: "/objects/events") { request in
            urls.append(request.URL)
            return OHHTTPStubsResponse(JSONObject: [:], statusCode: 200, headers: [:])
        }
        
        let myTimeline = AXObject.create("timelines", properties:["sysObjectId": "12345"])
        AXObject.find("events", query: { query in
            query.relation("timeline", hasObject: myTimeline)
        }) { objects, error in
            AXAssertNil(error)
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertEqual(urls.count, 1)
            AXAssertEqual(urls[0]?.absoluteString, "http://localhost:3000/objects/events?filter=timeline%20has%20(%2712345%27)")
        }
    }
    
    func testShouldIncludeRelatedObjectsInPropertyMatchQueries() {
        let async = expectationWithDescription("async")
        
        var urls: [NSURL?] = []
        AXStubs.method("GET", urlPath: "/objects/events") { request in
            urls.append(request.URL)
            return OHHTTPStubsResponse(JSONObject: [:], statusCode: 200, headers: [:])
        }
        
        let myTimeline = AXObject.create("timelines", properties:["sysObjectId": "12345"])
        AXObject.find("events", with: ["timeline":myTimeline]) {
            objects, error in
            AXAssertNil(error)
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertEqual(urls.count, 1)
            AXAssertEqual(urls[0]?.absoluteString, "http://localhost:3000/objects/events?filter=timeline%20has%20(%2712345%27)")
        }
    }
    
    

}
