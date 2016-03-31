
import Foundation

@objc public class AXUserService: NSObject {
    
    private var apiClient: AXApiClient
    private var loginManager: AXLoginUIManager!
    private var eventHub = AXEventHub()
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
    
    public func signup(username username: String, password: String, login: Bool, properties: [String:AnyObject], completion: ((AXUser?, NSError?) -> ())?) {
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
                let username = properties["sysUsername"] as? String ?? username
                let user = AXUser(username: username, properties: properties)
                if login {
                    self.currentUser = user
                    self.keychain.setObject(username, forKeyedSubscript: "Username")
                    self.keychain.setObject(objectID, forKeyedSubscript: "UserObjectID")
                    self.keychain.setObject(sessionID, forKeyedSubscript: "SessionID")
                }
                completion?(user, nil)
                self.eventHub.dispatch(AXEvent(type: "signup"))
            }
        }
    }
    
    public func login(username username: String, password: String, completion: ((AXUser?, NSError?) -> ())?) {
        let url = apiClient.urlByConcatenatingStrings(["sessions"])
        apiClient.postDictionary(["sysUsername":username, "sysPassword":password], toUrl: url!) {
            dictionary, error in
            if let error = error {
                completion?(nil, error)
            } else {
                self.handleLoginSuccess(dictionary, username: username, completion: completion)
            }
        }
    }
    
    public func login(provider provider: String, fromViewController: UIViewController?, completion: ((AXUser?, NSError?) -> ())?) {
        let authViewController = AXAuthViewController()
        
        fromViewController?.presentViewController(authViewController, animated: true, completion: nil)
        
        getProviderConfig(provider) {
            config, error in
            if let error = error {
                completion?(nil, error)
            } else if let clientId = config?["clientId"] as? String {
                var uri = ""
                switch provider {
                    case "facebook": uri = "https://www.facebook.com/dialog/oauth?client_id={clientId}&redirect_uri={redirectUri}&scope=public_profile,email"
                    case "google": uri = "https://accounts.google.com/o/oauth2/v2/auth?client_id={clientId}&redirect_uri={redirectUri}&nonce={nonce}&response_type=code&scope=profile+email"
                    default: break;
                }
                let redirectUri = "https://appstax.com/api/latest/sessions/auth"
                authViewController.runOAuth(uri: uri, redirectUri: redirectUri, clientId: clientId) {
                    result, error in
                    authViewController.dismissViewControllerAnimated(true, completion: nil)
                    
                    if let error = error {
                        completion?(nil, error)
                    } else if let result = result {
                        self.login(provider: provider, authResult: result, completion: completion)
                    }
                }
            }
        }
    }
    
    func getProviderConfig(provider: String, completion:(([String:AnyObject]?, NSError?) -> ())) {
        let url = apiClient.urlFromTemplate("sessions/providers/:provider", parameters: ["provider": provider])!
        apiClient.dictionaryFromUrl(url, completion: completion)
    }
    
    func login(provider provider:String, authResult: AXAuthResult, completion: ((AXUser?, NSError?) -> ())?) {
        let url = apiClient.urlByConcatenatingStrings(["sessions"])
        let data = [
            "sysProvider": [
                "type": provider,
                "data": [
                    "code": authResult.authCode ?? "",
                    "redirectUri": authResult.redirectUri
                ]
            ]
        ]
        apiClient.postDictionary(data, toUrl: url!) {
            dictionary, error in
            
            if let error = error {
                completion?(nil, error)
            } else {
                self.handleLoginSuccess(dictionary, completion: completion)
            }
        }
    }
    
    private func handleLoginSuccess(result: [String:AnyObject]?, username: String? = nil, completion: ((AXUser?, NSError?) -> ())?) {
        let properties = result?["user"] as? [String:AnyObject]? ?? [:]
        let sessionID = result?["sysSessionId"] as? String
        self.setSessionID(sessionID)
        let objectID = properties?["sysObjectId"] as? String
        let username = properties?["sysUsername"] as? String ?? username ?? ""
        self.currentUser = AXUser(username: username, properties: properties)
        self.keychain.setObject(username, forKeyedSubscript: "Username")
        self.keychain.setObject(objectID, forKeyedSubscript: "UserObjectID")
        self.keychain.setObject(sessionID, forKeyedSubscript: "SessionID")
        completion?(self.currentUser, nil)
        self.eventHub.dispatch(AXEvent(type: "login"))
    }
    
    func requireLogin(completion: ((AXUser) -> ())?, withCustomViews views: ((AXLoginViews) -> ())?) {
        requireLogin({ views?($0.views) }, completion: completion)
    }
    
    func requireLogin(config: ((AXLoginConfig) -> ()), completion: ((AXUser) -> ())?) {
        if let user = currentUser {
            user.refresh() { _ in
                completion?(user)
            }
        } else {
            loginManager.presentModalLoginWithConfig(config) { _ in
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
        eventHub.dispatch(AXEvent(type: "logout"))
    }
    
    func requestPasswordReset(email: String, completion: ((NSError?) -> ())?) {
        let url = apiClient.urlFromTemplate("/users/reset/email", parameters: [:])!
        apiClient.postDictionary(["email":email], toUrl: url) {
            completion?($1)
        }
    }
    
    func changePassword(password: String, username: String, code: String, login: Bool, completion:((AXUser?, NSError?) -> ())?) {
        let url = apiClient.urlFromTemplate("/users/reset/password", parameters: [:])!
        let data: [String:AnyObject] = [
            "password": password,
            "username": username,
            "pinCode": code,
            "login": login ? kCFBooleanTrue : kCFBooleanFalse
        ]
        apiClient.postDictionary(data, toUrl: url) {
            dictionary, error in
            if error != nil {
                completion?(nil, error)
            } else if login {
                self.handleLoginSuccess(dictionary, completion: completion)
            } else {
                completion?(nil, nil)
            }
        }
    }
    
    func on(type: String, handler: (AXEvent) -> ()) {
        eventHub.on(type, handler: handler)
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
