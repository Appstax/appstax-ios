
import Foundation
import XCTest
@testable import Appstax

@objc class RealtimeTests: XCTestCase {
    
    private var realtimeService: AXRealtimeService!
    private var appKeyHeader: String?
    private var websocketUrl: NSURL?
    private var serverReceived: [[String:AnyObject]] = []
    private var sessionRequestShouldFail = false
    private var websocketRequestShouldFail = false
    
    override func setUp() {
        super.setUp()
        OHHTTPStubs.setEnabled(true)
        OHHTTPStubs.removeAllStubs()
        Appstax.setAppKey("testappkey", baseUrl:"http://localhost:3000/");
        Appstax.setLogLevel("debug");
        realtimeService = Appstax.defaultContext.realtimeService
        
        appKeyHeader = nil
        websocketUrl = nil
        serverReceived = []
        sessionRequestShouldFail = false
        websocketRequestShouldFail = false
        AXStubs.method("POST", urlPath: "/messaging/realtime/sessions") { request in
            self.appKeyHeader = request.allHTTPHeaderFields?["x-appstax-appkey"]
            if self.sessionRequestShouldFail {
                return OHHTTPStubsResponse(JSONObject: ["":""], statusCode: 422, headers: [:])
            } else {
                return OHHTTPStubsResponse(JSONObject: ["realtimeSessionId":"testrsession"], statusCode: 200, headers: [:])
            }
        }
        realtimeService.webSocketFactory = {
            self.websocketUrl = $0
            let webSocket = MockWebSocket(self.realtimeService, fail: self.websocketRequestShouldFail) {
                self.serverReceived.append($0)
            }
            return webSocket
        }
    }
    
    override func tearDown() {
        super.tearDown()
        OHHTTPStubs.setEnabled(false)
    }
    
    func serverSend(dict: [String:AnyObject]) {
        realtimeService.webSocketDidReceiveMessage(dict)
    }
    
    func testShouldGetRealtimeSessionAndConnectToWebsocket() {
        let async = expectationWithDescription("async")
        
        let channel = AXChannel("public/chat")
        channel.on("open") { _ in
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertEqual(self.appKeyHeader, "testappkey")
            AXAssertNotNil(self.websocketUrl)
            AXAssertEqual(self.websocketUrl?.absoluteString, "ws://localhost:3000/messaging/realtime?rsession=testrsession")
        }
    }
    
    func testShouldReconnectIfDisconnected() {
        let async = expectationWithDescription("async")
        
        let channel = AXChannel("public/chat")
        var channelOpen = 0
        channel.on("open") { _ in
            channelOpen += 1
        }
        
        delay(2) {
            self.realtimeService.webSocketDidDisconnect(nil)
            delay(2) {
                channel.send("Message!")
                delay(2, async.fulfill)
            }
        }
        waitForExpectationsWithTimeout(10) { error in
            AXAssertEqual(channelOpen, 2)
            AXAssertEqual(self.serverReceived.count, 2)
            AXAssertEqual(self.serverReceived[0]["command"], "subscribe")
            AXAssertEqual(self.serverReceived[1]["command"], "publish")
            AXAssertEqual(self.serverReceived[1]["message"], "Message!")
        }
    }
    
    func testShouldSendSubscribeCommandToServerAndOpenEventToClient() {
        let async = expectationWithDescription("async")
        
        let channel = AXChannel("public/chat")
        var channelOpen = false
        channel.on("open") { _ in
            channelOpen = true
        }
        
        delay(1, async.fulfill)
        waitForExpectationsWithTimeout(3) { error in
            XCTAssertTrue(channelOpen)
            AXAssertEqual(self.serverReceived.count, 1)
            AXAssertEqual(self.serverReceived[0]["command"], "subscribe")
            AXAssertEqual(self.serverReceived[0]["channel"], "public/chat")
        }
    }
    
    func testShouldGetErrorEventWhenSessionRequestFails() {
        sessionRequestShouldFail = true
        let async = expectationWithDescription("async")
        
        let channel = AXChannel("public/chat")
        var channelOpen = false
        var channelError = false
        channel.on("open") { _ in
            channelOpen = true
        }
        channel.on("error") { _ in
            channelError = true
        }
        
        delay(1, async.fulfill)
        waitForExpectationsWithTimeout(3) { error in
            XCTAssertFalse(channelOpen)
            XCTAssertTrue(channelError)
        }
    }
    
