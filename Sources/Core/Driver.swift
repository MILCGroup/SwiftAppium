//
//  Device.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import Testing

public enum Driver: Equatable, Sendable {
    case XCUITest(
        deviceName: String, platformVersion: String, udid: String, app: String,
        automationName: String, wdaLocalPort: Int?,
        usePreinstalledWDA: Bool? = false)
    case UIAutomator(
        deviceName: String, platformVersion: String, app: String,
        automationName: String)
    case Espresso(
        deviceName: String,
        platformVersion: String,
        app: String,
        automationName: String,
        espressoBuildConfig: String?,
        forceEspressoRebuild: Bool?,
        espressoIdleTimeout: Int
    )
    case Chromium(
        platformVersion: String, automationName: String, browserName: String)

    public var platform: Platform {
        switch self {
        case .UIAutomator, .Espresso:
            .android
        case .XCUITest:
            .iOS
        case .Chromium:
            .browser
        }
    }

    public var platformName: String {
        switch self {
        case .XCUITest:
            return "iOS"
        case .UIAutomator, .Espresso:
            return "Android"
        case .Chromium:
            return "mac"
        }
    }

    public var platformVersion: String {
        switch self {
        case .XCUITest(_, let platformVersion, _, _, _, _, _),
            .UIAutomator(_, let platformVersion, _, _), .Espresso(_, let platformVersion, _, _, _, _, _),
            .Chromium(let platformVersion, _, _):
            return platformVersion
        }
    }

    public var automationName: String {
        switch self {
        case .XCUITest(_, _, _, _, let automationName, _, _),
            .UIAutomator(_, _, _, let automationName), .Espresso(_, _, _, let automationName, _, _, _),
            .Chromium(_, let automationName, _):
            return automationName
        }
    }

    public var browserName: String? {
        switch self {
        case .Chromium(_, _, let browserName):
            return browserName
        default:
            return nil
        }
    }

    public var deviceName: String? {
        switch self {
        case .XCUITest(let deviceName, _, _, _, _, _, _),
            .UIAutomator(let deviceName, _, _, _), .Espresso(let deviceName, _, _, _, _, _, _):
            return deviceName
        default:
            return nil
        }
    }

    public var udid: String? {
        switch self {
        case .XCUITest(_, _, let udid, _, _, _, _):
            return udid
        default:
            return nil
        }
    }

    public var app: String? {
        switch self {
        case .XCUITest(_, _, _, let app, _, _, _),
            .UIAutomator(_, _, let app, _), .Espresso(_, _, let app, _, _, _, _):
            return app
        default:
            return nil
        }
    }

    public var wdaLocalPort: Int? {
        switch self {
        case .XCUITest(_, _, _, _, _, let wdaLocalPort, _):
            return wdaLocalPort
        default:
            return nil
        }
    }

    public var usePreinstalledWDA: Bool? {
        switch self {
        case .XCUITest(_, _, _, _, _, _, let usePreinstalledWDA):
            return usePreinstalledWDA
        default:
            return nil
        }
    }
    
    public var espressoBuildConfig: String? {
        switch self {
        case .Espresso(_, _, _, _, let espressoBuildConfig, _, _):
            return espressoBuildConfig
        default:
            return nil
        }
    }
    
    public var forceEspressoRebuild: Bool? {
        switch self {
        case .Espresso(_, _, _, _, _, let forceEspressoRebuild, _):
            return forceEspressoRebuild
        default:
            return nil
        }
    }
    
    public var espressoIdleTimeout: Int? {
        switch self {
        case .Espresso(_, _, _, _, _, _, let espressoIdleTimeout):
            return espressoIdleTimeout
        default:
            return nil
        }
    }
}
