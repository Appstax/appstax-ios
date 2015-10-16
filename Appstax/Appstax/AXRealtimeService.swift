
import Foundation
import Starscream

@objc public enum AXRealtimeServiceStatus: NSInteger {
    case Disconnected
    case Connecting
    case Connected
}

class AXRealtimeService: NSObject {
    
    private var apiClient: AXApiClient
    private var status: AXRealtimeServiceStatus = .Disconnected
    private var connectionCheckTimer: NSTimer?
    private var webSocket: AXWebSocketAdapter?
    private var realtimeSessionRequested: Bool = false
    private var realtimeSessionId: String?
    private var eventHub = AXEventHub()
    private var queue: [[String:AnyObject]] = []
    private var idCounter = 0
    
    var webSocketFactory: ((url: NSURL) -> (AXWebSocketAdapter))?
    
    init(apiClient: AXApiClient) {
        self.apiClient = apiClient
        super.init()
        self.webSocketFactory = {
            return StarscreamWrapper(url: $0, service: self)
        }
    }
    
    func on(type: String, handler: (AXEvent) -> ()) {
        eventHub.on(type, handler: handler)
    }
    
    func send(command command: String, channel: String, message: AnyObject? = nil, data: AnyObject? = nil, filter: String? = nil) {
        var packet: [String:AnyObject] = [:]
        packet["id"] = "id \(idCounter++)"
        packet["command"] = command
        packet["channel"] = channel
        if message != nil {
            packet["message"] = message
        }
        if data != nil {
            packet["data"] = data
        }
        if filter != nil {
            packet["filter"] = filter
        }
        sendPacket(packet)
    }
    
    private func sendPacket(packet: [String:AnyObject]) {
        if let ws = webSocket {
            ws.send(packet)
        } else {
            queue.append(packet)
            connect()
        }
    }
    
    private func sendQueue() {
        while queue.count > 0 && webSocket != nil {
            webSocket?.send(queue.removeFirst())
        }
    }
    
    func connect() {
        if !realtimeSessionRequested {
            connectSession()
        }
        if connectionCheckTimer == nil {
            connectionCheckTimer = NSTimer.scheduledTimerWithTimeInterval(2.0, target: self, selector: "checkConnection", userInfo: nil, repeats: true)
        }
    }
    
    func checkConnection() {
        if webSocket == nil || status == .Disconnected {
            status = .Connecting
            connectWebSocket()
        }
    }
    
    func connectSession() {
        status = .Connecting
        realtimeSessionRequested = true
        let url = apiClient.urlFromTemplate("/messaging/realtime/sessions", parameters: [:])!
        apiClient.postDictionary([:], toUrl: url) {
            dictionary, error in
            if error == nil {
                self.realtimeSessionId = dictionary?["realtimeSessionId"] as? String
                self.connectionCheckTimer?.fire()
            } else {
                self.eventHub.dispatch(AXEvent(type: "error"))
            }
        }
    }
    
    func connectWebSocket() {
        if realtimeSessionId != nil {
            if let url = webSocketUrl() {
                webSocket = webSocketFactory?(url: url)
            }
        }
    }
    
    func webSocketUrl() -> NSURL? {
        let rs = realtimeSessionId ?? ""
        if let httpUrl = apiClient.urlFromTemplate("/messaging/realtime", parameters: [:], queryParameters: ["rsession":rs]) {
            return NSURL(string: httpUrl.absoluteString.stringByReplacingOccurrencesOfString("http", withString: "ws"))
        }
        return nil
    }
    
    func webSocketDidConnect() {
        status = .Connected
        eventHub.dispatch(AXEvent(type: "open"))
        sendQueue()
    }
    
    func webSocketDidDisconnect(error: NSError?) {
        eventHub.dispatch(AXEvent(type: "error"))
    }
    
    func webSocketDidReceiveMessage(dict: [String:AnyObject]) {
        eventHub.dispatch(AXChannelEvent(dict))
    }
    
}

protocol AXWebSocketAdapter {
    
    func send(message:AnyObject)
}

class StarscreamWrapper: AXWebSocketAdapter, WebSocketDelegate {
    
    private var webSocket: WebSocket
    private var realtimeService: AXRealtimeService
    
    init(url: NSURL, service: AXRealtimeService) {
        realtimeService = service
        webSocket = WebSocket(url: url)
        webSocket.delegate = self
        webSocket.connect()
    }
    
    func send(message:AnyObject) {
        if let str = message as? String {
            webSocket.writeString(str)
        } else if let dict = message as? [String:AnyObject] {
            let str = serializeDictionary(dict)
            webSocket.writeString(str)
        }
    }
    
    func websocketDidConnect(socket: WebSocket) {
        realtimeService.webSocketDidConnect()
    }
    
    func websocketDidDisconnect(socket: WebSocket, error: NSError?) {
        realtimeService.webSocketDidDisconnect(error)
    }
    
    func websocketDidReceiveData(socket: WebSocket, data: NSData) {
        
    }
    
    func websocketDidReceiveMessage(socket: WebSocket, text: String) {
        if let dict = deserializeDictionary(text) {
            realtimeService.webSocketDidReceiveMessage(dict)
        }
    }
    
    private func deserializeDictionary(text: String) -> [String:AnyObject]? {
        let data = text.dataUsingEncoding(NSUTF8StringEncoding) ?? NSData()
        if let dict = try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(rawValue: 0)) as? [String:AnyObject] {
            return dict
        }
        return nil
    }
    
    private func serializeDictionary(dictionary: [String:AnyObject]?) -> String {
        var result = "{}"
        if let data = try? NSJSONSerialization.dataWithJSONObject(dictionary!, options: NSJSONWritingOptions(rawValue: 0)) {
            if let str = NSString(data: data, encoding: NSUTF8StringEncoding) as? String {
                result = str
            }
        }
        return result
    }
    
}
