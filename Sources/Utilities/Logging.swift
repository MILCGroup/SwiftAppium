//
//  Logging.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

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
