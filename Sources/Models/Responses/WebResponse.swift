//
//  WebResponse.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

public struct WebResponse: Codable {
    public let value: Session

    public struct Session: Codable {
        public let sessionId: String?
        public let capabilities: Capabilities

        public struct Capabilities: Codable {
            private enum CodingKeys: String, CodingKey {
                case platformName, browserName, platformVersion, automationName
                case newCommandTimeout
                case timeouts, proxy
                case acceptInsecureCerts
                case chrome
            }

            public let platformName, browserName: String
            public let platformVersion, automationName: String?
            public let newCommandTimeout: Int?
            public let acceptInsecureCerts: Bool?
            public let timeouts: Timeouts?
            public let proxy: [String: String]?
            public let chrome: ChromeInfo?

            public init(
                platformName: String, platformVersion: String,
                automationName: String,
                browserName: String, newCommandTimeout: Int
            ) {
                self.platformName = platformName
                self.browserName = browserName
                self.automationName = automationName
                self.platformVersion = platformVersion
                self.newCommandTimeout = newCommandTimeout
                self.acceptInsecureCerts = nil
                self.timeouts = nil
                self.proxy = nil
                self.chrome = nil
            }

            public struct Timeouts: Codable {
                let implicit: Int
                let pageLoad: Int
                let script: Int
            }

            public struct ChromeInfo: Codable {
                let chromedriverVersion: String
                let userDataDir: String
            }
        }
    }
}

extension WebResponse.Session {
    public init(from webValue: SessionResponse.Session) {
        self.init(
            sessionId: webValue.id,
            capabilities: Capabilities(
                platformName: webValue.capabilities.platformName ?? "",
                platformVersion: webValue.capabilities.platformVersion ?? "",
                automationName: webValue.capabilities.automationName ?? "",
                browserName: webValue.capabilities.browserName ?? "",
                newCommandTimeout: webValue.capabilities.newCommandTimeout
                    ?? 3600
            )
        )

    }
}
