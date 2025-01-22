//
//  iOSResponse.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

public struct iOSResponse: Codable {
    public let value: Value

    public struct Value: Codable {
        public let id: String
        public let capabilities: Capabilities

        public enum CodingKeys: String, CodingKey {
            case id
            case sessionId
            case capabilities
        }

        public init(id: String, capabilities: Capabilities) {
            self.id = id
            self.capabilities = capabilities
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.capabilities = try container.decode(
                Capabilities.self, forKey: .capabilities)
            if let sessionId = try? container.decode(
                String.self, forKey: .sessionId)
            {
                self.id = sessionId
            } else {
                self.id = try container.decode(String.self, forKey: .id)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(capabilities, forKey: .capabilities)
            try container.encode(id, forKey: .id)
        }

        public struct Capabilities: Codable {
            public let platformName: String
            public let deviceName: String
            public let browserName: String?
            public let udid: String
            public let app: String
            public let newCommandTimeout: Int
            public let automationName: String
            public let platformVersion: String
            public let wdaLocalPort: Int
            public let webStorageEnabled: Bool?
            public let locationContextEnabled: Bool?
            public let platform: String?
            public let javascriptEnabled: Bool?
            public let databaseEnabled: Bool?
            public let takesScreenshot: Bool?
            public let networkConnectionEnabled: Bool?
        }
    }
}

// Conversion extension to convert from SessionResponse.Session to iOSResponse.Value
extension iOSResponse.Value {
    public init(from iOSValue: SessionResponse.Session) {
        self.init(
            id: iOSValue.id,
            capabilities: Capabilities(
                platformName: iOSValue.capabilities.platformName ?? "",
                deviceName: iOSValue.capabilities.deviceName ?? "",
                browserName: iOSValue.capabilities.browserName ?? "",
                udid: iOSValue.capabilities.udid ?? "",
                app: iOSValue.capabilities.app ?? "",
                newCommandTimeout: iOSValue.capabilities.newCommandTimeout
                    ?? 3600,
                automationName: iOSValue.capabilities.automationName ?? "",
                platformVersion: iOSValue.capabilities.platformVersion ?? "",
                wdaLocalPort: iOSValue.capabilities.wdaLocalPort ?? 8201,
                webStorageEnabled: iOSValue.capabilities.webStorageEnabled
                    ?? false,
                locationContextEnabled: iOSValue.capabilities
                    .locationContextEnabled ?? false,
                platform: iOSValue.capabilities.platformName ?? "",
                javascriptEnabled: iOSValue.capabilities.javascriptEnabled
                    ?? false,
                databaseEnabled: iOSValue.capabilities.databaseEnabled ?? false,
                takesScreenshot: iOSValue.capabilities.takesScreenshot ?? false,
                networkConnectionEnabled: iOSValue.capabilities
                    .networkConnectionEnabled ?? false
            )
        )
    }
}
