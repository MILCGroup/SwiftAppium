//
//  AppiumSession.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import Foundation

public protocol AppiumSession: Sendable {
    func executeScript(
        script: String,
        args: [Any]
    ) async throws -> Any?
    func hideKeyboard() async throws
    func click(
        _ element: Element,
        _ wait: TimeInterval,
        pollInterval: TimeInterval,
        andWaitFor: Element?,
        date: Date
    ) async throws
    func type(
        _ element: Element,
        text: String,
        pollInterval: TimeInterval
    ) async throws
    func select(
        _ element: Element,
        _ timeout: TimeInterval,
        pollInterval: TimeInterval
    ) async throws -> String
    func has(
        _ text: String
    ) async throws -> Bool
    func has(
        _ times: Int,
        _ text: String
    ) async throws -> Bool
    func willHave(
        _ text: String,
        timeout: TimeInterval,
        pollInterval: TimeInterval
    ) async throws -> Bool
    func hasNo(
        _ text: String
    ) async throws -> Bool
    func wontHave(
        _ text: String,
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
}
