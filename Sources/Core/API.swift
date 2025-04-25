//
//  API.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

/// API Enpoints for Appium Server
/// https://github.com/appium/appium/blob/master/packages/base-driver/lib/protocol/routes.js
public struct API: Sendable {
    nonisolated(unsafe) public static var serverURL: String = "http://localhost:4723"

    public init(_ serverURL: String = "http://localhost:4723") {
        API.serverURL = serverURL
    }
    
    private static func path(for sessionId: String, additional: String = "") -> String {
        return "\(serverURL)/session/\(sessionId)\(additional)"
    }

    public static func sessions() -> String {
        return "\(serverURL)/sessions"
    }

    public static func status() -> String {
        return "\(serverURL)/status"
    }

    public static func session(_ sessionId: String) -> String {
        return path(for: sessionId)
    }

    public static func source(_ sessionId: String) -> String {
        return path(for: sessionId, additional: "/source")
    }

    public static func element(_ sessionId: String) -> String {
        return path(for: sessionId, additional: "/element")
    }

    public static func click(_ elementId: String, _ sessionId: String) -> String {
        return path(for: sessionId, additional: "/element/\(elementId)/click")
    }

    public static func attributeValue(_ elementId: String, _ sessionId: String) -> String {
        return path(for: sessionId, additional: "/element/\(elementId)/attribute/value")
    }

    public static func value(_ elementId: String, _ sessionId: String) -> String {
        return path(for: sessionId, additional: "/element/\(elementId)/value")
    }

    public static func url(_ sessionId: String) -> String {
        return path(for: sessionId, additional: "/url")
    }

    public static func settings(_ sessionId: String) -> String {
        return path(for: sessionId, additional: "/appium/settings")
    }

    public static func hideKeyboard(_ sessionId: String) -> String {
        return path(for: sessionId, additional: "/appium/device/hide_keyboard")
    }

    public static func reset(_ sessionId: String) -> String {
        return path(for: sessionId, additional: "/appium/app/reset")
    }

    public static func fullscreen(_ sessionId: String) -> String {
        return path(for: sessionId, additional: "/window/fullscreen")
    }

    public static func execute(_ sessionId: String) -> String {
        return path(for: sessionId, additional: "/execute/sync")
    }

    public static func selected(_ elementId: String, _ sessionId: String) -> String {
        return path(for: sessionId, additional: "/element/\(elementId)/selected")
    }

    public static func text(_ elementId: String, _ sessionId: String) -> String {
        return path(for: sessionId, additional: "/element/\(elementId)/text")
    }

    public static func displayed(_ elementId: String, _ sessionId: String) -> String {
        return path(for: sessionId, additional: "/element/\(elementId)/displayed")
    }
}