    func testShouldGetErrorEventWhenWebSocketRequestFails() {
        websocketRequestShouldFail = true
        let async = expectationWithDescription("async")
        
        let channel = AXChannel("public/chat")
        var channelOpen = false
        var channelError = false
        channel.on("open") { _ in
            channelOpen = true
        }
        channel.on("error") { _ in
            channelError = true
        }
        
        delay(1, async.fulfill)
        waitForExpectationsWithTimeout(3) { error in
            XCTAssertFalse(channelOpen)
            XCTAssertTrue(channelError)
        }
    }
    
    func testShouldSendMessagesWithIdToServer() {
        let async = expectationWithDescription("async")
        
        let channel = AXChannel("public/chat")
        channel.send("This is my first message!")
        channel.send("This is my second message!")
        
        delay(1, async.fulfill)
        waitForExpectationsWithTimeout(3) { error in
            AXAssertEqual(self.serverReceived.count, 3)
            AXAssertEqual(self.serverReceived[1]["command"], "publish")
            AXAssertEqual(self.serverReceived[1]["channel"], "public/chat")
            AXAssertEqual(self.serverReceived[1]["message"], "This is my first message!")
            AXAssertEqual(self.serverReceived[2]["command"], "publish")
            AXAssertEqual(self.serverReceived[2]["channel"], "public/chat")
            AXAssertEqual(self.serverReceived[2]["message"], "This is my second message!")
            
            AXAssertNotNil(self.serverReceived[0]["id"])
            AXAssertNotNil(self.serverReceived[1]["id"])
            AXAssertNotNil(self.serverReceived[2]["id"])
            let id1 = self.serverReceived[0]["id"] as! NSString
            let id2 = self.serverReceived[1]["id"] as! String
            XCTAssertFalse(id1.isEqualToString(id2))
        }
    }
    
    func testShouldMapServerEventsToChannels() {
        let async = expectationWithDescription("async")
        
        let chat = AXChannel("public/chat")
        var chatReceived: [AXChannelEvent] = []
        chat.on("message") { chatReceived.append($0) }
        chat.on("error") { chatReceived.append($0) }
        
        let stocks = AXChannel("public/stocks")
        var stocksReceived: [AXChannelEvent] = []
        stocks.on("message") { stocksReceived.append($0) }
        stocks.on("error") { stocksReceived.append($0) }
        
        delay(0.2) {
            self.serverSend(["channel":"public/chat", "event":"message", "message":"Hello World!"])
            self.serverSend(["channel":"public/chat", "event":"error", "error":"Bad dog!"])
            self.serverSend(["channel":"public/stocks", "event":"message", "message":["AAPL": 127.61]])
            self.serverSend(["channel":"public/stocks", "event":"error", "error":"Bad stock!"])
            delay(0.1, async.fulfill)
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertEqual(chatReceived.count, 2)
            AXAssertEqual(stocksReceived.count, 2)
            
            AXAssertEqual(chatReceived[0].channel, "public/chat")
            AXAssertEqual(chatReceived[0].message, "Hello World!")
            AXAssertNil(chatReceived[0].error)
            
            AXAssertEqual(chatReceived[1].channel, "public/chat")
            AXAssertEqual(chatReceived[1].error, "Bad dog!")
            AXAssertNil(chatReceived[1].message)
            
            AXAssertEqual(stocksReceived[0].channel, "public/stocks")
            AXAssertEqual(stocksReceived[0].message?["AAPL"], 127.61)
            AXAssertNil(stocksReceived[0].error)
            
            AXAssertEqual(stocksReceived[1].channel, "public/stocks")
            AXAssertEqual(stocksReceived[1].error, "Bad stock!")
            AXAssertNil(stocksReceived[1].message)
        }
    }
    
