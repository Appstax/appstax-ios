
import Foundation

@objc public class Appstax: NSObject {
    
    private(set) public var apiClient: AXApiClient!
    private(set) public var appKey: String = ""
    private(set) public var fileService: AXFileService!
    private(set) public var objectService: AXObjectService!
    private(set) public var userService: AXUserService!
    private(set) public var permissionsService: AXPermissionsService!
    private(set) var realtimeService: AXRealtimeService!
    
    public static func setAppKey(appKey: String) {
        Appstax.defaultContext.setupServicesWithAppKey(appKey)
    }
    
    public static func setAppKey(appKey: String, baseUrl: String) {
        Appstax.defaultContext.setupServicesWithAppKey(appKey, baseUrl: baseUrl)
    }
    
    public static func setLogLevel(levelName: String) {
        if let level = AXLog.levelByName(levelName) {
            AXLog.minLevel = level
        }
    }
    
    internal func setupServicesWithAppKey(appKey: String, baseUrl: String = "https://appstax.com/api/latest/") {
        self.appKey = appKey
        self.apiClient = AXApiClient(appKey: appKey, baseUrl: baseUrl)
        setupServicesWithApiClient(apiClient!)
    }
    
    internal func setupServicesWithApiClient(apiClient: AXApiClient) {
        self.apiClient = apiClient
        self.objectService = AXObjectService(apiClient: apiClient)
        self.userService = AXUserService(apiClient: apiClient)
        self.permissionsService = AXPermissionsService(apiClient: apiClient)
        self.fileService = AXFileService(apiClient: apiClient)
        self.realtimeService = AXRealtimeService(apiClient: apiClient)
        AXLog.info("Initialized Appstax with app key \(appKey) and base url \(apiClient.baseUrl)")
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
