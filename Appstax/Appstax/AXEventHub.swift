
import Foundation

@objc public class AXEvent: NSObject {
    
    private(set) var type: String
    
    init(type: String) {
        self.type = type
    }
}



class AXEventHub {
    
    var handlers: [String:[(AXEvent) -> ()]] = [:]
    
    func on(type: String, handler: (AXEvent) -> ()) {
        if handlers[type] == nil {
            handlers[type] = []
        }
        handlers[type]?.append(handler)
    }
    
    func dispatch(event: AXEvent) {
        handlers[event.type]?.forEach() {
            $0(event)
        }
        handlers["*"]?.forEach() {
            $0(event)
        }
    }
}
