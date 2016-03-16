
import UIKit

public class AXLoginViews {
    
    var size: CGSize
    var login: UIView
    var signup: UIView
    
    init(size: CGSize) {
        self.size = size
        
        let frame = CGRect(origin: CGPointZero, size: self.size)
        login = UIView(frame: frame)
        signup = UIView(frame: frame)
    }
}
