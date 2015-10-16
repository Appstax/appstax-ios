
import Foundation

@objc public class AXChannel: NSObject {

    private(set) var name: String
    private(set) var filter: String?
    private var realtimeService: AXRealtimeService!
    private var eventHub = AXEventHub()
    private var createSendt = false
    private var type: String {
        get {
            if let slash = name.rangeOfString("/")?.startIndex {
                let length = name.startIndex.distanceTo(slash)
                return name.substringToIndex(name.startIndex.advancedBy(length))
            }
            return ""
        }
    }
    
    public static func channel(name: String) -> AXChannel {
        return AXChannel(name)
    }
    
    public static func channel(name: String, filter: String) -> AXChannel {
        return AXChannel(name, filter: filter)
    }
    
    public init(_ name: String, filter: String? = nil) {
        self.name = name
        self.filter = filter
        super.init()
        realtimeService = Appstax.defaultContext.realtimeService
        setupEvents()
        sendInitialCommands()
    }
    
    private func setupEvents() {
        realtimeService.on("*", handler: self.eventHub.dispatch)
    }
    
    private func sendInitialCommands() {
        realtimeService.send(command: "subscribe", channel: self.name, filter: filter)
    }
    
    public func on(event: String, handler: (AXChannelEvent) -> ()) {
        eventHub.on(event) {
            if let channelEvent = $0 as? AXChannelEvent {
                if self.shouldReceiveEvent(channelEvent) {
                    handler(channelEvent)
                }
            } else {
                handler(AXChannelEvent(["event": $0.type]))
            }
        }
    }
    
    public func send(message: AnyObject) {
        realtimeService.send(command: "publish", channel: self.name, message: message)
    }
    
    public func grant(who: String, permissions:[String]) {
        sendCreate()
        for permission in permissions {
            realtimeService.send(command: "grant.\(permission)", channel: name, data: [who])
        }
        
    }
    
    public func revoke(who: String, permissions:[String]) {
        sendCreate()
        for permission in permissions {
            realtimeService.send(command: "revoke.\(permission)", channel: name, data: [who])
        }
    }
    
    private func sendCreate() {
        if !createSendt {
            realtimeService.send(command: "channel.create", channel: name)
            createSendt = true
        }
    }
    
    private func shouldReceiveEvent(event: AXChannelEvent) -> Bool {
        if name.hasSuffix("*") {
            let length = name.characters.count - 1
            let match = name.substringToIndex(name.startIndex.advancedBy(length))
            return event.channel.hasPrefix(match)
        } else {
            return event.channel == self.name
        }
    }

}

@objc public class AXChannelEvent: AXEvent {
    
    public private(set) var channel: String
    public private(set) var message: AnyObject?
    public private(set) var error: String?
    public private(set) var object: AXObject?
    
    init(_ dict: [String:AnyObject]) {
        channel = dict["channel"] as? String ?? ""
        message = dict["message"]
        error   = dict["error"] as? String
        super.init(type: dict["event"] as? String ?? "")
        setupObject(dict["data"] as? [String:AnyObject])
    }
    
    private func setupObject(properties: [String:AnyObject]?) {
        if let properties = properties {
            if let collection = collectionNameFromChannelName(channel) {
                if properties["sysObjectId"] != nil {
                    object = AXObject.create(collection, properties: properties)
                }
            }
        }
    }
    
    private func collectionNameFromChannelName(channel: String) -> String? {
        if let slash = channel.rangeOfString("/")?.startIndex {
            return channel.substringFromIndex(slash.advancedBy(1))
        }
        return nil
    }
    
}
