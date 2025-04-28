//
//  Normalizable.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import Foundation
import NIOCore

public protocol Normalizable {}

public extension Normalizable {
    static func normalizeJSON(_ data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data)
        let normalizedData = try JSONSerialization.data(
            withJSONObject: json, options: [.sortedKeys])
        return String(data: normalizedData, encoding: .utf8)!
            .replacingOccurrences(
                of: #"\"#,
                with: "")
    }

    static func normalizeResponseBody(_ bytes: ByteBuffer) throws -> String {
        let data = Data(bytes.readableBytesView)
        var json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if var value = json?["value"] as? [String: Any],
           var capabilities = value["capabilities"] as? [String: Any] {

            if var chrome = capabilities["chrome"] as? [String: Any] {
                chrome["userDataDir"] = "[DYNAMIC_PATH]"  // Replace dynamic path
                chrome["chromedriverVersion"] = "[CHROMEDRIVER_VERSION]"
                capabilities["chrome"] = chrome
            }

            if var chromeOptions = capabilities["goog:chromeOptions"] as? [String: Any],
               let debuggerAddress = chromeOptions["debuggerAddress"] as? String {
                chromeOptions["debuggerAddress"] = debuggerAddress.replacingOccurrences(
                    of: #":\d+"#,
                    with: ":[PORT]",
                    options: .regularExpression
                )
                capabilities["goog:chromeOptions"] = chromeOptions
            }

            capabilities["browserVersion"] = "[BROWSER_VERSION]"
            value["capabilities"] = capabilities

            value["sessionId"] = "[SESSION_ID]"
            json?["value"] = value
        }

        let normalizedData = try JSONSerialization.data(
            withJSONObject: json ?? [:], options: [.sortedKeys])
        let jsonString = String(data: normalizedData, encoding: .utf8) ?? ""

        return jsonString.replacingOccurrences(of: #"\""#, with: "")
    }
}
