
import Foundation

@objc public class AXLoginConfig: NSObject {
    
    public var views: AXLoginViews
    public var providers: [String]
    
    init(views: AXLoginViews, providers: [String]) {
        self.views = views
        self.providers = providers
    }
    
}