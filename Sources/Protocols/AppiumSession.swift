//
//  AppiumSession.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import AsyncHTTPClient
import Foundation
#if os(macOS)
import OSLog
#endif

public protocol AppiumSession: Sendable {
    func executeScript(
        script: String,
        args: [Any]
    ) async throws -> Any?
    func hideKeyboard() async throws
    func click(
        _ element: Element,
        _ logger: Logger,
        _ wait: TimeInterval,
        pollInterval: TimeInterval,
        andWaitFor: Element?,
        date: Date
    ) async throws
    func type(
        _ element: Element,
        text: String,
        _ logger: Logger,
        pollInterval: TimeInterval
    ) async throws
    func select(
        _ element: Element,
        _ timeout: TimeInterval,
        pollInterval: TimeInterval
    ) async throws -> String
    func has(
        _ text: String,
        _ logger: Logger
    ) async throws -> Bool
    func has(
        _ times: Int,
        _ text: String,
        _ logger: Logger
    ) async throws -> Bool
    func willHave(
        _ text: String,
        _ logger: Logger,
        timeout: TimeInterval,
        pollInterval: TimeInterval
    ) async throws -> Bool
    func hasNo(
        _ text: String,
        _ logger: Logger
    ) async throws -> Bool
    func wontHave(
        _ text: String,
        _ logger: Logger,
        timeout: TimeInterval,
        pollInterval: TimeInterval
    ) async throws -> Bool
    func isChecked(
        _ element: Element
    ) async throws -> Bool
    func value(
        _ element: Element
    ) async throws -> Double
    func isVisible(
        _ element: Element
    ) async throws -> Bool
    func longClickOn(_ element: Element) async throws 
    func clickOn(_ element: Element) async throws
    func scrollToBackdoor(_ element: Element, position: Int) async throws
    func deleteSession() async throws
    func listIdlingResource() async throws -> HTTPClient.Response
    func printIdlingResources() async throws
}
