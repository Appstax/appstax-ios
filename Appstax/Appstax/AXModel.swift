
import Foundation

@objc public class AXModel: NSObject {

    private let realtimeService: AXRealtimeService
    private var eventHub = AXEventHub()
    private var observers:[String:AXModelObserver] = [:]
    private var allObjects:[String:AXObject] = [:]
    private var connectedStatusCount = 0
    internal var channelFactory:((String, String) -> (AXChannel))?
    
    public override init() {
        realtimeService = Appstax.defaultContext.realtimeService
        super.init()
        setupReloadAfterReconnect()
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
        watch(name, collection: nil, expand: nil, order: nil, filter: nil)
    }
    
    public func watch(name: String, expand: Int) {
        watch(name, collection: nil, expand: expand, order: nil, filter: nil)
    }
    
    public func watch(name: String, filter: String) {
        watch(name, collection: nil, expand: nil, order: nil, filter: filter)
    }
    
    public func watch(name: String, order: String) {
        watch(name, collection: nil, expand: nil, order: order, filter: nil)
    }
    
    public func watch(name: String, collection: String?, expand: Int?, order: String?, filter: String?) {
        var observer: AXModelObserver?
        switch name {
            case "status":
                observer = AXModelStatusObserver(model: self, realtimeService: realtimeService)
            case "currentUser":
                observer = AXModelCurrentUserObserver(model: self, userService: Appstax.defaultContext.userService)
            default:
                observer = AXModelArrayObserver(model: self, name: name, collection: collection, expand: expand, order: order, filter: filter)
        }
        if let observer = observer {
            observers[name] = observer
            observer.load()
            observer.connect()
        }
    }
    
    public func on(type: String, handler: (AXModelEvent) -> ()) {
        eventHub.on(type) {
            if let event = $0 as? AXModelEvent {
                handler(event)
            }
        }
    }
    
    public func reload() {
        observers.forEach() {
            $1.load()
        }
    }

