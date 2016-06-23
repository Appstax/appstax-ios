
import Foundation

public class AXObjectService {
    
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
        if collectionName == "users" {
            return AXUser(properties: properties)
        } else {
            return AXObject(collectionName:collectionName, properties: properties, status: status)
        }
    }
    
    public func createObjects(collectionName: String, properties: [[String:AnyObject]], status: AXObjectStatus) -> [AXObject] {
        return properties.map({
            return self.create(collectionName, properties: $0, status: status)
        })
    }
    
    public func saveObject(object: AXObject, completion: ((AXObject, NSError?) -> ())?) {
        if object.hasUnsavedRelations {
            let error = "Error saving object. Found unsaved related objects. Save related objects first or consider using saveAll instead."
            completion?(object, NSError(domain: "AXObjectError", code: 0, userInfo: [NSLocalizedDescriptionKey:error]))
        } else {
            object.status = .Saving
            
            let savedProperties = object.allPropertiesForSaving
            let afterSave: ((AXObject, NSError?) -> ()) = {
                object, error in
                if error != nil {
                    completion?(object, error)
                } else {
                    object.afterSave(savedProperties, completion: { completion?(object, $0) })
                }
            }
            
            if object.objectID == nil {
                if object.hasUnsavedFiles {
                    saveNewObjectWithFiles(object, completion: afterSave)
                } else {
                    saveNewObjectWithoutFiles(object, completion: afterSave)
                }
            } else {
                updateObject(object, completion: afterSave)
            }
        }
    }
    
    private func updateObject(object: AXObject, completion: ((AXObject, NSError?) -> ())?) {
        let url = urlForObject(object)
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
        let url = urlForCollection(object.collectionName)
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
            let data = fileService.dataForFile(file)
            multipart[key] = [
                "data": data,
                "mimeType": file.mimeType,
                "filename": file.filename
            ]
            AXLog.trace("Adding file to body: mimeType=\(file.mimeType), filename=\(file.filename), data=\(data.length) bytes")
        }
        
        let objectData = apiClient.serializeDictionary(object.allPropertiesForSaving)
        multipart["sysObjectData"] = ["data": objectData]
        AXLog.trace("Object data in multipart body: \(NSString(data: objectData, encoding: NSUTF8StringEncoding))")
        
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
        if objects.count == 0 {
            completion?(nil)
        }
        
        var completionCount = 0
        var firstError: NSError?
        for object in objects {
            saveObject(object) {
                object, error in
                completionCount += 1
                if firstError == nil && error != nil {
                    firstError = error
                }
                if completionCount == objects.count {
                    completion?(firstError)
                }
            }
        }
    }
    
    public func remove(object: AXObject, completion: ((NSError?) -> ())?) {
        let url = urlForObject(object)
        apiClient.deleteUrl(url, completion: completion)
    }
    
    public func findAll(collectionName: String, options: [String:AnyObject]?, completion: (([AXObject]?, NSError?) -> ())?) {
        let url = urlForCollection(collectionName, queryParameters: queryParametersFromQueryOptions(options))
        apiClient.dictionaryFromUrl(url) {
            dictionary, error in
            var objects: [AXObject] = []
            if let properties = dictionary?["objects"] as? [[String:AnyObject]] {
                objects = self.createObjects(collectionName, properties: properties, status: .Saved)
            }
            completion?(objects, error)
        }
    }
    
    public func find(collectionName: String, withId id: String, options: [String:AnyObject]?, completion: ((AXObject?, NSError?) -> ())?) {
        let url = urlForObject(collectionName, withId: id, queryParameters: queryParametersFromQueryOptions(options))
        apiClient.dictionaryFromUrl(url) {
            dictionary, error in
            if let properties = dictionary {
                completion?(self.create(collectionName, properties: properties, status: .Saved), error)
            } else {
                completion?(nil, error)
            }
        }
    }
    
    public func find(collectionName: String, with propertyValues:[String:AnyObject], options: [String:AnyObject]?, completion: (([AXObject]?, NSError?) -> ())?) {
        let query = AXQuery()
        var keys = Array(propertyValues.keys)
        keys.sortInPlace({ $0 < $1 })
        for key in keys {
            if let stringValue = propertyValues[key] as? String {
                query.string(key, equals: stringValue)
            }
            if let objectValue = propertyValues[key] as? AXObject {
                query.relation(key, hasObject: objectValue)
            }
        }
        find(collectionName, queryString:query.queryString, options: options, completion: completion)
    }
    
    public func find(collectionName: String, search propertyValues: [String:String], options: [String:AnyObject]?, completion: (([AXObject]?, NSError?) -> ())?) {
        let query = AXQuery()
        query.logicalOperator = "or"
        for (key, _) in propertyValues {
            query.string(key, contains: propertyValues[key])
        }
        find(collectionName, queryString:query.queryString, options: options, completion: completion)
    }
    
    public func find(collectionName: String, search searchString: String, properties:[String], options: [String:AnyObject]?, completion: (([AXObject]?, NSError?) -> ())?) {
        var propertyValues: [String:String] = [:]
        for property in properties {
            propertyValues[property] = searchString
        }
        find(collectionName, search:propertyValues, options: options, completion:completion)
    }
    
    public func find(collectionName: String, query queryBlock:((AXQuery) -> ()), options: [String:AnyObject]?, completion: (([AXObject]?, NSError?) -> ())?) {
        let query = AXQuery()
        queryBlock(query)
        find(collectionName, queryString: query.queryString, options: options, completion: completion)
    }
    
    public func find(collectionName: String, queryString: String, options: [String:AnyObject]?, completion: (([AXObject]?, NSError?) -> ())?) {
        let query = AXQuery(queryString: queryString)
        var queryParameters = queryParametersFromQueryOptions(options)
        queryParameters["filter"] = query.queryString
        let url = apiClient.urlFromTemplate("/objects/:collection", parameters: ["collection": collectionName], queryParameters: queryParameters)!
        apiClient.dictionaryFromUrl(url) {
            dictionary, error in
            var objects: [AXObject] = []
            if let properties = dictionary?["objects"] as? [[String:AnyObject]] {
                objects = self.createObjects(collectionName, properties: properties, status: .Saved)
            }
            completion?(objects, error)
        }
    }
    
    public func urlForObject(object: AXObject, queryParameters: [String:String] = [:]) -> NSURL {
        return urlForObject(object.collectionName, withId: object.objectID!, queryParameters: queryParameters)
    }
    
    public func urlForObject(collectionName: String, withId id: String, queryParameters: [String:String] = [:]) -> NSURL {
        let parameters = ["collection": collectionName, "id": id]
        return apiClient.urlFromTemplate("objects/:collection/:id", parameters: parameters, queryParameters: queryParameters)!
    }
    
    public func urlForCollection(collectionName: String, queryParameters: [String:String] = [:]) -> NSURL {
        return apiClient.urlFromTemplate("objects/:collection", parameters: ["collection":collectionName], queryParameters: queryParameters)!
    }
    
    private func queryParametersFromQueryOptions(options: [String:AnyObject]?) -> [String:String] {
        var parameters: [String:String] = [:]
        
        if let expand = options?["expand"] as? Int {
            parameters["expanddepth"] = "\(expand)"
        }
        if let order = options?["order"] as? String {
            var startPos: Int = 0
            var sortorder:String = "asc"
            if order.hasPrefix("-") {
                sortorder = "desc"
                startPos = 1
                
            }
            parameters["sortorder"] = sortorder
            parameters["sortcolumn"] = order.substringFromIndex(order.startIndex.advancedBy(startPos))
            
        }
        
        if let page = options?["page"] as? Int {
            parameters["paging"] = "yes"
            parameters["pagenum"] = "\(page)"
        }
        if let pageSize = options?["pageSize"] as? Int {
            parameters["paging"] = "yes"
            parameters["pagelimit"] = "\(pageSize)"
        }
        return parameters
    }
}