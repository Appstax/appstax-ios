
import UIKit

@objc public class AXLoginViews: NSObject {
    
    var size: CGSize
    public var login: UIView
    public var signup: UIView
    
    init(size: CGSize) {
        self.size = size
        
        let frame = CGRect(origin: CGPointZero, size: self.size)
        login = UIView(frame: frame)
        signup = UIView(frame: frame)
    }
}
