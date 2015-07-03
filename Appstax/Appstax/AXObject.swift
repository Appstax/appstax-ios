
import Foundation

@objc public enum AXObjectStatus: NSInteger {
    case New
    case Saving
    case Saved
    case Modified
}

internal struct Relation {
    var type: String
    var ids: [String]
}

@objc public class AXObject: NSObject {
    
    internal(set) public var status: AXObjectStatus
    internal(set) public var collectionName: String
    
    private(set) internal var internalID: String
    
    private var objectService: AXObjectService
    private var permissionsService: AXPermissionsService
    private var fileService: AXFileService
    private var properties: [String:AnyObject]
    private var grants: [[String:AnyObject]]
    private var revokes: [[String:AnyObject]]
    private var relations: [String:Relation]
    
    internal convenience init(collectionName: String) {
        self.init(collectionName: collectionName, properties: [:], status:.New)
    }
    
    internal init(collectionName: String, properties: [String:AnyObject], status: AXObjectStatus) {
        self.objectService = Appstax.defaultContext.objectService
        self.permissionsService = Appstax.defaultContext.permissionsService
        self.fileService = Appstax.defaultContext.fileService
        self.status = status
        self.collectionName = collectionName
        self.properties = properties
        self.grants = []
        self.revokes = []
        self.relations = [:]
        self.internalID = NSUUID().UUIDString
        super.init()
        self.setupInitialFileProperties()
        self.setupInitialRelationsProperties()
        if objectID != nil {
            self.status = .Saved
        }
    }
    
    internal func setupInitialFileProperties() {
        var files: [String:AXFile] = [:]
        for (key, value) in properties {
            if let details = value as? [String:AnyObject] {
                if details["sysDatatype"] as! String == "file" {
                    var filename = details["filename"] as! String
                    var url = fileService.urlForFileName(filename, objectID: objectID, propertyName: key, collectionName: collectionName)
                    files[key] = AXFile(url: url, name: filename, status: AXFileStatusSaved)
                }
            }
        }
        for (key, file) in files {
            properties[key] = file
        }
    }
    
    internal func setupInitialRelationsProperties() {
        for (key, value) in properties {
            if let details = value as? [String:AnyObject] {
                if details["sysDatatype"] as! String == "relation" {
                    setupRelationBacking(key, details)
                    setupRelationProperty(key, details)
                }
            }
        }
    }
    
    internal func setupRelationBacking(key: String, _ details: [String:AnyObject]) {
        var type = details["sysRelationType"] as! String
        relations[key] = Relation(
            type: type,
            ids: (details["sysObjects"] as? [AnyObject] ?? []).map({
                (($0 is String) ? $0 : $0["sysObjectId"]) as? String ?? ""
            }) as [String]
        )
    }
    
    internal func setupRelationProperty(key: String, _ details: [String:AnyObject]) {
        var type = details["sysRelationType"] as! String
        var values: [AnyObject] = (details["sysObjects"] as? [AnyObject] ?? []).map({
            if let id = $0 as? String {
                return id
            } else {
                let collectionName = details["sysCollection"] as! String
                let properties = $0 as! [String:AnyObject]
                return AXObject.create(collectionName, properties: properties)
            }
        })
        if values.count > 0 {
            properties[key] = (type == "single") ? values[0] : NSMutableArray(array: values)
        } else {
            properties[key] = (type == "single") ? nil : NSMutableArray()
        }
    }
    
    public func string(path: String) -> String? {
        return value(path) as? String
    }
    
    public func number(path: String) -> NSNumber? {
        return value(path) as? NSNumber
    }
    
    public func file(path: String) -> AXFile? {
        return value(path) as? AXFile
    }
    
    public func array(path: String) -> [AnyObject]? {
        return value(path) as? [AnyObject]
    }

    public func object(path: String) -> AXObject? {
        return value(path) as? AXObject
    }
    
    public func objects(path: String) -> [AXObject]? {
        return value(path) as? [AXObject]
    }
    
    private func value(path: String) -> AnyObject? {
        var current = self
        for key in (split(path) { $0 == "." }) {
            if let next = current[key] as? AXObject {
                current = next
            } else {
                return current[key]
            }
        }
        return current != self ? current : nil
    }
    