    func testShouldMapServerEventsToWildcardChannels() {
        let async = expectationWithDescription("async")
        
        let a1 = AXChannel("public/a/1")
        let a2 = AXChannel("public/a/2")
        let aw = AXChannel("public/a/*")
        let b1 = AXChannel("public/b/1")
        let b2 = AXChannel("public/b/2")
        let bw = AXChannel("public/b/*")
        
        var received: [String:[AXChannelEvent]] = ["a1":[],"a2":[],"aw":[],"b1":[],"b2":[],"bw":[]]
        a1.on("message") { received["a1"]?.append($0) }
        a2.on("message") { received["a2"]?.append($0) }
        aw.on("message") { received["aw"]?.append($0) }
        b1.on("message") { received["b1"]?.append($0) }
        b2.on("message") { received["b2"]?.append($0) }
        bw.on("message") { received["bw"]?.append($0) }
        
        delay(0.2) {
            self.serverSend(["channel":"public/a/1", "event":"message", "message":"A1"])
            self.serverSend(["channel":"public/a/2", "event":"message", "message":"A2"])
            self.serverSend(["channel":"public/b/1", "event":"message", "message":"B1"])
            self.serverSend(["channel":"public/b/2", "event":"message", "message":"B2"])
            delay(0.1, async.fulfill)
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertEqual(received["a1"]?.count, 1)
            AXAssertEqual(received["a2"]?.count, 1)
            AXAssertEqual(received["aw"]?.count, 2)
            AXAssertEqual(received["b1"]?.count, 1)
            AXAssertEqual(received["b2"]?.count, 1)
            AXAssertEqual(received["bw"]?.count, 2)
        }
    }
    
    func testShouldMapServerEventsToWildcardEventHandlers() {
        let async = expectationWithDescription("async")
        
        let a1 = AXChannel("public/a/1")
        let a2 = AXChannel("public/a/2")
        let aw = AXChannel("public/a/*")
        let b1 = AXChannel("public/b/1")
        let b2 = AXChannel("public/b/2")
        let bw = AXChannel("public/b/*")
        
        var received: [String:[AXChannelEvent]] = ["a1":[],"a2":[],"aw":[],"b1":[],"b2":[],"bw":[]]
        a1.on("*") { received["a1"]?.append($0) }
        a2.on("*") { received["a2"]?.append($0) }
        aw.on("*") { received["aw"]?.append($0) }
        b1.on("*") { received["b1"]?.append($0) }
        b2.on("*") { received["b2"]?.append($0) }
        bw.on("*") { received["bw"]?.append($0) }
        
        delay(1.0) {
            self.serverSend(["channel":"public/a/1", "event":"message", "message":"A1"])
            self.serverSend(["channel":"public/a/2", "event":"message", "message":"A2"])
            self.serverSend(["channel":"public/b/1", "event":"message", "message":"B1"])
            self.serverSend(["channel":"public/b/2", "event":"message", "message":"B2"])
            delay(0.1, async.fulfill)
        }
        
        waitForExpectationsWithTimeout(3) { error in
            AXAssertEqual(received["a1"]?[0].type, "status")
            AXAssertEqual(received["a2"]?[0].type, "status")
            AXAssertEqual(received["aw"]?[0].type, "status")
            AXAssertEqual(received["b1"]?[0].type, "status")
            AXAssertEqual(received["b2"]?[0].type, "status")
            AXAssertEqual(received["bw"]?[0].type, "status")
            
            AXAssertEqual(received["a1"]?[1].type, "open")
            AXAssertEqual(received["a2"]?[1].type, "open")
            AXAssertEqual(received["aw"]?[1].type, "open")
            AXAssertEqual(received["b1"]?[1].type, "open")
            AXAssertEqual(received["b2"]?[1].type, "open")
            AXAssertEqual(received["bw"]?[1].type, "open")
            
            AXAssertEqual(received["a1"]?[2].type, "message")
            AXAssertEqual(received["a2"]?[2].type, "message")
            AXAssertEqual(received["aw"]?[2].type, "message")
            AXAssertEqual(received["b1"]?[2].type, "message")
            AXAssertEqual(received["b2"]?[2].type, "message")
            AXAssertEqual(received["bw"]?[2].type, "message")
            
            AXAssertEqual(received["a1"]?[2].channel, "public/a/1")
            AXAssertEqual(received["a2"]?[2].channel, "public/a/2")
            AXAssertEqual(received["aw"]?[2].channel, "public/a/1")
            AXAssertEqual(received["aw"]?[3].channel, "public/a/2")
            AXAssertEqual(received["b1"]?[2].channel, "public/b/1")
            AXAssertEqual(received["b2"]?[2].channel, "public/b/2")
            AXAssertEqual(received["bw"]?[2].channel, "public/b/1")
            AXAssertEqual(received["bw"]?[3].channel, "public/b/2")
        }
    }
    
