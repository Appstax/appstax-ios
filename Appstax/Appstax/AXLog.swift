
import Foundation

public enum AXLogLevel: Int {
    case Trace = 0
    case Debug
    case Info
    case Warn
    case Error
    case Fatal
    case Off
}

internal class AXLog {
    
    internal static var minLevel: AXLogLevel = .Info
    
    internal static func log(level: AXLogLevel, _ message: String) {
        if level.rawValue >= minLevel.rawValue {
            NSLog("\(label(level)) \(message)")
        }
    }
    
    internal static func trace(message: String) {
        log(.Trace, message)
    }
    
    internal static func debug(message: String) {
        log(.Debug, message)
    }
    
    internal static func info(message: String) {
        log(.Info, message)
    }
    
    internal static func warn(message: String) {
        log(.Warn, message)
    }
    
    internal static func error(message: String) {
        log(.Error, message)
    }
    
    internal static func fatal(message: String) {
        log(.Fatal, message)
    }
    
    internal static func label(level: AXLogLevel) -> String {
        return "[APPSTAX][\(levelName(level))]"
    }
    
    internal static func levelName(level: AXLogLevel) -> String {
        switch level {
        case .Trace: return "TRACE"
        case .Debug: return "DEBUG"
        case .Info:  return "INFO"
        case .Warn:  return "WARN"
        case .Error: return "ERROR"
        case .Fatal: return "FATAL"
        case .Off:   return "OFF"
        }
    }
    
    internal static func levelByName(levelName: String) -> AXLogLevel? {
        switch levelName.uppercaseString {
        case "TRACE": return .Trace
        case "DEBUG": return .Debug
        case "INFO":  return .Info
        case "WARN":  return .Warn
        case "ERROR": return .Error
        case "FATAL": return .Fatal
        case "OFF":   return .Off
        default:      return nil
        }
    }
    
}
