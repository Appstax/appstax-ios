
import Foundation

@objc public class AXUser: AXObject {
 
    public init(username: String, properties: [String:AnyObject]) {
        var p = properties
        p["sysUsername"] = username
        super.init(collectionName: "users", properties: p, status: .New)
    }
    
    public var username: String {
        get {
            return string("sysUsername") ?? ""
        }
    }
    
    public static func signup(#username: String, password: String, completion: ((AXUser?, NSError?) -> ())?) {
        Appstax.defaultContext.userService.signupWithUsername(username, password: password, completion: completion)
    }
    
    public static func login(#username: String, password: String, completion: ((AXUser?, NSError?) -> ())?) {
        Appstax.defaultContext.userService.loginWithUsername(username, password: password, completion: completion)
    }
    
    public static func requireLogin(completion: ((AXUser) -> ())?) {
        Appstax.defaultContext.userService.requireLogin({
                completion?($0)
            }, withCustomViews: {
                views in
        })
    }
    
    public static func requireLogin(completion: ((AXUser) -> ())?, withCustomWiews views: ((AXLoginViews) -> ())?) {
        Appstax.defaultContext.userService.requireLogin({
                completion?($0)
            }, withCustomViews: {
                views?($0)
            })
    }

    public static func currentUser() -> AXUser? {
        return Appstax.defaultContext.userService.currentUser
    }
    
    public static func logout() {
        Appstax.defaultContext.userService.logout()
    }
}