
import Foundation

@objc public class AXUser: AXObject {
 
    public convenience init(username: String) {
        self.init(username: username, properties:[:])
    }
    
    public convenience init(username: String, properties: [String:AnyObject]?) {
        var p = properties ?? [:]
        p["sysUsername"] = username
        self.init(properties: p)
    }
    
    public init(properties: [String:AnyObject]) {
        super.init(collectionName: "users", properties: properties, status: .New)
    }
    
    public var username: String {
        get {
            return string("sysUsername") ?? ""
        }
    }
    
    public static func signup(username username: String, password: String, completion: ((AXUser?, NSError?) -> ())?) {
        Appstax.defaultContext.userService.signup(username: username, password: password, login: true, properties: [:], completion: completion)
    }
    
    public static func signup(username username: String, password: String, login: Bool, completion: ((AXUser?, NSError?) -> ())?) {
        Appstax.defaultContext.userService.signup(username: username, password: password, login: login, properties: [:], completion: completion)
    }
    
    public static func signup(username username: String, password: String, properties: [String:AnyObject], completion: ((AXUser?, NSError?) -> ())?) {
        Appstax.defaultContext.userService.signup(username: username, password: password, login: true, properties: properties, completion: completion)
    }
    
    public static func signup(username username: String, password: String, login: Bool, properties: [String:AnyObject], completion: ((AXUser?, NSError?) -> ())?) {
        Appstax.defaultContext.userService.signup(username: username, password: password, login: login, properties: properties, completion: completion)
    }
    
    public static func login(username username: String, password: String, completion: ((AXUser?, NSError?) -> ())?) {
        Appstax.defaultContext.userService.login(username: username, password: password, completion: completion)
    }
    
    public static func login(provider provider: String, fromViewController: UIViewController?, completion: ((AXUser?, NSError?) -> ())?) {
        Appstax.defaultContext.userService.login(provider: provider, fromViewController: fromViewController, completion: completion)
    }
    
    public static func requireLogin(completion: ((AXUser) -> ())?) {
        Appstax.defaultContext.userService.requireLogin({
                completion?($0)
            }, withCustomViews: {
                views in
        })
    }
    
    public static func requireLogin(config: ((AXLoginConfig) -> ()), completion: ((AXUser) -> ())?) {
        Appstax.defaultContext.userService.requireLogin(config, completion: completion)
    }
    
    public static func requireLogin(completion: ((AXUser) -> ())?, withCustomViews views: ((AXLoginViews) -> ())?) {
        Appstax.defaultContext.userService.requireLogin(completion, withCustomViews: views)
    }

    public static func currentUser() -> AXUser? {
        return Appstax.defaultContext.userService.currentUser
    }
    
    public static func logout() {
        Appstax.defaultContext.userService.logout()
    }
    
    public static func requestPasswordReset(email: String, completion: ((NSError?) -> ())?) {
        Appstax.defaultContext.userService.requestPasswordReset(email, completion: completion)
    }
    
    public static func changePassword(password: String, username: String, code: String, login: Bool, completion:((AXUser?, NSError?) -> ())?) {
        Appstax.defaultContext.userService.changePassword(password, username: username, code: code, login: login, completion: completion)
    }
}