    public internal(set) var objectID: String? {
        set(id) {
            self.properties["sysObjectId"] = id
        }
        get {
            return self.properties["sysObjectId"] as? String
        }
    }
    
    public subscript(key: String) -> AnyObject? {
        get {
            return properties[key]
        }
        set(value) {
            properties[key] = value
            status = .Modified
        }
    }
    
    public var allProperties: [String:AnyObject] {
        get {
            return properties
        }
    }
    
    internal var allPropertiesForSaving: [String:AnyObject] {
        get {
            detectUndeclaredRelations()
            var result: [String:AnyObject] = [:]
            var keys = Set<String>(properties.keys)
            for (key, _) in relations {
                keys.insert(key)
            }
            for key in keys {
                let value: AnyObject? = properties[key]
                if let file = value as? AXFile {
                    result[key] = [
                        "sysDatatype": "file",
                        "filename": file.filename
                    ]
                } else if let relation = relations[key] {
                    let changes = getRelationChanges(key)
                    result[key] = ["sysRelationChanges": changes]
                } else {
                    result[key] = value
                }
            }
            return result
        }
    }
    
    internal var allFileProperties: [String:AXFile] {
        get {
            var result: [String:AXFile] = [:]
            for (key, value) in properties {
                if let file = value as? AXFile {
                    result[key] = file
                }
            }
            return result
        }
    }
    
    internal func detectUndeclaredRelations() {
        for (key, value) in properties {
            if relations[key] != nil {
                continue
            }
            if let object = properties[key] as? AXObject {
                relations[key] = Relation(type: "single", ids: [])
            } else if let objects = properties[key] as? [AXObject] {
                relations[key] = Relation(type: "array", ids: [])
            }
        }
    }
    
    internal func getRelationChanges(key: String) -> [String:[String]] {
        var changes: [String:[String]] = [:]
        if let relation = relations[key] {
            var items: [AnyObject] = []
            if let property: AnyObject = properties[key] {
                items = relation.type == "array" ? property as? [AnyObject] ?? [] : [property]
            }
            var currentIds = items.map({ ($0 as? AXObject)?.objectID ?? $0 as? String ?? "" })
                                  .filter({ $0 != "" })
            changes["additions"] = currentIds.filter({ !contains(relation.ids, $0) })
            changes["removals"] = relation.ids.filter({ !contains(currentIds, $0) })
        }
        return changes
    }
    
    internal func applyRelationChanges(savedProperties: [String:AnyObject]) {
        detectUndeclaredRelations()
        for (key, var relation) in relations {
            if let changes = savedProperties[key]?["sysRelationChanges"] as? [String:[String]] {
                relation.ids += changes["additions"] ?? []
                relation.ids = relation.ids.filter({ !contains(changes["removals"] ?? [], $0) })
                relations[key] = relation
            }
        }
    }
    
    internal var hasUnsavedFiles: Bool {
        get {
            for (key, file) in allFileProperties {
                if file.status.value != AXFileStatusSaved.value {
                    return true
                }
            }
            return false
        }
    }
    
    internal var hasUnsavedRelations: Bool {
        get {
            
            for object in relatedObjects {
                switch object.status {
                    case .New: return true
                    default: continue
                }
            }
            return false
        }
    }
    
    internal var isUnsaved: Bool {
        get {
            return objectID == nil
        }
    }
    
    internal var relatedObjects: [AXObject] {
        get {
            detectUndeclaredRelations()
            var objects: [AXObject] = []
            for (key, relation) in relations {
                if relation.type == "single" {
                    if let object = properties[key] as? AXObject {
                        objects.append(object)
                    }
                } else {
                    objects += properties[key] as? [AXObject] ?? []
                }
            }
            return objects
        }
    }
    
    public func grant(who: AnyObject, permissions:[String]) {
        var usernames = who as? [String] ?? []
        if let username = who as? String {
            usernames.append(username)
        }
        grants += usernames.map({
            return [
                "username": $0,
                "permissions": permissions
            ]
        })
    }
    
    public func revoke(who: AnyObject, permissions:[String]) {
        var usernames = who as? [String] ?? []
        if let username = who as? String {
            usernames.append(username)
        }
        revokes += usernames.map({
            return [
                "username": $0,
                "permissions": permissions
            ]
        })
    }
    
