//
//  SessionResponse.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import AsyncHTTPClient

public struct SessionResponse: Codable {
    public let value: [Session]

    public struct Session: Codable {
        public let id: String
        public let capabilities: Capabilities

        public struct Capabilities: Codable {
            public let platformName: String?
            public let deviceName: String?
            public let browserName: String?
            public let udid: String?
            public let app: String?
            public let newCommandTimeout: Int?
            public let automationName: String?
            public let platformVersion: String?
            public let wdaLocalPort: Int?
            public let javascriptEnabled: Bool?
            public let databaseEnabled: Bool?
            public let takesScreenshot: Bool?
            public let networkConnectionEnabled: Bool?
            public let webStorageEnabled: Bool?
            public let locationContextEnabled: Bool?
        }
    }
}
