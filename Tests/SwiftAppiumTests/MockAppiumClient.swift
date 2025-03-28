import Foundation
@testable import SwiftAppium

class MockAppiumClient: AppiumClient {
    var mockResponses: [String: Any] = [:]
    var mockErrors: [String: Error] = [:]
    var callCounts: [String: Int] = [:]
    
    func waitForElement(
        _ session: Session,
        strategy: Strategy,
        selector: String,
        timeout: TimeInterval
    ) async throws -> String {
        let key = "waitForElement_\(strategy.rawValue)_\(selector)"
        if let error = mockErrors[key] {
            throw error
        }
        if let response = mockResponses[key] as? String {
            return response
        }
        throw AppiumError.elementNotFound("Element not found")
    }
    
    func findElement(
        _ session: Session,
        strategy: Strategy,
        selector: String
    ) async throws -> String? {
        let key = "findElement_\(strategy.rawValue)_\(selector)"
        if let error = mockErrors[key] {
            throw error
        }
        return mockResponses[key] as? String
    }
    
    func containsInHierarchy(
        _ session: Session,
        contains text: String
    ) async throws -> Bool {
        let key = "containsInHierarchy_\(text)"
        if let error = mockErrors[key] {
            throw error
        }
        return mockResponses[key] as? Bool ?? false
    }
    
    func checkElementVisibility(
        _ session: Session,
        strategy: Strategy,
        selector: String
    ) async throws -> Bool {
        let key = "checkElementVisibility_\(strategy.rawValue)_\(selector)"
        if let error = mockErrors[key] {
            throw error
        }
        return mockResponses[key] as? Bool ?? false
    }
    
    func executeScript(
        _ session: Session,
        script: String,
        args: [Any]
    ) async throws -> Any? {
        let key = "executeScript_\(script)"
        if let error = mockErrors[key] {
            throw error
        }
        return mockResponses[key]
    }
    
    func hideKeyboard(
        _ session: Session
    ) async throws {
        let key = "hideKeyboard"
        if let error = mockErrors[key] {
            throw error
        }
    }
    
    func clickElement(
        _ session: Session,
        strategy: Strategy,
        selector: String,
        _ wait: TimeInterval
    ) async throws {
        let key = "clickElement_\(strategy.rawValue)_\(selector)"
        if let error = mockErrors[key] {
            throw error
        }
    }
    
    func sendKeys(
        _ session: Session,
        strategy: Strategy,
        selector: String,
        text: String
    ) async throws {
        let key = "sendKeys_\(strategy.rawValue)_\(selector)_\(text)"
        if let error = mockErrors[key] {
            throw error
        }
    }
    
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
} 