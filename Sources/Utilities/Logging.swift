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
