
import Foundation

@objc public class Appstax: NSObject {
    
    private(set) public var apiClient: AXApiClient!
    private(set) public var appKey: String = ""
    private(set) public var fileService: AXFileService!
    private(set) public var dataStore: AXDataStore!
    private(set) public var userService: AXUserService!
    private(set) public var permissionsService: AXPermissionsService!
    
    public static func setAppKey(appKey: String) {
        Appstax.defaultContext.setupServicesWithAppKey(appKey)
    }
    
    public static func setAppKey(appKey: String, baseUrl: String) {
        Appstax.defaultContext.setupServicesWithAppKey(appKey, baseUrl: baseUrl)
    }
    
    internal func setupServicesWithAppKey(appKey: String, baseUrl: String = "https://appstax.com/api/latest/") {
        self.appKey = appKey
        self.apiClient = AXApiClient(appKey: appKey, baseUrl: baseUrl)
        setupServicesWithApiClient(apiClient!)
    }
    
    internal func setupServicesWithApiClient(apiClient: AXApiClient) {
        self.apiClient = apiClient
        self.dataStore = AXDataStore(apiClient: apiClient)
        self.userService = AXUserService(apiClient: apiClient)
        self.permissionsService = AXPermissionsService(apiClient: apiClient)
        self.fileService = AXFileService(apiClient: apiClient)
    }
    
    public static func frameworkBundle() -> NSBundle! {
        struct Static {
            static var onceToken: dispatch_once_t = 0
            static var frameworkBundle: NSBundle? = nil
        }
        dispatch_once(&Static.onceToken) {
            Static.frameworkBundle = NSBundle(forClass: Appstax.self)
        }
        return Static.frameworkBundle
    }
    
    public static var defaultContext: Appstax {
        struct Static {
            static var onceToken: dispatch_once_t = 0
            static var instance: Appstax? = nil
        }
        dispatch_once(&Static.onceToken) {
            Static.instance = Appstax()
        }
        return Static.instance!
    }

}
