
import Foundation

@objc public class AXObjectService {
    
    private var apiClient: AXApiClient
    
    public init(apiClient: AXApiClient) {
        self.apiClient = apiClient
    }
    
    public func create(collectionName: String) -> AXObject {
        return create(collectionName, properties: [:])
    }
    
    public func create(collectionName: String, properties: [String:AnyObject]) -> AXObject {
        return create(collectionName, properties: properties, status: .New)
    }
    
    public func create(collectionName: String, properties: [String:AnyObject], status:AXObjectStatus) -> AXObject {
        return AXObject(collectionName:collectionName, properties: properties, status: status)
    }
    
    public func createObjects(collectionName: String, properties: [[String:AnyObject]], status: AXObjectStatus) -> [AXObject] {
        return properties.map({
            return self.create(collectionName, properties: $0, status: status)
        })
    }
    
    public func save(object: AXObject, completion: ((AXObject, NSError?) -> ())?) {
        object.status = .Saving
        if object.objectID == nil {
            if object.hasUnsavedFiles {
                saveNewObjectWithFiles(object, completion: completion)
            } else {
                saveNewObjectWithoutFiles(object, completion: completion)
            }
        } else {
            updateObject(object, completion: completion)
        }
    }
    
    private func updateObject(object: AXObject, completion: ((AXObject, NSError?) -> ())?) {
        var url = urlForObject(object)
        apiClient.putDictionary(object.allPropertiesForSaving, toUrl: url) {
            dictionary, error in
            if error == nil {
                let fileService = Appstax.defaultContext.fileService
                fileService.saveFilesForObject(object) {
                    error in
                    object.status = error != nil ? .Modified : .Saved
                    completion?(object, error)
                }
            } else {
                completion?(object, error)
            }
        }
    }
    
    private func saveNewObjectWithoutFiles(object: AXObject, completion: ((AXObject, NSError?) -> ())?) {
        var url = urlForCollection(object.collectionName)
        apiClient.postDictionary(object.allPropertiesForSaving, toUrl: url) {
            dictionary, error in
            object.status = error != nil ? .Modified : .Saved
            if error == nil {
                if let id = dictionary?["sysObjectId"] as! String? {
                    object.objectID = id
                }
            }
            completion?(object, error)
        }
    }
    
    private func saveNewObjectWithFiles(object: AXObject, completion: ((AXObject, NSError?) -> ())?) {
        let url = urlForCollection(object.collectionName)
        let fileService = Appstax.defaultContext.fileService
        var multipart: [String: AnyObject] = [:]
        
        for (key, file) in object.allFileProperties {
            file.status = AXFileStatusSaving
            multipart[key] = [
                "data": fileService.dataForFile(file),
                "mimeType": file.mimeType,
                "filename": file.filename
            ]
        }
        multipart["sysObjectData"] = ["data": apiClient.serializeDictionary(object.allPropertiesForSaving)]
        
        apiClient.sendMultipartFormData(multipart, toUrl: url, method: "POST") {
            dictionary, error in
            object.status = error != nil ? .Modified : .Saved
            if error == nil {
                if let id = dictionary?["sysObjectId"] as! String? {
                    object.objectID = id
                }
                for (key, file) in object.allFileProperties {
                    file.status = AXFileStatusSaved
                    file.url = fileService.urlForFileName(file.filename, objectID: object.objectID, propertyName: key, collectionName: object.collectionName)
                }
            }
            completion?(object, error)
        }
    }
    
    public func saveObjects(objects: [AXObject], completion: ((NSError?) -> ())?) {
        var objectCount = objects.count
        var completionCount = 0
        var firstError: NSError?
        for object in objects {
            save(object) {
                object, error in
                completionCount++
                if firstError == nil && error == nil {
                    firstError = error
                }
                if completionCount == objectCount {
                    completion?(firstError)
                }
            }
        }
    }
    
    public func remove(object: AXObject, completion: ((NSError?) -> ())?) {
        let url = urlForObject(object)
        apiClient.deleteUrl(url, completion: completion)
    }
    
    public func findAll(collectionName: String, completion: (([AXObject]?, NSError?) -> ())?) {
        let url = urlForCollection(collectionName)
        apiClient.dictionaryFromUrl(url) {
            dictionary, error in
            var objects: [AXObject] = []
            if let properties = dictionary?["objects"] as? [[String:AnyObject]] {
                objects = self.createObjects(collectionName, properties: properties, status: .Saved)
            }
            completion?(objects, error)
        }
    }
    
    public func find(collectionName: String, withId: String, completion: ((AXObject?, NSError?) -> ())?) {
        let url = apiClient.urlByConcatenatingStrings(["objects/", collectionName, "/", withId])!
        apiClient.dictionaryFromUrl(url) {
            dictionary, error in
            if let properties = dictionary {
                completion?(self.create(collectionName, properties: properties, status: .Saved), error)
            } else {
                completion?(nil, error)
            }
        }
    }
    
    public func find(collectionName: String, with propertyValues:[String:AnyObject], completion: (([AXObject]?, NSError?) -> ())?) {
        var query = AXQuery()
        var keys = propertyValues.keys.array
        keys.sort({ $0 < $1 })
        for key in keys {
            if let stringValue = propertyValues[key] as? String {
                query.string(key, equals: stringValue)
            }
        }
        find(collectionName, queryString:query.queryString, completion: completion)
    }
    
    public func find(collectionName: String, search propertyValues: [String:String], completion: (([AXObject]?, NSError?) -> ())?) {
        var query = AXQuery()
        query.logicalOperator = "or"
        for (key, value) in propertyValues {
            query.string(key, contains: propertyValues[key])
        }
        find(collectionName, queryString:query.queryString, completion: completion)
    }
    
    public func find(collectionName: String, search searchString: String, properties:[String], completion: (([AXObject]?, NSError?) -> ())?) {
        var propertyValues: [String:String] = [:]
        for property in properties {
            propertyValues[property] = searchString
        }
        find(collectionName, search:propertyValues, completion:completion)
    }
    
    public func find(collectionName: String, query queryBlock:((AXQuery) -> ()), completion: (([AXObject]?, NSError?) -> ())?) {
        let query = AXQuery()
        queryBlock(query)
        find(collectionName, queryString: query.queryString, completion: completion)
    }
    
    public func find(collectionName: String, queryString: String, completion: (([AXObject]?, NSError?) -> ())?) {
        let query = AXQuery(queryString: queryString)
        let url = apiClient.urlFromTemplate("/objects/:collection?filter=:filter", parameters: ["collection": collectionName, "filter": query.queryString])!
        apiClient.dictionaryFromUrl(url) {
            dictionary, error in
            var objects: [AXObject] = []
            if let properties = dictionary?["objects"] as? [[String:AnyObject]] {
                objects = self.createObjects(collectionName, properties: properties, status: .Saved)
            }
            completion?(objects, error)
        }
    }
    
    public func urlForObject(object: AXObject) -> NSURL {
        return apiClient.urlByConcatenatingStrings(["objects/", object.collectionName, "/", object.objectID!])!
    }
    
    public func urlForCollection(collectionName: String) -> NSURL {
        return apiClient.urlByConcatenatingStrings(["objects/", collectionName])!
    }
}