    public func grantPublic(permissions: [String]) {
        grant("*", permissions: permissions)
    }
    
    public func revokePublic(permissions: [String]) {
        revoke("*", permissions: permissions)
    }
    
    public func save() {
        save(nil)
    }
    
    public func save(completion: ((NSError?) -> ())?) {
        objectService.saveObject(self) {
            completion?($1)
        }
    }
    
    internal func afterSave(savedProperties: [String:AnyObject], completion: ((NSError?) -> ())?) {
        self.applyRelationChanges(savedProperties)
        self.savePermissionChanges(completion)
    }
    
    public func saveAll() {
        saveAll(nil)
    }
    
    public func saveAll(completion: ((NSError?) -> ())?) {
        saveObjectsInGraph(completion)
    }
    
    private func saveObjectsInGraph(completion: ((NSError?) -> ())?) {
        let objects = getObjectGraph()
        let unsavedInbound = objects["inbound"]!.filter({ $0.isUnsaved })
        let outbound = objects["outbound"]!
        let remaining = objects["inbound"]!.filter({
            !contains(unsavedInbound, $0) &&
            !contains(outbound, $0)
        })
        
        if 0 == outbound.count + unsavedInbound.count + remaining.count {
            save(completion)
            return
        }
        
        objectService.saveObjects(unsavedInbound) {
            error in
            if error != nil {
                completion?(error)
                return
            }
            self.objectService.saveObjects(outbound) {
                error in
                if error != nil {
                    completion?(error)
                    return
                }
                self.objectService.saveObjects(remaining, completion:completion)
            }
        }
    }
    
    private func getObjectGraph() -> [String:[AXObject]] {
        var queue:    [AXObject]        = [self];
        var all:      [String:AXObject] = [:]
        var inbound:  [String:AXObject] = [:]
        var outbound: [String:AXObject] = [:]
        var allOrdered:      [AXObject] = []
        var inboundOrdered:  [AXObject] = []
        var outboundOrdered: [AXObject] = []
        
        while queue.count > 0 {
            var object = queue.removeAtIndex(0)
            if all[object.internalID] == nil {
                all[object.internalID] = object
                allOrdered.append(object)
                let allRelated = object.getRelatedObjects()
                for related in allRelated {
                    if inbound[related.internalID] == nil {
                        inbound[related.internalID] = related
                        inboundOrdered.append(related)
                    }
                }
                if allRelated.count > 0 {
                    if outbound[object.internalID] == nil {
                        outbound[object.internalID] = object
                        outboundOrdered.append(object)
                    }
                    queue += allRelated
                }
            }
        }
        
        return [
            "all": allOrdered,
            "inbound": inboundOrdered,
            "outbound": outboundOrdered
        ]
    }
    
    internal func getRelatedObjects() -> [AXObject] {
        detectUndeclaredRelations()
        var related: [AXObject] = []
        for (key, relation) in relations {
            if let property = properties[key] as? [AXObject] {
                related += property
            } else if let property = properties[key] as? AXObject {
                related.append(property)
            }
        }
        return related
    }
    
    private func savePermissionChanges(completion: ((NSError?) -> ())?) {
        if grants.count + revokes.count == 0 {
            completion?(nil)
            return
        }
        permissionsService.grant(grants, revoke: revokes, objectID: objectID) {
            error in
            if error == nil {
                self.grants.removeAll()
                self.revokes.removeAll()
            }
            completion?(error)
        }
    }
    
    public func refresh() {
        self.refresh(nil)
    }
    
    public func refresh(completion: ((NSError?) -> ())?) {
        if let id = objectID {
            AXObject.find(collectionName, withId: id) {
                object, error in
                for (key, value) in object?.allProperties ?? [:] {
                    self.properties[key] = value
                }
                completion?(error)
            }
        } else {
            completion?(nil)
        }
    }
    
    public func expand() {
        expand(1, completion: nil)
    }
    
    public func expand(completion: ((NSError?) -> ())?) {
        expand(1, completion: completion)
    }
    
    public func expand(depth: Int, completion: ((NSError?) -> ())?) {
        if let id = objectID {
            AXObject.find(collectionName, withId: id, options: ["expand": depth]) {
                object, error in
                for (key, value) in object?.allProperties ?? [:] {
                    self.properties[key] = value
                }
                completion?(error)
            }
        } else {
            completion?(NSError(domain: "AXObjectError", code: 0, userInfo: [NSLocalizedDescriptionKey:"Error calling expand() on unsaved object"]))
        }
    }
    
