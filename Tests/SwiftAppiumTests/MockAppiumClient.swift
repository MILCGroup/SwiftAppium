import Foundation
import Logging
import AsyncHTTPClient
@testable import SwiftAppium

class MockAppium: @unchecked Sendable, AppiumSession {
    var mockResponses: [String: Any] = [:]
    var mockErrors: [String: Error] = [:]
    var callCounts: [String: Int] = [:]

    // Helper methods for test setup
    func setMockResponse(for key: String, response: Any) {
        mockResponses[key] = response
        mockErrors.removeValue(forKey: key)
    }

    func setMockError(for key: String, error: Error) {
        mockErrors[key] = error
        mockResponses.removeValue(forKey: key)
    }

    func clearMocks() {
        mockResponses.removeAll()
        mockErrors.removeAll()
        callCounts.removeAll()
    }

    // MARK: - AppiumSession Conformance

    func executeScript(script: String, args: [Any]) async throws -> Any? {
        let key = "executeScript"
        callCounts[key, default: 0] += 1
        if let error = mockErrors[key] { throw error }
        return mockResponses[key]
    }

    func hideKeyboard() async throws {
        let key = "hideKeyboard"
        callCounts[key, default: 0] += 1
        if let error = mockErrors[key] { throw error }
    }

    func click(_ element: Element, _ logger: Logger, _ wait: TimeInterval, pollInterval: TimeInterval, andWaitFor: Element?, date: Date) async throws {
        let key = "click"
        callCounts[key, default: 0] += 1
        if let error = mockErrors[key] { throw error }
    }

    func type(_ element: Element, text: String, _ logger: Logger, pollInterval: TimeInterval) async throws {
        let key = "type"
        callCounts[key, default: 0] += 1
        if let error = mockErrors[key] { throw error }
    }

    func select(_ element: Element, _ timeout: TimeInterval, pollInterval: TimeInterval) async throws -> String {
        let key = "select"
        callCounts[key, default: 0] += 1
        if let error = mockErrors[key] { throw error }
        return mockResponses[key] as? String ?? ""
    }

    func has(_ text: String, _ logger: Logger) async throws -> Bool {
        let key = "has"
        callCounts[key, default: 0] += 1
        if let error = mockErrors[key] { throw error }
        return mockResponses[key] as? Bool ?? false
    }

    func has(_ times: Int, _ text: String, _ logger: Logger) async throws -> Bool {
        let key = "has"
        callCounts[key, default: 0] += 1
        if let error = mockErrors[key] { throw error }
        return mockResponses[key] as? Bool ?? false
    }

    func willHave(_ text: String, _ logger: Logger, timeout: TimeInterval, pollInterval: TimeInterval) async throws -> Bool {
        let key = "willHave"
        callCounts[key, default: 0] += 1
        if let error = mockErrors[key] { throw error }
        return mockResponses[key] as? Bool ?? false
    }

    func hasNo(_ text: String, _ logger: Logger) async throws -> Bool {
        let key = "hasNo"
        callCounts[key, default: 0] += 1
        if let error = mockErrors[key] { throw error }
        return mockResponses[key] as? Bool ?? true
    }

    func wontHave(_ text: String, _ logger: Logger, timeout: TimeInterval, pollInterval: TimeInterval) async throws -> Bool {
        let key = "wontHave"
        callCounts[key, default: 0] += 1
        if let error = mockErrors[key] { throw error }
        return mockResponses[key] as? Bool ?? true
    }

    func isChecked(_ element: Element) async throws -> Bool {
        let key = "isChecked"
        callCounts[key, default: 0] += 1
        if let error = mockErrors[key] { throw error }
        return mockResponses[key] as? Bool ?? false
    }

    func value(_ element: Element) async throws -> Double {
        let key = "value"
        callCounts[key, default: 0] += 1
        if let error = mockErrors[key] { throw error }
        return mockResponses[key] as? Double ?? 0.0
    }

    func isVisible(_ element: Element) async throws -> Bool {
        let key = "isVisible"
        callCounts[key, default: 0] += 1
        if let error = mockErrors[key] { throw error }
        return mockResponses[key] as? Bool ?? false
    }

    func longClickOn(_ element: Element) async throws {
        let key = "longClickOn"
        callCounts[key, default: 0] += 1
        if let error = mockErrors[key] { throw error }
    }

    func clickOn(_ element: Element) async throws {
        let key = "clickOn"
        callCounts[key, default: 0] += 1
        if let error = mockErrors[key] { throw error }
    }

    func scrollToBackdoor(_ element: Element, position: Int) async throws {
        let key = "scrollToBackdoor"
        callCounts[key, default: 0] += 1
        if let error = mockErrors[key] { throw error }
    }

    func deleteSession() async throws {
        let key = "deleteSession"
        callCounts[key, default: 0] += 1
        if let error = mockErrors[key] { throw error }
    }

    func listIdlingResource() async throws -> HTTPClient.Response {
        let key = "listIdlingResource"
        callCounts[key, default: 0] += 1
        if let error = mockErrors[key] { throw error }
        // This is tricky to mock. Let's throw for now.
        throw AppiumError.invalidResponse("Not implemented in mock")
    }

    func printIdlingResources() async throws {
        let key = "printIdlingResources"
        callCounts[key, default: 0] += 1
        if let error = mockErrors[key] { throw error }
    }
}