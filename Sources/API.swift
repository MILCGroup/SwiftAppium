//
//  API.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

/// API Enpoints for Appium Server
/// https://github.com/appium/appium/blob/master/packages/base-driver/lib/protocol/routes.js
public enum API {
    case sessions
    case session(String)
    case status
    case source(String)
    case element(String)
    case click(String, String)
    case value(String, String)
    case url(String)
    case settings(String)
    case hideKeyboard(String)
    case reset(String)
    case fullscreen(String)
    case execute(String)
    case selected(String, String)
    case text(String, String)

    public static let serverURL = "http://localhost:4723"

    private func path(for sessionId: String, additional: String = "") -> String
    {
        return "\(API.serverURL)/session/\(sessionId)\(additional)"
    }

    public var path: String {
        switch self {
        case .sessions:
            return "\(API.serverURL)/sessions"
        case .status:
            return "\(API.serverURL)/status"
        case .session(let sessionId):
            return path(for: sessionId)
        case .source(let sessionId):
            return path(for: sessionId, additional: "/source")
        case .element(let sessionId):
            return path(for: sessionId, additional: "/element")
        case .click(let elementId, let sessionId):
            return path(
                for: sessionId, additional: "/element/\(elementId)/click")
        case .value(let elementId, let sessionId):
            return path(
                for: sessionId, additional: "/element/\(elementId)/value")
        case .url(let sessionId):
            return path(for: sessionId, additional: "/url")
        case .settings(let sessionId):
            return path(for: sessionId, additional: "/appium/settings")
        case .hideKeyboard(let sessionId):
            return path(
                for: sessionId, additional: "/appium/device/hide_keyboard")
        case .reset(let sessionId):
            return path(
                for: sessionId, additional: "/appium/app/reset")
        case .fullscreen(let sessionId):
            return path(
                for: sessionId, additional: "/window/fullscreen")
        case .execute(let sessionId):
            return path(
                for: sessionId, additional: "/execute/sync")
        case .selected(let elementId, let sessionId):
            return path(
                for: sessionId, additional: "/element/\(elementId)/selected")
        case .text(let elementId, let sessionId):
            return path(
                for: sessionId, additional: "/element/\(elementId)/text")
        }
    }
}