    public func remove() {
        self.remove(nil)
    }
    
    public func remove(completion: ((NSError?) -> ())?) {
        Appstax.defaultContext.objectService.remove(self, completion:completion)
    }
    
    public static func create(collectionName: String) -> AXObject {
        return Appstax.defaultContext.objectService.create(collectionName)
    }
    
    public static func create(collectionName: String, properties: [String:AnyObject]) -> AXObject {
        return Appstax.defaultContext.objectService.create(collectionName, properties: properties)
    }
    
    public static func saveObjects(objects: [AXObject], completion: ((NSError?) -> ())?) {
        Appstax.defaultContext.objectService.saveObjects(objects, completion: completion)
    }
    
    public static func findAll(collectionName: String, completion: (([AXObject]?, NSError?) -> ())?) {
        Appstax.defaultContext.objectService.findAll(collectionName, options: nil, completion: completion)
    }
    
    public static func find(collectionName: String, withId: String, completion: ((AXObject?, NSError?) -> ())?) {
        Appstax.defaultContext.objectService.find(collectionName, withId: withId, options: nil, completion: completion)
    }
    
    public static func find(collectionName: String, with: [String:AnyObject], completion: (([AXObject]?, NSError?) -> ())?) {
        Appstax.defaultContext.objectService.find(collectionName, with: with, options: nil, completion: completion)
    }
    
    public static func find(collectionName: String, search: [String:String], completion: (([AXObject]?, NSError?) -> ())?) {
        Appstax.defaultContext.objectService.find(collectionName, search: search, options: nil, completion: completion)
    }
    
    public static func find(collectionName: String, search: String, properties:[String], completion: (([AXObject]?, NSError?) -> ())?) {
        Appstax.defaultContext.objectService.find(collectionName, search: search, properties: properties, options: nil, completion: completion)
    }
    
    public static func find(collectionName: String, query:((AXQuery) -> ()), completion: (([AXObject]?, NSError?) -> ())?) {
        Appstax.defaultContext.objectService.find(collectionName, query: query, options: nil, completion: completion)
    }
    
    public static func find(collectionName: String, queryString: String, completion: (([AXObject]?, NSError?) -> ())?) {
        Appstax.defaultContext.objectService.find(collectionName, queryString: queryString, options: nil, completion: completion)
    }
    
    
    public static func findAll(collectionName: String, options: [String:AnyObject], completion: (([AXObject]?, NSError?) -> ())?) {
        Appstax.defaultContext.objectService.findAll(collectionName, options: options, completion: completion)
    }
    
    public static func find(collectionName: String, withId: String, options: [String:AnyObject], completion: ((AXObject?, NSError?) -> ())?) {
        Appstax.defaultContext.objectService.find(collectionName, withId: withId, options: options, completion: completion)
    }
    
    public static func find(collectionName: String, with: [String:AnyObject], options: [String:AnyObject], completion: (([AXObject]?, NSError?) -> ())?) {
        Appstax.defaultContext.objectService.find(collectionName, with: with, options: options, completion: completion)
    }
    
    public static func find(collectionName: String, search: [String:String], options: [String:AnyObject], completion: (([AXObject]?, NSError?) -> ())?) {
        Appstax.defaultContext.objectService.find(collectionName, search: search, options: options, completion: completion)
    }
    
    public static func find(collectionName: String, search: String, properties:[String], options: [String:AnyObject], completion: (([AXObject]?, NSError?) -> ())?) {
        Appstax.defaultContext.objectService.find(collectionName, search: search, properties: properties, options: options, completion: completion)
    }
    
    public static func find(collectionName: String, query:((AXQuery) -> ()), options: [String:AnyObject], completion: (([AXObject]?, NSError?) -> ())?) {
        Appstax.defaultContext.objectService.find(collectionName, query: query, options: options, completion: completion)
    }
    
    public static func find(collectionName: String, queryString: String, options: [String:AnyObject], completion: (([AXObject]?, NSError?) -> ())?) {
        Appstax.defaultContext.objectService.find(collectionName, queryString: queryString, options: options, completion: completion)
    }
    
    
    
}