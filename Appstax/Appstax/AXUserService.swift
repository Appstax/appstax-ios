
import Foundation

@objc public class AXUserService: NSObject {
    
    private var apiClient: AXApiClient
    private var loginManager: AXLoginUIManager!
    private(set) public var keychain: AXKeychain = AXKeychain()

    private var _currentUser: AXUser?
    public var currentUser: AXUser? {
        get {
            if _currentUser == nil {
                restoreUserFromPreviousSession()
            }
            return _currentUser
        }
        set {
            _currentUser = newValue
        }
    }
    
    init(apiClient: AXApiClient) {
        self.apiClient = apiClient
        super.init()
        self.loginManager = AXLoginUIManager(userService: self)
    }
    
    public func signupWithUsername(username: String, password: String, login: Bool, properties: [String:AnyObject], completion: ((AXUser?, NSError?) -> ())?) {
        
        var url = apiClient.urlByConcatenatingStrings(["users"])
        if !login {
            url = apiClient.urlByConcatenatingStrings(["users?login=false"])
        }
        var data: [String:AnyObject] = properties
        data["sysUsername"] = username
        data["sysPassword"] = password
        
        apiClient.postDictionary(data, toUrl: url!) {
            dictionary, error in
            if let error = error {
                completion?(nil, error)
            } else if let properties = dictionary?["user"] as? [String:AnyObject]? ?? [:] {
                let sessionID = dictionary?["sysSessionId"] as? String
                self.setSessionID(sessionID)
                let objectID = properties["sysObjectId"] as? String
                let user = AXUser(username: username, properties: properties)
                if login {
                    self.currentUser = user
                    self.keychain.setObject(username, forKeyedSubscript: "Username")
                    self.keychain.setObject(objectID, forKeyedSubscript: "UserObjectID")
                    self.keychain.setObject(sessionID, forKeyedSubscript: "SessionID")
                }
                completion?(user, nil)
            }
        }
    }
    
    public func loginWithUsername(username: String, password: String, completion: ((AXUser?, NSError?) -> ())?) {
        
        let url = apiClient.urlByConcatenatingStrings(["sessions"])
        apiClient.postDictionary(["sysUsername":username, "sysPassword":password], toUrl: url!) {
            dictionary, error in
            if let error = error {
                completion?(nil, error)
            } else if let properties = dictionary?["user"] as? [String:AnyObject]? ?? [:] {
                let sessionID = dictionary?["sysSessionId"] as? String
                self.setSessionID(sessionID)
                let objectID = properties["sysObjectId"] as? String
                self.currentUser = AXUser(username: username, properties: properties)
                self.keychain.setObject(username, forKeyedSubscript: "Username")
                self.keychain.setObject(objectID, forKeyedSubscript: "UserObjectID")
                self.keychain.setObject(sessionID, forKeyedSubscript: "SessionID")
                completion?(self.currentUser, nil)
            }
        }
    }
    
    func requireLogin(completion: ((AXUser) -> ())?, withCustomViews views: ((AXLoginViews!) -> ())?) {
        if let user = currentUser {
            user.refresh() { _ in
                completion?(user)
            }
        } else if let views = views {
            loginManager.presentModalLoginWithViews(views) { _ in
                completion?(self.currentUser!)
            }
        }
    }
    
    func logout() {
        if let sessionID = apiClient.sessionID {
            let url = apiClient.urlByConcatenatingStrings(["sessions/", sessionID])
            apiClient.deleteUrl(url!)
        }
        keychain.setObject(nil, forKeyedSubscript: "SessionID")
        keychain.setObject(nil, forKeyedSubscript: "Username")
        currentUser = nil
        apiClient.updateSessionID(nil)
    }
    
    private func setSessionID(sessionID: String?) {
        apiClient.updateSessionID(sessionID)
    }
    
    private func restoreUserFromPreviousSession() {
        let sessionID = keychain.objectForKeyedSubscript("SessionID") as? String
        let username  = keychain.objectForKeyedSubscript("Username")  as? String
        let objectID  = keychain.objectForKeyedSubscript("UserObjectID") as? String
        if sessionID != nil && username != nil && objectID != nil {
            apiClient.updateSessionID(sessionID)
            _currentUser = AXUser(username: username!, properties: ["sysObjectId":objectID!])
        }
    }
    
}
