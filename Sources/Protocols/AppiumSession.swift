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
        file: String,
        line: UInt,
        function: StaticString,
        andWaitFor: Element?,
        date: Date
    ) async throws
    func type(
        _ element: Element,
        text: String,
        file: String,
        line: UInt,
        function: StaticString
    ) async throws
    func select(
        _ element: Element,
        _ timeout: TimeInterval,
        file: String,
        line: UInt,
        function: StaticString
    ) async throws -> String
    func hierarchyContains(
        _ text: String,
        timeout: TimeInterval
    ) async throws -> Bool
    func containsMultipleInHierarchy(
        contains times: Int, _ text: String,
        timeout: TimeInterval
    ) async throws -> Bool
    func hierarchyDoesNotContain(
        _ text: String,
        timeout: TimeInterval
    ) async throws -> Bool
    func waitFor(
        _ text: String,
        timeout: TimeInterval
    ) async throws -> Bool
    func waitForDismissed(
        _ text: String,
        timeout: TimeInterval
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
