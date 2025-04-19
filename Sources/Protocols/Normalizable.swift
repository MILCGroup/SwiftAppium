//
//  Normalizable.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import Foundation
import NIOCore

public protocol Normalizable {}

extension Normalizable {
    public func normalizeJSON(_ data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data)
        let normalizedData = try JSONSerialization.data(
            withJSONObject: json, options: [.sortedKeys])
        return String(data: normalizedData, encoding: .utf8)!
            .replacingOccurrences(
                of: #"\"#,
                with: "")
    }

    public func normalizeResponseBody(_ bytes: ByteBuffer) throws -> String {
        let data = Data(bytes.readableBytesView)
        var json =
            try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Normalize dynamic values in the JSON structure
        if var value = json?["value"] as? [String: Any],
            var capabilities = value["capabilities"] as? [String: Any]
        {

            // Replace dynamic chrome values
            if var chrome = capabilities["chrome"] as? [String: Any] {
                chrome["userDataDir"] = "[DYNAMIC_PATH]"  // Replace dynamic path
                capabilities["chrome"] = chrome
            }

            // Replace dynamic chromeOptions values
            if var chromeOptions = capabilities["goog:chromeOptions"]
                as? [String: Any]
            {
                if let debuggerAddress = chromeOptions["debuggerAddress"]
                    as? String
                {
                    // Replace only the port number
                    chromeOptions["debuggerAddress"] =
                        debuggerAddress.replacingOccurrences(
                            of: #":\d+"#,
                            with: ":[PORT]",
                            options: .regularExpression
                        )
                }
                capabilities["goog:chromeOptions"] = chromeOptions
            }

            value["capabilities"] = capabilities
            value["browserVersion"] = "[BROWSER_VERSION]"
            value["chromedriverVersion"] = "[CHROMEDRIVER_VERSION]"
            value["sessionId"] = "[SESSION_ID]"
            json?["value"] = value
        }

        // Convert back to normalized string and remove whitespace
        let normalizedData = try JSONSerialization.data(
            withJSONObject: json ?? [:], options: [.sortedKeys])
        let jsonString = String(data: normalizedData, encoding: .utf8) ?? ""

        // Remove Backslashes
        return jsonString.replacingOccurrences(
            of: #"\"#,
            with: "")
    }
}
