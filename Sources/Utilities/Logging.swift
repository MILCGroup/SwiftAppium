//
//  Logging.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import OSLog

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

extension Logger {
    public func debug(_ message: String, logData: LogData) {
        self.debug("\(logData.fileId) -- \(message)")
    }
    public func info(_ message: String, logData: LogData) {
        self.info("\(logData.fileId) -- \(message)")
    }
    public func notice(_ message: String, logData: LogData) {
        self.notice("\(logData.fileId) -- \(message)")
    }
    public func warning(_ message: String, logData: LogData) {
        self.warning("\(logData.fileId) -- \(message)")
    }
    public func error(_ message: String, logData: LogData) {
        self.error("\(logData.fileId) -- \(message)")
    }
    public func critical(_ message: String, logData: LogData) {
        self.critical("\(logData.fileId) -- \(message)")
    }
}
