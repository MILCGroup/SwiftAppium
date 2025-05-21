//
//  Logging.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import OSLog

public func log(
    subsytem: String = #function,
    category: Int = #line
) -> Logger {
    Logger(
        subsystem: subsytem,
        category: String(category)
    )
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
