
import Foundation

// TODO: Make internal
@objc public class AXApiClient: NSObject {
    
    public private(set) var sessionID: String?
    var baseUrl: String
    var appKey: String
    var urlSession: NSURLSession
    
    public func updateSessionID(id: String?) {
        sessionID = id
    }
    
    public init(appKey: String, baseUrl: String) {
        self.appKey = appKey
        self.baseUrl = baseUrl
        self.sessionID = nil
        self.urlSession = NSURLSession.sharedSession()
    }
    
    public func postDictionary(dictionary: [String:AnyObject], toUrl: NSURL, completion: (([String:AnyObject]?, NSError?) -> ())?) {
        sendHttpBody(serializeDictionary(dictionary), toUrl: toUrl, method: "POST", headers: [:]) {
            completion?(self.deserializeDictionary($0), $1)
        }
    }
    
    public func putDictionary(dictionary: [String:AnyObject], toUrl: NSURL, completion: (([String:AnyObject]?, NSError?) -> ())?) {
        sendHttpBody(serializeDictionary(dictionary), toUrl: toUrl, method: "PUT", headers: [:]) {
            completion?(self.deserializeDictionary($0), $1)
        }
    }
    
    public func sendMultipartFormData(dataParts: [String:AnyObject], toUrl: NSURL, method: String, completion: (([String:AnyObject]?, NSError?) -> ())?) {
        let boundary = "Boundary-\(NSUUID().UUIDString)"
        let contentType = "multipart/form-data; boundary=\(boundary)"
        let body = NSMutableData()
        
        for (partName, part) in dataParts {
            let filename = part["filename"] as! String? ?? ""
            let mimeType = part["mimeType"] as! String? ?? ""
            let data = part["data"] as! NSData
            body.appendData(stringData("--\(boundary)\r\n"))
            if filename != "" {
                body.appendData(stringData("Content-Disposition: form-data; name=\"\(partName)\"; filename=\"\(filename)\"\r\n"))
            } else {
                body.appendData(stringData("Content-Disposition: form-data; name=\"\(partName)\r\n"))
            }
            if mimeType != "" {
                body.appendData(stringData("Content-Type: \(mimeType)\r\n"))
            }
            body.appendData(stringData("\r\n"))
            body.appendData(data)
            body.appendData(stringData("\r\n"))
        }
        body.appendData(stringData("--\(boundary)--\r\n"))
        
        sendHttpBody(body, toUrl: toUrl, method: method, headers: ["Content-Type":contentType]) {
            completion?(self.deserializeDictionary($0), $1)
        }
    }
    
    public func dictionaryFromUrl(url: NSURL, completion: (([String:AnyObject]?, NSError?) -> ())?) {
        dataFromUrl(url) {
            completion?(self.deserializeDictionary($0), $1)
        }
    }
    
    public func arrayFromUrl(url: NSURL, completion: (([AnyObject]?, NSError?) -> ())?) {
        dataFromUrl(url) {
            completion?(self.deserializeArray($0), $1)
        }
    }
    
    public func dataFromUrl(url: NSURL, completion: ((NSData?, NSError?) -> ())?) {
        let request = makeRequestWithMethod("GET", url: url, headers: [:])
        logRequest(request)
        urlSession.dataTaskWithRequest(request) {
            var data = $0
            let response = $1
            var error = $2
            
            self.logResponse(response, data: data, error: error)
            if error == nil {
                error = self.errorFromResponse(response, data: data)
            }
            if error != nil {
                data = nil
            }
            dispatch_async(dispatch_get_main_queue()) {
                completion?(data, error);
            }
        }.resume()
    }
    
    public func deleteUrl(url: NSURL, completion: ((NSError?) -> ())? = nil) {
        sendHttpBody(NSData(), toUrl: url, method: "DELETE", headers: [:]) {
            completion?($1)
        }
    }
    
    public func urlByConcatenatingStrings(strings: [String]) -> NSURL? {
        let full = baseUrl.stringByAppendingString(strings.joinWithSeparator(""))
        return NSURL(string: full)
    }
    
    public func urlFromTemplate(template: String, parameters: [String:String], queryParameters: [String:String] = [:]) -> NSURL? {
        let url = NSMutableString(string: template)
        if(url.hasPrefix("/")) {
            url.replaceCharactersInRange(NSMakeRange(0, 1), withString: "")
        }
        url.insertString(baseUrl, atIndex: 0)
        for (key, value) in parameters {
            url.replaceOccurrencesOfString(":" + key, withString: urlEncode(value), options: .LiteralSearch, range: NSMakeRange(0, url.length))
        }
        
        var queryString = ""
        if queryParameters.count > 0 {
            queryString = Array(queryParameters.keys).map({
                key in
                if let value = queryParameters[key] {
                    return "\(key)=\(self.urlEncode(value))"
                }
                return ""
            }).joinWithSeparator("&")
            let queryStringPrefix = (url.rangeOfString("?").toRange() == nil) ? "?" : "&"
            queryString = "\(queryStringPrefix)\(queryString)"
        }
        
        return NSURL(string: url.stringByAppendingString(queryString))
    }
    
