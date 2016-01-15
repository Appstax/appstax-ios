
import Foundation
import XCTest
@testable import Appstax

@objc class AXModelTests: XCTestCase {
    
    var realtimeService: AXRealtimeService!
    
    let itemsResponse = ["objects":[[
        "sysObjectId":"id0",
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
            "sysObjects": [[
                "sysObjectId": "id2",
                "prop4": "value4a"
            ],[
                "sysObjectId": "id3",
                "prop4": "value4b"
            ]]
        ]
    ]]]
    
    let itemsResponseDeep = ["objects":[[
        "sysObjectId":"id0",
        "prop1": [
            "sysDatatype": "relation",
            "sysRelationType": "single",
            "sysCollection": "collection2",
            "sysObjects": [[
                "sysObjectId": "id1",
                "prop2": "value2",
                "prop3": [
                    "sysDatatype": "relation",
                    "sysRelationType": "single",
                    "sysCollection": "collection3",
                    "sysObjects": [[
                        "sysObjectId": "id2",
                        "prop4": "value4"
                    ]]
                ]
            ]]
        ]
    ]]]
    
    let itemsResponseDeepArray = ["objects":[[
        "sysObjectId":"id0",
        "prop1": [
            "sysDatatype": "relation",
            "sysRelationType": "array",
            "sysCollection": "collection2",
            "sysObjects": [[
                "sysObjectId": "id1",
                "prop2": "value2",
                "prop3": [
                    "sysDatatype": "relation",
                    "sysRelationType": "single",
                    "sysCollection": "collection3",
                    "sysObjects": [[
                        "sysObjectId": "id2",
                        "prop4": "value4"
                    ]]
                ]
            ]]
        ]
    ]]]
    
    override func setUp() {
        super.setUp()
        OHHTTPStubs.setEnabled(true)
        OHHTTPStubs.removeAllStubs()
        Appstax.setAppKey("testappkey", baseUrl:"http://localhost:3000/");
        Appstax.setLogLevel("debug");
        realtimeService = Appstax.defaultContext.realtimeService
    }
    
    override func tearDown() {
        super.tearDown()
        OHHTTPStubs.setEnabled(false)
    }
    
    // MARK: Array/Collection observers
    
    func testShouldAddArrayAndUpdateItWithInitialData() {
        weak var async = expectationWithDescription("async")
        var requestCount = 0
        AXStubs.method("GET", urlPath: "/objects/posts") { request in
            requestCount++
            return OHHTTPStubsResponse(JSONObject: ["objects":[
                ["sysObjectId": "id1", "content": "c1", "sysCreated": "2015-08-19T11:00:00"],
                ["sysObjectId": "id2", "content": "c2", "sysCreated": "2015-08-19T10:00:00"]
            ]], statusCode: 200, headers: [:])
        }
        
        let model = AXModel()
        AXAssertNil(model["posts"])
        
        model.watch("posts")
        AXAssertNotNil(model["posts"])
        XCTAssertTrue(model["posts"] is [AXObject])
        AXAssertEqual(model["posts"]?.count, 0)
        
        delay(0.3) { async?.fulfill() }
        waitForExpectationsWithTimeout(3) { error in
            AXAssertEqual(requestCount, 1)
            AXAssertEqual(model["posts"]?.count, 2)
            AXAssertEqual(model["posts"]?[0].objectID, "id1")
            AXAssertEqual(model["posts"]?[1].objectID, "id2")
            AXAssertEqual(model["posts"]?[0].collectionName, "posts")
            AXAssertEqual(model["posts"]?[1].collectionName, "posts")
            AXAssertEqual(model["posts"]?[0]["content"], "c1")
            AXAssertEqual(model["posts"]?[1]["content"], "c2")
        }
    }
    
    func testShouldSortInitialDataByCreatedDate() {
        weak var async = expectationWithDescription("async")
        AXStubs.method("GET", urlPath: "/objects/posts") { request in
            return OHHTTPStubsResponse(JSONObject: ["objects":[
                ["sysObjectId": "id1", "sysCreated": "2015-08-19T10:00:00"],
                ["sysObjectId": "id2", "sysCreated": "2015-08-19T12:00:00"],
                ["sysObjectId": "id3", "sysCreated": "2015-08-19T11:00:00"]
            ]], statusCode: 200, headers: [:])
        }
        
        let model = AXModel()
        model.watch("posts")
        
        delay(0.3) { async?.fulfill() }
        waitForExpectationsWithTimeout(3) { error in
            let ids = (model["posts"] as! [AXObject]).map() { $0.objectID! }.joinWithSeparator(",")
            AXAssertEqual(ids, "id2,id3,id1")
        }
    }
    
    func testShouldOrderObjectsByGivenDatePropertyAscending() {
        weak var async = expectationWithDescription("async")
        AXStubs.method("GET", urlPath: "/objects/posts") { request in
            return OHHTTPStubsResponse(JSONObject: ["objects":[
                ["sysObjectId": "id1", "sysCreated": "2015-08-20", "sysUpdated": "2015-08-21"],
                ["sysObjectId": "id2", "sysCreated": "2015-08-22", "sysUpdated": "2015-08-20"],
                ["sysObjectId": "id3", "sysCreated": "2015-08-21", "sysUpdated": "2015-08-22"]
                ]], statusCode: 200, headers: [:])
        }
        
        let model = AXModel()
        model.watch("posts", order: "updated")
        
        delay(0.3) { async?.fulfill() }
        waitForExpectationsWithTimeout(3) { error in
            let ids = (model["posts"] as! [AXObject]).map() { $0.objectID! }.joinWithSeparator(",")
            AXAssertEqual(ids, "id2,id1,id3")
        }
    }
    
    func testShouldOrderObjectsByGivenDatePropertyDescending() {
        weak var async = expectationWithDescription("async")
        AXStubs.method("GET", urlPath: "/objects/posts") { request in
            return OHHTTPStubsResponse(JSONObject: ["objects":[
                ["sysObjectId": "id1", "sysCreated": "2015-08-20", "sysUpdated": "2015-08-21"],
                ["sysObjectId": "id2", "sysCreated": "2015-08-22", "sysUpdated": "2015-08-20"],
                ["sysObjectId": "id3", "sysCreated": "2015-08-21", "sysUpdated": "2015-08-22"]
                ]], statusCode: 200, headers: [:])
        }
        
        let model = AXModel()
        model.watch("posts", order: "-updated")
        
        delay(0.3) { async?.fulfill() }
        waitForExpectationsWithTimeout(3) { error in
            let ids = (model["posts"] as! [AXObject]).map() { $0.objectID! }.joinWithSeparator(",")
            AXAssertEqual(ids, "id3,id1,id2")
        }
    }
    
    func testShouldOrderObjectsByGivenStringPropertyAscending() {
        weak var async = expectationWithDescription("async")
        AXStubs.method("GET", urlPath: "/objects/posts") { request in
            return OHHTTPStubsResponse(JSONObject: ["objects":[
                ["sysObjectId": "id1", "sysCreated": "2015-08-20", "category": "gamma"],
                ["sysObjectId": "id2", "sysCreated": "2015-08-22", "category": "alpha"],
                ["sysObjectId": "id3", "sysCreated": "2015-08-21", "category": "beta"]
                ]], statusCode: 200, headers: [:])
        }
        
        let model = AXModel()
        model.watch("posts", order: "category")
        
        delay(0.3) { async?.fulfill() }
        waitForExpectationsWithTimeout(3) { error in
            let ids = (model["posts"] as! [AXObject]).map() { $0.objectID! }.joinWithSeparator(",")
            AXAssertEqual(ids, "id2,id3,id1")
        }
    }
    
    func testShouldOrderObjectsByGivenStringPropertyDescending() {
        weak var async = expectationWithDescription("async")
        AXStubs.method("GET", urlPath: "/objects/posts") { request in
            return OHHTTPStubsResponse(JSONObject: ["objects":[
                ["sysObjectId": "id1", "sysCreated": "2015-08-20", "category": "gamma"],
                ["sysObjectId": "id2", "sysCreated": "2015-08-22", "category": "alpha"],
                ["sysObjectId": "id3", "sysCreated": "2015-08-21", "category": "beta"]
                ]], statusCode: 200, headers: [:])
        }
        
        let model = AXModel()
        model.watch("posts", order: "-category")
        
        delay(0.3) { async?.fulfill() }
        waitForExpectationsWithTimeout(3) { error in
            let ids = (model["posts"] as! [AXObject]).map() { $0.objectID! }.joinWithSeparator(",")
            AXAssertEqual(ids, "id1,id3,id2")
        }
    }
    
    func testShouldTriggerChangeEventAfterLoadingInitialData() {
        weak var async = expectationWithDescription("async")
        AXStubs.method("GET", urlPath: "/objects/posts") { request in
            return OHHTTPStubsResponse(JSONObject: ["objects":[["sysObjectId": "id1"]]], statusCode: 200, headers: [:])
        }
        
        let model = AXModel()
        model.watch("posts")
        model.on("change") {
            event in
            AXAssertEqual(event.type, "change")
            async?.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertEqual(model["posts"]?.count, 1)
        }
    }
    
    func testShouldAddObjectsWhenReceivingRealtimeObjectCreated() {
        weak var async = expectationWithDescription("async")
        
        let model = AXModel()
        model.watch("posts")
        model.on("change") { _ in
            async?.fulfill()
        }
        
        realtimeService.webSocketDidReceiveMessage([
            "event": "object.created",
            "channel": "objects/posts",
            "data": ["sysObjectId": "id1", "content": "c3"]
        ])
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertEqual(model["posts"]?.count, 1)
            AXAssertEqual(model["posts"]?[0]["content"], "c3")
        }
    }
    
    func testShouldKeepOrderWhenInsertingObjectFromObjectCreated() {
        weak var async = expectationWithDescription("async")
        AXStubs.method("GET", urlPath: "/objects/posts") { request in
            return OHHTTPStubsResponse(JSONObject: ["objects":[
                ["sysObjectId": "id1", "sysCreated": "2015-08-19T10:00:00"],
                ["sysObjectId": "id2", "sysCreated": "2015-08-19T12:00:00"],
                ["sysObjectId": "id3", "sysCreated": "2015-08-19T11:00:00"]
                ]], statusCode: 200, headers: [:])
        }
        
        let model = AXModel()
        model.watch("posts")

        delay(0.5) {
            self.realtimeService.webSocketDidReceiveMessage([
                "event": "object.created",
                "channel": "objects/posts",
                "data": ["sysObjectId": "id4", "sysCreated": "2015-08-19T11:30:00"]
            ])
            delay(0.5) {
                async?.fulfill()
            }
        }
        
        waitForExpectationsWithTimeout(3) { error in
            let ids = (model["posts"] as! [AXObject]).map() { $0.objectID! }.joinWithSeparator(",")
            AXAssertEqual(ids, "id2,id4,id3,id1")
        }
    }
    
    func testShouldReorderWhenUpdatingObjectFromObjectUpdated() {
        weak var async = expectationWithDescription("async")
        AXStubs.method("GET", urlPath: "/objects/posts") { request in
            return OHHTTPStubsResponse(JSONObject: ["objects":[
                ["sysObjectId": "id1", "sysUpdated": "2015-08-20"],
                ["sysObjectId": "id2", "sysUpdated": "2015-08-22"],
                ["sysObjectId": "id3", "sysUpdated": "2015-08-21"]
                ]], statusCode: 200, headers: [:])
        }
        
        let model = AXModel()
        model.watch("posts", order: "-updated")
        
        delay(0.5) {
            self.realtimeService.webSocketDidReceiveMessage([
                "event": "object.updated",
                "channel": "objects/posts",
                "data": ["sysObjectId": "id1", "sysUpdated": "2015-08-23"]
                ])
            delay(0.5) {
                async?.fulfill()
            }
        }
        
        waitForExpectationsWithTimeout(3) { error in
            let ids = (model["posts"] as! [AXObject]).map() { $0.objectID! }.joinWithSeparator(",")
            AXAssertEqual(ids, "id1,id2,id3")
        }
    }
    
    func testShouldRemoveObjectWhenReceivingObjectDeleted() {
        weak var async = expectationWithDescription("async")
        AXStubs.method("GET", urlPath: "/objects/posts") { request in
            return OHHTTPStubsResponse(JSONObject: ["objects":[
                ["sysObjectId": "id1", "sysCreated": "2015-08-22"],
                ["sysObjectId": "id2", "sysCreated": "2015-08-21"],
                ["sysObjectId": "id3", "sysCreated": "2015-08-20"]
                ]], statusCode: 200, headers: [:])
        }
        
        let model = AXModel()
        model.watch("posts")
        
        delay(0.5) {
            self.realtimeService.webSocketDidReceiveMessage([
                "event": "object.deleted",
                "channel": "objects/posts",
                "data": ["sysObjectId": "id2"]
            ])
            delay(0.5) {
                async?.fulfill()
            }
        }
        
        waitForExpectationsWithTimeout(3) { error in
            let ids = (model["posts"] as! [AXObject]).map() { $0.objectID! }.joinWithSeparator(",")
            AXAssertEqual(ids, "id1,id3")
        }
    }
    
    func testShouldUpdateObjectInPlaceWhenReceivingObjectUpdated() {
        weak var async = expectationWithDescription("async")
        AXStubs.method("GET", urlPath: "/objects/posts") { request in
            return OHHTTPStubsResponse(JSONObject: ["objects":[
                ["sysObjectId": "id1", "prop": "value1"]
            ]], statusCode: 200, headers: [:])
        }
        
        let model = AXModel()
        model.watch("posts")
        
        var oldObject: AXObject? = nil;
        delay(0.5) {
            oldObject = model["posts"]?[0] as? AXObject
            AXAssertEqual(oldObject?["prop"], "value1")
            
            self.realtimeService.webSocketDidReceiveMessage([
                "event": "object.updated",
                "channel": "objects/posts",
                "data": ["sysObjectId": "id1", "prop": "value2"]
            ])
            delay(0.5) {
                async?.fulfill()
            }
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertEqual(oldObject?["prop"], "value2")
            AXAssertEqual(model["posts"]?[0]["prop"], "value2")
            XCTAssertTrue(oldObject === model["posts"]?[0])
        }
    }
    
    func testShouldTriggerChangeEventAfterReceivingRealtimeObjectEvents() {
        weak var async = expectationWithDescription("async")
        AXStubs.method("GET", urlPath: "/objects/posts") { request in
            return OHHTTPStubsResponse(JSONObject: ["objects":[
                ["sysObjectId": "id1", "prop": "value1"]
            ]], statusCode: 200, headers: [:])
        }
        
        let model = AXModel()
        model.watch("posts")
        
        var changes = 0
        model.on("change") { _ in
            changes++
        }
        
        self.realtimeService.webSocketDidReceiveMessage([
            "event": "object.created",
            "channel": "objects/posts",
            "data": ["sysObjectId": "id1"]
        ])
        self.realtimeService.webSocketDidReceiveMessage([
            "event": "object.updated",
            "channel": "objects/posts",
            "data": ["sysObjectId": "id1"]
        ])
        self.realtimeService.webSocketDidReceiveMessage([
            "event": "object.deleted",
            "channel": "objects/posts",
            "data": ["sysObjectId": "id1"]
        ])
        
        delay(0.3) { async?.fulfill() }
        waitForExpectationsWithTimeout(1) { error in
            AXAssertEqual(changes, 4)
        }
    }
    
    func testShouldAddFilteredArrayPropertyAndSubscribeToFilteredObjects() {
        weak var async = expectationWithDescription("async")
        AXStubs.method("GET", urlPath: "/objects/posts", query:"filter=foo%3D%27bar%27") { request in
            return OHHTTPStubsResponse(JSONObject: ["objects":[
                ["sysObjectId": "id1", "sysCreated": "2015-08-22"],
                ["sysObjectId": "id2", "sysCreated": "2015-08-21"],
                ["sysObjectId": "id3", "sysCreated": "2015-08-20"]
                ]], statusCode: 200, headers: [:])
        }
        
        let model = AXModel()
        
        var channelNames: [String] = []
        var channelFilters: [String] = []
        model.channelFactory = {
            channelNames.append($0)
            channelFilters.append($1)
            return AXChannel($0, filter: $1)
        }
        
        model.watch("posts", filter:"foo='bar'")
        
        delay(0.3) {
            AXAssertEqual(model["posts"]?.count, 3)
            self.realtimeService.webSocketDidReceiveMessage([
                "event": "object.created",
                "channel": "objects/posts",
                "data": ["sysObjectId": "id4", "sysCreated": "2015-08-23"]
                ])
            delay(0.3) {
                async?.fulfill()
            }
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertEqual(model["posts"]?.count, 4)
            AXAssertEqual(model["posts"]?[0].objectID, "id4")
            AXAssertEqual(model["posts"]?[1].objectID, "id1")
            AXAssertEqual(model["posts"]?[2].objectID, "id2")
            AXAssertEqual(model["posts"]?[3].objectID, "id3")
            AXAssertEqual(channelNames.count, 1)
            AXAssertEqual(channelFilters.count, 1)
            AXAssertEqual(channelNames[0], "objects/posts")
            AXAssertEqual(channelFilters[0], "foo='bar'")
        }
    }
    
    func testShouldAddArrayPropertyWithNameAlias() {
        weak var async = expectationWithDescription("async")
        AXStubs.method("GET", urlPath: "/objects/items", query:"filter=foo%3D%27bar%27") { request in
            return OHHTTPStubsResponse(JSONObject: ["objects":[
                ["sysObjectId": "id1", "sysCreated": "2015-08-22"],
                ["sysObjectId": "id2", "sysCreated": "2015-08-21"]
                ]], statusCode: 200, headers: [:])
        }
        AXStubs.method("GET", urlPath: "/objects/items", query:"filter=foo%3D%27baz%27") { request in
            return OHHTTPStubsResponse(JSONObject: ["objects":[
                ["sysObjectId": "id3", "sysCreated": "2015-08-22"],
                ["sysObjectId": "id4", "sysCreated": "2015-08-21"]
                ]], statusCode: 200, headers: [:])
        }
        
        let model = AXModel()
        
        var channelNames: [String] = []
        var channelFilters: [String] = []
        model.channelFactory = {
            channelNames.append($0)
            channelFilters.append($1)
            return AXChannel($0, filter: $1)
        }
        
        model.watch("barItems", collection: "items", expand: nil, order: nil, filter:"foo='bar'")
        model.watch("bazItems", collection: "items", expand: nil, order: nil, filter:"foo='baz'")
        
        XCTAssertTrue(model["barItems"] is [AXObject])
        XCTAssertTrue(model["bazItems"] is [AXObject])
        
        delay(0.3) {
            async?.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertEqual(model["barItems"]?.count, 2)
            AXAssertEqual(model["bazItems"]?.count, 2)
            AXAssertEqual(model["barItems"]?[0].objectID, "id1")
            AXAssertEqual(model["barItems"]?[1].objectID, "id2")
            AXAssertEqual(model["bazItems"]?[0].objectID, "id3")
            AXAssertEqual(model["bazItems"]?[1].objectID, "id4")
            AXAssertEqual(channelNames.count, 2)
            AXAssertEqual(channelFilters.count, 2)
            AXAssertEqual(channelNames[0], "objects/items")
            AXAssertEqual(channelNames[1], "objects/items")
            AXAssertEqual(channelFilters[0], "foo='bar'")
            AXAssertEqual(channelFilters[1], "foo='baz'")
        }
    }
    
    // MARK: Relations

    func testRelationsShouldBeLoadedInitiallyWhenExpandIsSpecified() {
        weak var async = expectationWithDescription("async")
        AXStubs.method("GET", urlPath: "/objects/items", query: "expanddepth=2", response: itemsResponse, statusCode: 200)
        
        let model = AXModel()
        model.watch("items", expand: 2)
        
        delay(0.3) {
            async?.fulfill()
        }

        waitForExpectationsWithTimeout(3) { error in
            AXAssertEqual(model["items"]?.count, 1)
            AXAssertEqual(model["items"]?[0].object("prop1")?.objectID, "id1")
            AXAssertEqual(model["items"]?[0].objects("prop2")?[0].objectID, "id2")
            AXAssertEqual(model["items"]?[0].objects("prop2")?[1].objectID, "id3")
        }
    }
    
    func testShouldSubscribeToUnfilteredObjectChannelsForRelatedCollections() {
        weak var async = expectationWithDescription("async")
        AXStubs.method("GET", urlPath: "/objects/items", query: "expanddepth=2", response: itemsResponse, statusCode: 200)
        
        let model = AXModel()
        
        var channelNames: [String] = []
        var channelFilters: [String] = []
        model.channelFactory = {
            channelNames.append($0)
            channelFilters.append($1)
            return AXChannel($0, filter: $1)
        }
        
        model.watch("items", expand: 2)
        delay(0.3) {
            async?.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertEqual(channelNames.count, 3)
            AXAssertEqual(channelFilters.count, 3)
            AXAssertEqual(channelNames[0], "objects/items")
            AXAssertEqual(channelNames[1], "objects/collection2")
            AXAssertEqual(channelNames[2], "objects/collection3")
            AXAssertEqual(channelFilters[0], "")
            AXAssertEqual(channelFilters[1], "")
            AXAssertEqual(channelFilters[2], "")
        }
    }
    
    func testShouldUpdateRelatedObjectsInPlace() {
        weak var async = expectationWithDescription("async")
        AXStubs.method("GET", urlPath: "/objects/items", query: "expanddepth=1", response: itemsResponse, statusCode: 200)
        
        let model = AXModel()
        model.watch("items", expand: 1)
        
        var cached: [String:AXObject?] = [:]
        delay(0.3) {
            cached["item0"] = model["items"]?[0] as? AXObject
            cached["item0_prop1"] = model["items"]?[0].object("prop1")
            cached["item0_prop2_1"] = model["items"]?[0].objects("prop2")?[1]
            
            self.realtimeService.webSocketDidReceiveMessage([
                "event": "object.updated",
                "channel": "objects/collection2",
                "data": ["sysObjectId": "id1", "prop3": "value3 new!"]
            ])
            
            self.realtimeService.webSocketDidReceiveMessage([
                "event": "object.updated",
                "channel": "objects/collection3",
                "data": ["sysObjectId": "id3", "prop4": "value4b new!"]
            ])
            
            delay(0.3) {
                async?.fulfill()
            }
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertEqual(model["items"]?[0].object("prop1")?["prop3"], "value3 new!")
            AXAssertEqual(model["items"]?[0].objects("prop2")?[1]["prop4"], "value4b new!")
            
            // check object normalization
            AXAssertEqual(model["items"]?[0], cached["item0"] ?? nil)
            AXAssertEqual(model["items"]?[0].object("prop1"), cached["item0_prop1"] ?? nil)
            AXAssertEqual(model["items"]?[0].objects("prop2")?[1], cached["item0_prop2_1"] ?? nil)
        }
    }
    
    func testShouldReExpandRelationsWhenUpdatingAnObjectLoadedWithRelations() {
        weak var async = expectationWithDescription("async")
        
        var item0ExpandResponse = itemsResponse["objects"]![0]
        item0ExpandResponse["prop2b"] = "prop2b is new"

        AXStubs.method("GET", urlPath: "/objects/items",     query: "expanddepth=1", response: itemsResponse, statusCode: 200)
        AXStubs.method("GET", urlPath: "/objects/items/id0", query: "expanddepth=1", response: item0ExpandResponse, statusCode: 200)
        
        let model = AXModel()
        model.watch("items", expand: 1)
        
        var cached: [String:AXObject?] = [:]
        delay(0.3) {
            cached["item0"] = model["items"]?[0] as? AXObject
            cached["item0_prop1"] = model["items"]?[0].object("prop1")
            cached["item0_prop2_1"] = model["items"]?[0].objects("prop2")?[1]
            
            self.realtimeService.webSocketDidReceiveMessage([
                "event": "object.updated",
                "channel": "objects/items",
                "data": [
                    "sysObjectId": "id0",
                    "prop1": [
                        "sysDatatype": "relation",
                        "sysRelationType": "single",
                        "sysCollection": "collection2",
                        "sysObjects": ["id1"] // realtime updates are not expanded
                    ],
                    "prop2": [
                        "sysDatatype": "relation",
                        "sysRelationType": "array",
                        "sysCollection": "collection3",
                        "sysObjects": ["id2", "id3"] // realtime updates are not expanded
                    ],
                    "prop2b": "prop2b is new"
                ]
            ])
            
            delay(0.3) {
                async?.fulfill()
            }
        }
        
        waitForExpectationsWithTimeout(30) { error in
            AXAssertEqual(model["items"]?[0].string("prop2b"), "prop2b is new")
            AXAssertEqual(model["items"]?[0].object("prop1")?["prop3"], "value3")
            AXAssertEqual(model["items"]?[0].objects("prop2")?[1]["prop4"], "value4b")
            
            // check object normalization
            AXAssertEqual(model["items"]?[0], cached["item0"] ?? nil)
            AXAssertEqual(model["items"]?[0].object("prop1"), cached["item0_prop1"] ?? nil)
            AXAssertEqual(model["items"]?[0].objects("prop2")?[1], cached["item0_prop2_1"] ?? nil)
        }
    }
    
    func testShouldUpdateDeepObjectsAndReExpandRelations() {
        weak var async = expectationWithDescription("async")
        
        let id1ExpandResponse = [
            "sysObjectId": "id1",
            "prop2": "value2 new!",
            "prop3": [
                "sysDatatype": "relation",
                "sysRelationType": "single",
                "sysCollection": "collection3",
                "sysObjects": [[
                    "sysObjectId": "id2",
                    "prop4": "value4 new!"
                ]]
            ]
        ]
        
        AXStubs.method("GET", urlPath: "/objects/items", query: "expanddepth=2", response: itemsResponseDeep, statusCode: 200)
        AXStubs.method("GET", urlPath: "/objects/collection2/id1", query: "expanddepth=1", response: id1ExpandResponse, statusCode: 200)
        
        let model = AXModel()
        model.watch("items", expand: 2)
        
        var cached: [String:AXObject?] = [:]
        delay(0.3) {
            cached["item0"] = model["items"]?[0] as? AXObject
            cached["item0_prop1"] = model["items"]?[0].object("prop1")
            cached["item0_prop1_prop3"] = model["items"]?[0].object("prop1")?.object("prop3")
            
            self.realtimeService.webSocketDidReceiveMessage([
                "event": "object.updated",
                "channel": "objects/collection2",
                "data": [
                    "sysObjectId": "id1",
                    "prop2": "value2 new!",
                    "prop3": [
                        "sysDatatype": "relation",
                        "sysRelationType": "single",
                        "sysCollection": "collection3",
                        "sysObjects": ["id2"]
                    ]
                ]
            ])
            
            delay(0.3) {
                async?.fulfill()
            }
        }
        
        waitForExpectationsWithTimeout(30) { error in
            AXAssertEqual(model["items"]?[0].string("prop1.prop2"), "value2 new!")
            AXAssertEqual(model["items"]?[0].string("prop1.prop3.prop4"), "value4 new!")
            
            // check object normalization
            AXAssertEqual(model["items"]?[0], cached["item0"] ?? nil)
            AXAssertEqual(model["items"]?[0].object("prop1"), cached["item0_prop1"] ?? nil)
            AXAssertEqual(model["items"]?[0].object("prop1")?.object("prop3"), cached["item0_prop1_prop3"] ?? nil)
        }
    }
    
    func testShouldUpdateDeepObjectsInArrayAndReExpandRelations() {
        weak var async = expectationWithDescription("async")
        
        let id1ExpandResponse = [
            "sysObjectId": "id1",
            "prop2": "value2 new!",
            "prop3": [
                "sysDatatype": "relation",
                "sysRelationType": "single",
                "sysCollection": "collection3",
                "sysObjects": [[
                    "sysObjectId": "id2",
                    "prop4": "value4 new!"
                ]]
            ]
        ]
        
        AXStubs.method("GET", urlPath: "/objects/items", query: "expanddepth=2", response: itemsResponseDeepArray, statusCode: 200)
        AXStubs.method("GET", urlPath: "/objects/collection2/id1", query: "expanddepth=1", response: id1ExpandResponse, statusCode: 200)
        
        let model = AXModel()
        model.watch("items", expand: 2)
        
        var cached: [String:AXObject?] = [:]
        delay(0.3) {
            cached["item0"] = model["items"]?[0] as? AXObject
            cached["item0_prop1_0"] = model["items"]?[0].objects("prop1")?[0]
            cached["item0_prop1_0_prop3"] = model["items"]?[0].objects("prop1")?[0].object("prop3")
            
            self.realtimeService.webSocketDidReceiveMessage([
                "event": "object.updated",
                "channel": "objects/collection2",
                "data": [
                    "sysObjectId": "id1",
                    "prop2": "value2 new!",
                    "prop3": [
                        "sysDatatype": "relation",
                        "sysRelationType": "single",
                        "sysCollection": "collection3",
                        "sysObjects": ["id2"]
                    ]
                ]
            ])
            
            delay(0.3) {
                async?.fulfill()
            }
        }
        
        waitForExpectationsWithTimeout(30) { error in
            AXAssertEqual(model["items"]?[0].objects("prop1")?[0].string("prop2"), "value2 new!")
            AXAssertEqual(model["items"]?[0].objects("prop1")?[0].string("prop3.prop4"), "value4 new!")
            
            // check object normalization
            AXAssertEqual(model["items"]?[0], cached["item0"] ?? nil)
            AXAssertEqual(model["items"]?[0].objects("prop1")?[0], cached["item0_prop1_0"] ?? nil)
            AXAssertEqual(model["items"]?[0].objects("prop1")?[0].object("prop3"), cached["item0_prop1_0_prop3"] ?? nil)
        }
    }
    
    func testShouldGetUpdatesForRelatedObjectAppearingAfterInitialLoad() {
        weak var async = expectationWithDescription("async")
        
        let initialResponse = ["objects":[["sysObjectId":"id000"]]]
        let expandResponse = [
            "sysObjectId": "id000",
            "prop1": [
                "sysDatatype": "relation",
                "sysRelationType": "single",
                "sysCollection": "collection2",
                "sysObjects": [[
                    "sysObjectId": "id001",
                    "prop2": "value2"
                ]]
            ]
        ]
        
        AXStubs.method("GET", urlPath: "/objects/items", query: "expanddepth=1", response: initialResponse, statusCode: 200)
        AXStubs.method("GET", urlPath: "/objects/items/id000", query: "expanddepth=1", response: expandResponse, statusCode: 200)
        
        let model = AXModel()
        model.watch("items", expand: 1)
        
        delay(0.3) {
            self.realtimeService.webSocketDidReceiveMessage([
                "event": "object.updated",
                "channel": "objects/items",
                "data": [
                    "sysObjectId":"id000",
                    "prop1": [
                        "sysDatatype": "relation",
                        "sysRelationType": "single",
                        "sysCollection": "collection2",
                        "sysObjects": ["id001"]
                    ]
                ]
            ])
            
            delay(0.3) {
                AXAssertEqual(model["items"]?[0].string("prop1.prop2"), "value2")
                
                self.realtimeService.webSocketDidReceiveMessage([
                    "event": "object.updated",
                    "channel": "objects/collection2",
                    "data": [
                        "sysObjectId":"id001",
                        "prop2": "value2 new!"
                    ]
                ])
                
                delay(0.3) {
                    async?.fulfill()
                }
            }
        }
        
        waitForExpectationsWithTimeout(30) { error in
            AXAssertEqual(model["items"]?[0].string("prop1.prop2"), "value2 new!")
        }
    }
    
    // MARK: Status

    func testShouldTriggerChangeEventsAndUpdateStatusTroughoutConnectionLifecycle() {
        let async = expectationWithDescription("async")
        
        AXStubs.method("POST", urlPath: "/messaging/realtime/sessions") { request in
            return OHHTTPStubsResponse(JSONObject: ["realtimeSessionId":"testrsession"], statusCode: 200, headers: [:])
        }
        realtimeService.webSocketFactory = { _ in
            return MockWebSocket(self.realtimeService)
        }
        
        var statusChanges: [String] = []
        let model = AXModel()
        model.on("change") { event in
            statusChanges.append(model["status"] as? String ?? "")
        }
        model.watch("status")
        
        
        delay(1) {
            AXAssertEqual(statusChanges.count, 2)
            self.realtimeService.webSocketDidDisconnect(nil)
            delay(3) {
                AXAssertEqual(statusChanges.count, 4)
                async.fulfill()
            }
        }
        waitForExpectationsWithTimeout(10) { error in
            AXAssertEqual(statusChanges[0], "connecting")
            AXAssertEqual(statusChanges[1], "connected")
            AXAssertEqual(statusChanges[2], "connecting")
            AXAssertEqual(statusChanges[3], "connected")
        }
    }
    
}



private class MockWebSocket: AXWebSocketAdapter {

    init(_ realtimeService: AXRealtimeService) {
        delay(0.5) {
            realtimeService.webSocketDidConnect()
        }
    }
    
    func send(message:AnyObject) {}
    
}

