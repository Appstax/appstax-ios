
import Foundation

func delay(time: NSTimeInterval, _ fn: () -> ()) {
    let action = DelayAction(fn: fn)
    NSTimer.scheduledTimerWithTimeInterval(time, target: action, selector: "execute", userInfo: nil, repeats: false)
}

class DelayAction: NSObject {
    
    private var fn: () -> ()
    
    init(fn: () -> ()) {
        self.fn = fn
    }
    
    func execute() {
        self.fn()
    }
}
