//
//  Device.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import Testing

public enum Device: Equatable, Sendable {
    case iOS(
        deviceName: String, platformVersion: String, udid: String, app: String,
        automationName: String, wdaLocalPort: Int?,
        usePreinstalledWDA: Bool? = false)
    case Android(
        deviceName: String, platformVersion: String, app: String,
        automationName: String, espressoBuildConfig: String?)
    case Browser(
        platformVersion: String, automationName: String, browserName: String)

    public var platform: Platform {
        switch self {
        case .Android:
            .android
        case .iOS:
            .iOS
        case .Browser:
            .browser
        }
    }

    public var platformName: String {
        switch self {
        case .iOS:
            return "iOS"
        case .Android:
            return "Android"
        case .Browser:
            return "mac"
        }
    }

    public var platformVersion: String {
        switch self {
        case .iOS(_, let platformVersion, _, _, _, _, _),
            .Android(_, let platformVersion, _, _, _),
            .Browser(let platformVersion, _, _):
            return platformVersion
        }
    }

    public var automationName: String {
        switch self {
        case .iOS(_, _, _, _, let automationName, _, _),
            .Android(_, _, _, let automationName, _),
            .Browser(_, let automationName, _):
            return automationName
        }
    }

    public var browserName: String? {
        switch self {
        case .Browser(_, _, let browserName):
            return browserName
        default:
            return nil
        }
    }

    public var deviceName: String? {
        switch self {
        case .iOS(let deviceName, _, _, _, _, _, _),
            .Android(let deviceName, _, _, _, _):
            return deviceName
        default:
            return nil
        }
    }

    public var udid: String? {
        switch self {
        case .iOS(_, _, let udid, _, _, _, _):
            return udid
        default:
            return nil
        }
    }

    public var app: String? {
        switch self {
        case .iOS(_, _, _, let app, _, _, _),
            .Android(_, _, let app, _, _):
            return app
        default:
            return nil
        }
    }

    public var wdaLocalPort: Int? {
        switch self {
        case .iOS(_, _, _, _, _, let wdaLocalPort, _):
            return wdaLocalPort
        default:
            return nil
        }
    }

    public var usePreinstalledWDA: Bool? {
        switch self {
        case .iOS(_, _, _, _, _, _, let usePreinstalledWDA):
            return usePreinstalledWDA
        default:
            return nil
        }
    }

    public var espressoBuildConfig: String? {
        switch self {
        case .Android(_, _, _, _, let espressoBuildConfig):
            return espressoBuildConfig
        default:
            return nil
        }
    }
}