    public func deserializeDictionary(data: NSData?) -> [String:AnyObject]? {
        if data == nil {
            return nil
        }
        return (try? NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions(rawValue: 0))) as? [String:AnyObject]
    }
    
    public func deserializeArray(data: NSData?) -> [AnyObject]? {
        if data == nil {
            return nil
        }
        return (try? NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions(rawValue: 0))) as? [AnyObject]
    }
    
    public func serializeDictionary(dictionary: [String:AnyObject]?) -> NSData {
        if dictionary == nil {
            return NSData()
        }
        let data = try? NSJSONSerialization.dataWithJSONObject(dictionary!, options: NSJSONWritingOptions(rawValue: 0))
        if data == nil {
            return NSData()
        }
        return data!
    }
    
    public func urlEncode(string: String) -> String {
        let characterSet = NSCharacterSet(charactersInString: " ='\"#%/<>?@^`{|}").invertedSet
        return string.stringByAddingPercentEncodingWithAllowedCharacters(characterSet) ?? string
    }
    
    
    // PRIVATE
    
    private func sendHttpBody(httpBody: NSData, toUrl url: NSURL, method: String, headers: [String:String], completion: (NSData?, NSError?) -> ()) {
        let request = makeRequestWithMethod(method, url: url, headers: headers)
        request.HTTPBody = httpBody
        NSURLProtocol.setProperty(request.HTTPBody!, forKey: "HTTPBody", inRequest: request)
        logRequest(request)
        urlSession.uploadTaskWithRequest(request, fromData: nil) {
            var data = $0
            let response = $1
            var error = $2
            
            self.logResponse(response, data: data, error: error)
            if error == nil {
                error = self.errorFromResponse(response, data: data)
            }
            if error != nil {
                data = nil
            }
            dispatch_async(dispatch_get_main_queue()) {
                completion(data, error);
            }
        }.resume()
    }
    
    private func makeRequestWithMethod(method: String, url: NSURL, headers: [String:String]) -> NSMutableURLRequest {
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = method
        request.setValue(appKey, forHTTPHeaderField: "x-appstax-appkey")
        request.setValue(sessionID, forHTTPHeaderField: "x-appstax-sessionid")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }
    
    func logRequest(request: NSURLRequest) {
        let method = request.HTTPMethod ?? "(no http method)"
        let url = request.URL?.absoluteString ?? "(no url)"
        AXLog.debug("HTTP Request: \(method) : \(url)")
        if let body = NSString(data: request.HTTPBody ?? NSData(), encoding: NSUTF8StringEncoding) {
            AXLog.trace("HTTP Request Body: \(body)")
        } else {
            AXLog.trace("No HTTP Request Body")
        }
    }
    
    func logResponse(response: NSURLResponse?, data: NSData?, var error: NSError?) {
        if let httpResponse = response as? NSHTTPURLResponse {
            if error == nil {
                error = errorFromResponse(httpResponse, data: data)
            }
            if error == nil {
                AXLog.debug("HTTP Response: \(httpResponse.statusCode) \(httpResponse.URL!)")
            } else {
                AXLog.error("HTTP Response: \(httpResponse.statusCode) \(httpResponse.URL!)")
                if let message = error?.localizedDescription {
                    AXLog.error(message)
                }
            }
            if let body = NSString(data: data ?? NSData(), encoding: NSUTF8StringEncoding) {
                AXLog.trace("HTTP Response Body: \(body)")
            } else {
                AXLog.trace("No HTTP Response Body")
            }
        } else if let message = error?.localizedDescription {
            AXLog.error(message)
        }
    }
    
    func errorFromResponse(response: NSURLResponse?, data: NSData?) -> NSError? {
        var error: NSError?
        if let httpResponse = response as? NSHTTPURLResponse {
            if httpResponse.statusCode / 100 != 2 {
                let message: String = deserializeDictionary(data)?["errorMessage"] as? String ?? ""
                error = NSError(domain: "ApiClientHttpError", code: httpResponse.statusCode, userInfo: ["errorMessage": message])
            }
        }
        return error
    }
    
    func stringData(string: String) -> NSData {
        return string.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
    }
    
}