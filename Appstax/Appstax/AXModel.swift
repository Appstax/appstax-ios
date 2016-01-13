
import Foundation

@objc public class AXModel: NSObject {

    private var eventHub = AXEventHub()
    private var observers:[String:AXModelObserver] = [:]
    private var allObjects:[String:AXObject] = [:]
    internal var channelFactory:((String, String) -> (AXChannel))?
    
    public override init() {
        
    }
    
    private convenience init(channelFactory: ((String, String) -> (AXChannel))) {
        self.init()
        self.channelFactory = channelFactory
    }
    
    public static func model() -> AXModel {
        return AXModel()
    }
    
    public subscript(key: String) -> AnyObject? {
        get {
            return observers[key]?.get()
        }
    }
    
    public func watch(name: String) {
        watch(name, collection: nil, order: nil, filter: nil)
    }
    
    public func watch(name: String, filter: String) {
        watch(name, collection: nil, order: nil, filter: filter)
    }
    
    public func watch(name: String, order: String) {
        watch(name, collection: nil, order: order, filter: nil)
    }
    
    public func watch(name: String, collection: String?, order: String?, filter: String?) {
        let observer = AXModelArrayObserver(model: self, name: name, collection: collection, order: order, filter: filter)
        observers[name] = observer
        observer.load()
        observer.connect()
    }
    
    public func on(type: String, handler: (AXModelEvent) -> ()) {
        eventHub.on(type) {
            if let event = $0 as? AXModelEvent {
                handler(event)
            }
        }
    }
    
    private func createChannel(name:String, filter:String) -> AXChannel {
        if let factory = channelFactory {
            return factory(name, filter)
        }
        return AXChannel(name, filter: filter)
    }
    
    private func notify(event: String) {
        eventHub.dispatch(AXModelEvent(type: event))
    }
    
    private func update(object: AXObject) {
        if let id = object.objectID {
            if let existing = allObjects[id] {
                existing.importValues(object)
            } else {
                allObjects[id] = object
            }
            observers.forEach() {
                $1.sort()
            }
            notify("change")
        }
    }
    
    private func normalize(object: AXObject) -> AXObject {
        if let id = object.objectID {
            if allObjects[id] == nil {
                allObjects[id] = object
            }
            return allObjects[id]!
        }
        return object
    }
    
}

public class AXModelEvent: AXEvent {
    
}

private protocol AXModelObserver {
    func load()
    func connect()
    func sort()
    func get() -> AnyObject
}

private class AXModelArrayObserver: AXModelObserver {
    
    private var model: AXModel
    private let name: String
    private let collection: String
    private let order: String
    private let filter: String
    private var objects: [AXObject] = []
    
    init(model:AXModel, name: String, collection: String? = nil, order: String? = nil, filter: String? = nil) {
        self.model = model
        self.name = name
        self.collection = collection ?? name
        self.order = order ?? "-created"
        self.filter = filter ?? ""
    }
    
    private func set(objects: [AXObject]) {
        self.objects = objects.map(model.normalize)
        sort()
        model.notify("change")
    }
    
    private func add(object: AXObject) {
        objects.append(model.normalize(object))
        sort()
        model.notify("change")
    }
    
    private func remove(object: AXObject) {
        if let index = objects.indexOf({ $0.objectID == object.objectID }) {
            objects.removeAtIndex(index)
        }
        sort()
        model.notify("change")
    }
    
    private func sort() {
        var property = order
        var direction = 1
        if order.characters.first == Character("-") {
            property = order.substringFromIndex(order.startIndex.advancedBy(1))
            direction = -1
        }
        
        switch property {
            case "created": property = "sysCreated"
            case "updated": property = "sysUpdated"
            default: break
        }
        
        if direction < 0 {
            self.objects.sortInPlace() {
                let v0 = $0.string(property) ?? ""
                let v1 = $1.string(property) ?? ""
                return v0 > v1
            }
        } else if direction > 0 {
            self.objects.sortInPlace() {
                let v0 = $0.string(property) ?? ""
                let v1 = $1.string(property) ?? ""
                return v0 < v1
            }
        }
    }
    
    func get() -> AnyObject {
        return objects
    }
    
    func load() {
        if filter != "" {
            AXObject.find(collection, queryString: filter, completion: handleLoadCompleted)
        } else {
            AXObject.findAll(collection, completion: handleLoadCompleted)
        }
    }
    
    func handleLoadCompleted(objects:[AXObject]?, error:NSError?) {
        if let objects = objects {
            self.set(objects)
        }
    }
    
    func connect() {
        let channel = model.createChannel("objects/\(collection)", filter: filter)
        channel.on("object.created") {
            if let object = $0.object {
                self.add(object)
            }
        }
        channel.on("object.updated") {
            if let object = $0.object {
                self.model.update(object)
            }
        }
        channel.on("object.deleted") {
            if let object = $0.object {
                self.remove(object)
            }
        }
    }
    
}
