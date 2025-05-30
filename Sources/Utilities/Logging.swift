//
//  Logging.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

#if os(macOS)
import OSLog

@discardableResult
public func logger(
    _ message: String = "",
    level: OSLogType = .info,
    subsystem: String = #function,
    file: StaticString = #file,
    line: Int = #line
) -> Logger {
    let logger = Logger(subsystem: subsystem, category: "\(file):\(line)")
    logger.log(level: level, "\(message, privacy: .private)")
    return logger
}

public let iOSLogger = Logger(subsystem: "SwiftAppium", category: "iOS")
public let androidLogger = Logger(subsystem: "SwiftAppium", category: "Android")
public let webLogger = Logger(subsystem: "SwiftAppium", category: "Web")
public let appiumLogger = Logger(subsystem: "SwiftAppium", category: "Client")
public let testLogger = Logger(subsystem: "SwiftAppium", category: "Test")

public struct LogData {
    public let file: StaticString
    public let line: UInt
    public let function: StaticString
    
    public init(
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) {
        self.file = file
        self.line = line
        self.function = function
    }
    
    public var fileId: String { "\(function) in \(file):\(line)" }
}

#else
import Foundation
import Dispatch

public enum OSLogType: @unchecked Sendable {
    case debug
    case info
    case error
    case fault
    case `default`
    case critical
    case warning
    
    var prefix: String {
        switch self {
        case .debug: return "🔍 DEBUG"
        case .info: return "ℹ️ INFO"
        case .error: return "❌ ERROR"
        case .fault: return "💥 FAULT"
        case .default: return "📝 LOG"
        case .critical: return "🚨 CRITICAL"
        case .warning: return "⚠️ WARNING"
        }
    }
}

public final class Logger: @unchecked Sendable {
    private let subsystem: String
    private let category: String
    private let dateFormatter: ISO8601DateFormatter
    private let queue: DispatchQueue
    
    public init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
        self.dateFormatter = ISO8601DateFormatter()
        self.queue = DispatchQueue(label: "com.swiftappium.logger.\(subsystem).\(category)")
    }
    
    private func logInternal(level: OSLogType, _ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] [\(level.prefix)] [\(subsystem):\(category)] \(message)")
    }
    
    public func log(level: OSLogType = .default, _ message: String) {
        queue.sync {
            logInternal(level: level, message)
        }
    }
    
    // Convenience methods to match OSLog interface
    public func debug(_ message: String) {
        log(level: .debug, message)
    }
    
    public func info(_ message: String) {
        log(level: .info, message)
    }
    
    public func error(_ message: String) {
        log(level: .error, message)
    }
    
    public func warning(_ message: String) {
        log(level: .warning, message)
    }
    
    public func critical(_ message: String) {
        log(level: .critical, message)
    }
}

@discardableResult
public func logger(
    _ message: String = "",
    level: OSLogType = .info,
    subsystem: String = #function,
    file: StaticString = #file,
    line: Int = #line
) -> Logger {
    let logger = Logger(subsystem: subsystem, category: "\(file):\(line)")
    logger.log(level: level, message)
    return logger
}

public let iOSLogger = Logger(subsystem: "SwiftAppium", category: "iOS")
public let androidLogger = Logger(subsystem: "SwiftAppium", category: "Android")
public let webLogger = Logger(subsystem: "SwiftAppium", category: "Web")
public let appiumLogger = Logger(subsystem: "SwiftAppium", category: "Client")
public let testLogger = Logger(subsystem: "SwiftAppium", category: "Test")

public struct LogData {
    public let file: StaticString
    public let line: UInt
    public let function: StaticString
    
    public init(
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) {
        self.file = file
        self.line = line
        self.function = function
    }
    
    public var fileId: String { "\(function) in \(file):\(line)" }
}
#endif