    func testShouldSubscribeToAPrivateChannel() {
        let async = expectationWithDescription("async")
        
        let _ = AXChannel("private/mychannel")
        
        delay(1, async.fulfill)
        waitForExpectationsWithTimeout(3) { error in
            AXAssertEqual(self.serverReceived.count, 1)
            AXAssertEqual(self.serverReceived[0]["command"], "subscribe")
            AXAssertEqual(self.serverReceived[0]["channel"], "private/mychannel")
        }
    }
    
    func testShouldGrantPermissionsOnPrivateChannels() {
        let async = expectationWithDescription("async")
        
        let channel = AXChannel("private/mychannel")
        channel.grant("buddy", permissions:["read"])
        channel.grant("friend", permissions:["read", "write"])
        channel.revoke("buddy", permissions:["read", "write"])
        channel.revoke("friend", permissions:["write"])
        
        delay(1, async.fulfill)
        waitForExpectationsWithTimeout(8) { error in
            AXAssertEqual(self.serverReceived.count, 8)
            AXAssertEqual(self.serverReceived[0]["command"], "subscribe")
            AXAssertEqual(self.serverReceived[0]["channel"], "private/mychannel")
            AXAssertEqual(self.serverReceived[1]["command"], "channel.create")
            AXAssertEqual(self.serverReceived[1]["channel"], "private/mychannel")
            AXAssertEqual(self.serverReceived[2]["channel"], "private/mychannel")
            AXAssertEqual(self.serverReceived[2]["command"], "grant.read")
            AXAssertEqual((self.serverReceived[2]["data"] as! [String])[0], "buddy")
            AXAssertEqual(self.serverReceived[3]["channel"], "private/mychannel")
            AXAssertEqual(self.serverReceived[3]["command"], "grant.read")
            AXAssertEqual((self.serverReceived[3]["data"] as! [String])[0], "friend")
            AXAssertEqual(self.serverReceived[4]["channel"], "private/mychannel")
            AXAssertEqual(self.serverReceived[4]["command"], "grant.write")
            AXAssertEqual((self.serverReceived[4]["data"] as! [String])[0], "friend")
            AXAssertEqual(self.serverReceived[5]["channel"], "private/mychannel")
            AXAssertEqual(self.serverReceived[5]["command"], "revoke.read")
            AXAssertEqual((self.serverReceived[5]["data"] as! [String])[0], "buddy")
            AXAssertEqual(self.serverReceived[6]["channel"], "private/mychannel")
            AXAssertEqual(self.serverReceived[6]["command"], "revoke.write")
            AXAssertEqual((self.serverReceived[6]["data"] as! [String])[0], "buddy")
            AXAssertEqual(self.serverReceived[7]["channel"], "private/mychannel")
            AXAssertEqual(self.serverReceived[7]["command"], "revoke.write")
            AXAssertEqual((self.serverReceived[7]["data"] as! [String])[0], "friend")
        }
    }
    
    func testShouldSubscribeToObjectChannel() {
        let async = expectationWithDescription("async")
        
        let _ = AXChannel("objects/mycollection")
        
        delay(1, async.fulfill)
        waitForExpectationsWithTimeout(8) { error in
            AXAssertEqual(self.serverReceived.count, 1)
            AXAssertEqual(self.serverReceived[0]["channel"], "objects/mycollection")
            AXAssertEqual(self.serverReceived[0]["command"], "subscribe")
        }
    }
    
    func testShouldSubscribeToObjectChannelWithFilter() {
        let async = expectationWithDescription("async")
        
        let _ = AXChannel("objects/mycollection", filter: "text like Hello%")
        
        delay(1, async.fulfill)
        waitForExpectationsWithTimeout(8) { error in
            AXAssertEqual(self.serverReceived.count, 1)
            AXAssertEqual(self.serverReceived[0]["channel"], "objects/mycollection")
            AXAssertEqual(self.serverReceived[0]["command"], "subscribe")
            AXAssertEqual(self.serverReceived[0]["filter"], "text like Hello%")
        }
    }
    
