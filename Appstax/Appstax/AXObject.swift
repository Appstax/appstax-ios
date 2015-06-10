
import Foundation

@objc public enum AXObjectStatus: NSInteger {
    case New
    case Saving
    case Saved
    case Modified
}

@objc public class AXObject: NSObject {
    
    internal(set) public var status: AXObjectStatus
    internal(set) public var collectionName: String
    
    private var objectService: AXObjectService
    private var permissionsService: AXPermissionsService
    private var fileService: AXFileService
    private var properties: [String:AnyObject]
    private var grants: [[String:AnyObject]]
    private var revokes: [[String:AnyObject]]
    
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
        super.init()
        self.setupInitialFileProperties()
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
            var result: [String:AnyObject] = [:]
            for (key, value) in properties {
                if let file = value as? AXFile {
                    result[key] = [
                        "sysDatatype": "file",
                        "filename": file.filename
                    ]
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
        self.save(nil)
    }
    
    public func save(completion: ((NSError?) -> ())?) {
        objectService.save(self) {
            object, error in
            if error != nil {
                completion?(error)
            } else {
                self.savePermissionChanges(completion)
            }
        }
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
        Appstax.defaultContext.objectService.findAll(collectionName, completion: completion)
    }
    
    public static func find(collectionName: String, withId: String, completion: ((AXObject?, NSError?) -> ())?) {
        Appstax.defaultContext.objectService.find(collectionName, withId: withId, completion: completion)
    }
    
    public static func find(collectionName: String, with: [String:AnyObject], completion: (([AXObject]?, NSError?) -> ())?) {
        Appstax.defaultContext.objectService.find(collectionName, with: with, completion: completion)
    }
    
    public static func find(collectionName: String, search: [String:String], completion: (([AXObject]?, NSError?) -> ())?) {
        Appstax.defaultContext.objectService.find(collectionName, search: search, completion: completion)
    }
    
    public static func find(collectionName: String, search: String, properties:[String], completion: (([AXObject]?, NSError?) -> ())?) {
        Appstax.defaultContext.objectService.find(collectionName, search: search, properties: properties, completion: completion)
    }
    
    public static func find(collectionName: String, query:((AXQuery) -> ()), completion: (([AXObject]?, NSError?) -> ())?) {
        Appstax.defaultContext.objectService.find(collectionName, query: query, completion: completion)
    }
    
    public static func find(collectionName: String, queryString: String, completion: (([AXObject]?, NSError?) -> ())?) {
        Appstax.defaultContext.objectService.find(collectionName, queryString: queryString, completion: completion)
    }
    
    
    
}