    private func setupReloadAfterReconnect() {
        realtimeService.on("status") {
            event in
            if self.realtimeService.status == .Connected {
                self.connectedStatusCount += 1
                if self.connectedStatusCount > 1 {
                    self.reload()
                }
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
        notify(AXModelEvent(type: event))
    }
    
    private func notify(event: AXModelEvent) {
        eventHub.dispatch(event)
    }
    
    private func update(object: AXObject, depth: Int = 0) {
        normalize(object, depth: depth)
        observers.forEach() {
            $1.sort()
        }
        notify("change")
    }
    
    private func normalize(object: AXObject, depth: Int = 0) -> AXObject {
        var normalized = object
        if let id = object.objectID {
            if allObjects[id] == nil {
                normalized = object
                allObjects[id] = normalized
            } else {
                normalized = allObjects[id]!
                normalized.importValues(object)
            }
        }
        if depth >= 0 {
            object.allProperties.keys.forEach() { key in
                if let property = object.object(key) {
                    normalized[key] = self.normalize(property, depth: depth - 1)
                } else if let property = object.objects(key) {
                    normalized[key] = property.map() {
                        self.normalize($0, depth: depth - 1)
                    }
                }
            }
        }
        return normalized
    }
    
}

public class AXModelEvent: AXEvent {
    
    private(set) var error: String?
    
    init(type: String, error: String? = nil) {
        super.init(type: type)
        self.error = error
    }
}

private protocol AXModelObserver {
    func load()
    func connect()
    func sort()
    func get() -> AnyObject?
}

private class AXModelCurrentUserObserver: AXModelObserver {
    
    private var model: AXModel
    private var userService: AXUserService
    private var user: AXUser?
    
    init(model: AXModel, userService: AXUserService) {
        self.model = model
        self.userService = userService
        self.setupUserServiceEvents()
    }
    
    private func setupUserServiceEvents() {
        userService.on("login")  { _ in self.importCurrentUser() }
        userService.on("logout") { _ in self.importCurrentUser() }
        userService.on("signup") { _ in self.importCurrentUser() }
    }
    
    func importCurrentUser() {
        set(userService.currentUser)
    }
    
    func load() {
        if let currentUser = userService.currentUser {
            currentUser.refresh() { _ in
                self.user = self.model.normalize(currentUser) as? AXUser
                self.model.notify("change")
            }
        }
    }
    
    func connect() {
        let channel = model.createChannel("objects/users", filter: "")
        channel.on("object.updated") {
            self.set($0.object as? AXUser)
        }
    }
    
    private func set(user: AXUser?) {
        if let user = user {
            self.user = model.normalize(user) as? AXUser
        } else {
            self.user = nil
        }
        self.model.notify("change")
    }
    
    func sort() {}
    func get() -> AnyObject? {
        return user
    }
    
}

private class AXModelStatusObserver: AXModelObserver {
    
    private var realtimeService: AXRealtimeService
    
    init(model: AXModel, realtimeService: AXRealtimeService) {
        self.realtimeService = realtimeService
        self.realtimeService.on("status") { _ in
            model.notify("change")
        }
    }
    
    func load() {}
    func connect() {
        realtimeService.connect()
    }
    func sort() {}
    func get() -> AnyObject? {
        return realtimeService.statusString
    }
    
}

private class AXModelArrayObserver: AXModelObserver {
    
    private var model: AXModel
    private let name: String
    private let collection: String
    private let order: String
    private let filter: String
    private let expand: Int
    private var objects: [AXObject] = []
    private var connectedRelations: [String:Bool] = [:]
    private var expandedObjects: [String:Int] = [:]
    
    init(model:AXModel, name: String, collection: String? = nil, expand: Int? = nil, order: String? = nil, filter: String? = nil) {
        self.model = model
        self.name = name
        self.collection = collection ?? name
        self.order = order ?? "-created"
        self.filter = filter ?? ""
        self.expand = expand ?? 0
    }
    
    private func set(objects: [AXObject]) {
        self.objects = objects.map {
            let x = model.normalize($0, depth: self.expand)
            self.registerRelations(x, depth: self.expand)
            return x
        }
        sort()
        model.notify("change")
    }
    
    private func add(object: AXObject) {
        objects.append(model.normalize(object))
        sort()
        model.notify("change")
    }
    
    private func update(object: AXObject) {
        let depth = expandedObjects[object.objectID ?? ""] ?? 0
        
        func _update() {
            model.update(object, depth: depth)
            registerRelations(object, depth: depth)
        }
        
        if depth > 0 {
            object.expand(depth) { _ in _update() }
        } else {
            _update()
        }
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
    
    func get() -> AnyObject? {
        return objects
    }
    
    func load() {
        var options: [String:AnyObject] = [:]
        if expand > 0 {
            options["expand"] = expand
        }
        if filter != "" {
            AXObject.find(collection, queryString: filter, options: options, completion: handleLoadCompleted)
        } else {
            AXObject.findAll(collection, options: options, completion: handleLoadCompleted)
        }
    }
    
    func handleLoadCompleted(objects:[AXObject]?, error:NSError?) {
        if let error = error {
            self.model.notify(AXModelEvent(type: "error", error: error.userInfo["errorMessage"] as? String))
        } else if let objects = objects {
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
                self.update(object)
            }
        }
        channel.on("object.deleted") {
            if let object = $0.object {
                self.remove(object)
            }
        }
        channel.on("error") {
            self.model.notify(AXModelEvent(type: "error", error: $0.error))
        }
    }
    
    func connectRelation(collection: String) {
        if !(connectedRelations[collection] ?? false) {
            connectedRelations[collection] = true
            let channel = model.createChannel("objects/\(collection)", filter: "")
            channel.on("object.updated") {
                if let object = $0.object {
                    self.update(object)
                }
            }
        }
    }
    
    func registerRelations(object: AXObject, depth: Int) {
        if let id = object.objectID {
            expandedObjects[id] = depth
        }
        if depth > 0 {
            object.relatedObjects.forEach() {
                self.connectRelation($0.collectionName)
                registerRelations($0, depth: depth-1)
            }
        }
    }
    
}