    func testShouldConvertReceivedDataToAppstaxObjects() {
        let async = expectationWithDescription("async")
        
        let channel = AXChannel("objects/mycollection3")
        var receivedObjects: [AXObject?] = []
        channel.on("object.created") { receivedObjects.append($0.object) }
        channel.on("object.updated") { receivedObjects.append($0.object) }
        channel.on("object.deleted") { receivedObjects.append($0.object) }
        
        delay(1) {
            self.serverSend([
                "channel": "objects/mycollection3",
                "event": "object.created",
                "data": ["sysObjectId":"id1", "prop1":"value1"]
            ])
            self.serverSend([
                "channel": "objects/mycollection3",
                "event": "object.updated",
                "data": ["sysObjectId":"id2", "prop2":"value2"]
                ])
            self.serverSend([
                "channel": "objects/mycollection3",
                "event": "object.deleted",
                "data": ["sysObjectId":"id3", "prop3":"value3"]
                ])
            delay(0.1, async.fulfill)
        }
        
        waitForExpectationsWithTimeout(8) { error in
            AXAssertEqual(receivedObjects.count, 3)
            AXAssertEqual(receivedObjects[0]?.objectID, "id1")
            AXAssertEqual(receivedObjects[0]?.collectionName, "mycollection3")
            AXAssertEqual(receivedObjects[0]?.string("prop1"), "value1")
            AXAssertEqual(receivedObjects[1]?.objectID, "id2")
            AXAssertEqual(receivedObjects[1]?.collectionName, "mycollection3")
            AXAssertEqual(receivedObjects[1]?.string("prop2"), "value2")
            AXAssertEqual(receivedObjects[2]?.objectID, "id3")
            AXAssertEqual(receivedObjects[2]?.collectionName, "mycollection3")
            AXAssertEqual(receivedObjects[2]?.string("prop3"), "value3")
        }
    }
    
    func testShouldTriggerStatusEventsThrougoutConnectionLifecycle() {
        let async = expectationWithDescription("async")
        
        var statusChanges: [[String:AnyObject]] = []
        realtimeService.on("status") { event in
            let status = self.realtimeService.status
            statusChanges.append(["eventType": event.type, "status": status.rawValue])
        }
        
        AXAssertEqual(realtimeService.status.rawValue, AXRealtimeServiceStatus.Disconnected.rawValue)
        
        let channel = AXChannel("public/foo")
        channel.send("foo")
        
        delay(1) {
            AXAssertEqual(statusChanges.count, 2)
            self.realtimeService.webSocketDidDisconnect(nil)
            delay(3) {
                AXAssertEqual(statusChanges.count, 4)
                async.fulfill()
            }
        }
        waitForExpectationsWithTimeout(10) { error in
            AXAssertEqual(statusChanges[0]["status"], AXRealtimeServiceStatus.Connecting.rawValue)
            AXAssertEqual(statusChanges[1]["status"], AXRealtimeServiceStatus.Connected.rawValue)
            AXAssertEqual(statusChanges[2]["status"], AXRealtimeServiceStatus.Connecting.rawValue)
            AXAssertEqual(statusChanges[3]["status"], AXRealtimeServiceStatus.Connected.rawValue)
        }
    }
    

}

private class MockWebSocket: AXWebSocketAdapter {
    
    private var realtimeService: AXRealtimeService!
    private var received: ([String:AnyObject])->()

    init(_ realtimeService: AXRealtimeService, fail: Bool, received: ([String:AnyObject])->()) {
        self.realtimeService = realtimeService
        self.received = received
        delay(0.5) {
            if fail {
                self.realtimeService.webSocketDidDisconnect(NSError(domain: "webSocketDidDisconnect", code: 0, userInfo: nil))
            } else {
                self.realtimeService.webSocketDidConnect()
            }
        }
    }
    
    func send(message:AnyObject) {
        if let packet = message as? [String:AnyObject] {
            received(packet)
        }
    }
    
}
