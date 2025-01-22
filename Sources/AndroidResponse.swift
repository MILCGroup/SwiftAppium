//
//  AndroidResponse.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

public struct AndroidResponse: Codable {
    public let value: ResponseValue

    public struct ResponseValue: Codable {
        public let capabilities: Capabilities
        public let sessionId: String?
        public let id: String?

        public init(capabilities: Capabilities, sessionId: String?, id: String?)
        {
            self.capabilities = capabilities
            self.sessionId = sessionId
            self.id = id
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.capabilities = try container.decode(
                Capabilities.self, forKey: .capabilities)
            self.sessionId = try container.decodeIfPresent(
                String.self, forKey: .sessionId)
            self.id = try container.decodeIfPresent(String.self, forKey: .id)
        }

        public var identifier: String {
            return sessionId ?? id ?? ""
        }

        public struct Capabilities: Codable {
            public let platformName: String
            public let deviceName: String
            public let platformVersion: String
            public let app: String
            public let newCommandTimeout: Int
            public let automationName: String
            public let platform: String?
            public let webStorageEnabled: Bool?
            public let takesScreenshot: Bool?
            public let javascriptEnabled: Bool?
            public let databaseEnabled: Bool?
            public let networkConnectionEnabled: Bool?
            public let locationContextEnabled: Bool?
            public let warnings: [String: String]?
            public let desired: DesiredCapabilities?
            public let deviceUDID: String?
            public let appPackage: String?
            public let pixelRatio: String?
            public let statBarHeight: Int?
            public let viewportRect: ViewportRect?
            public let deviceApiLevel: Int?
            public let deviceManufacturer: String?
            public let deviceModel: String?
            public let deviceScreenSize: String?
            public let deviceScreenDensity: Int?

            public struct DesiredCapabilities: Codable {
                public let platformName: String
                public let deviceName: String
                public let platformVersion: String
                public let app: String
                public let newCommandTimeout: Int
                public let automationName: String
            }

            public struct ViewportRect: Codable {
                public let left: Int
                public let top: Int
                public let width: Int
                public let height: Int
            }
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let singleValue = try? container.decode(
            ResponseValue.self, forKey: .value)
        {
            self.value = singleValue
        } else if var arrayContainer = try? container.nestedUnkeyedContainer(
            forKey: .value),
            let firstElement = try? arrayContainer.decode(ResponseValue.self)
        {
            self.value = firstElement
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription:
                        "Expected ResponseValue or [ResponseValue]"))
        }
    }

    public enum CodingKeys: String, CodingKey {
        case value
    }
}

extension AndroidResponse.ResponseValue {
    public init(from androidValue: SessionResponse.Session) {
        self.init(
            capabilities: Capabilities(
                platformName: androidValue.capabilities.platformName ?? "",
                deviceName: androidValue.capabilities.deviceName ?? "",
                platformVersion: androidValue.capabilities.platformVersion
                    ?? "",
                app: "",
                newCommandTimeout: androidValue.capabilities.newCommandTimeout
                    ?? 3600,
                automationName: androidValue.capabilities.automationName ?? "",
                platform: nil,
                webStorageEnabled: nil,
                takesScreenshot: nil,
                javascriptEnabled: nil,
                databaseEnabled: nil,
                networkConnectionEnabled: nil,
                locationContextEnabled: nil,
                warnings: nil,
                desired: nil,
                deviceUDID: nil,
                appPackage: nil,
                pixelRatio: nil,
                statBarHeight: nil,
                viewportRect: nil,
                deviceApiLevel: nil,
                deviceManufacturer: nil,
                deviceModel: nil,
                deviceScreenSize: nil,
                deviceScreenDensity: nil
            ),
            sessionId: androidValue.id,
            id: androidValue.id
        )
    }
}
