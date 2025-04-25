import Foundation
@testable import SwiftAppium

class MockAppium: AppiumClient, AppiumSession {
    var mockResponses: [String: Any] = [:]
    var mockErrors: [String: Error] = [:]
    var callCounts: [String: Int] = [:]
    
    func waitForElement(
        _ session: Session,
        _ element: Element,
        timeout: TimeInterval
    ) async throws -> String {
        let key = "waitForElement_\(element.strategy.rawValue)_\(element.selector.wrappedValue)"
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
        _ element: Element,
    ) async throws -> String? {
        let key = "findElement_\(element.strategy.rawValue)_\(element.selector.wrappedValue)"
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
    
    public func containsMultipleInHierarchy(
        _ session: Session,
        contains times: Int, _ text: String
    ) async throws -> Bool {
        let key = "containsMultipleInHierarchy_\(text)"
        if let error = mockErrors[key] {
            throw error
        }
        return mockResponses[key] as? Bool ?? false
    }
    
    public func elementValue(
        _ session: Session,
        _ element: Element
    ) async throws -> Double {
        let key = "checkElementVisibility_\(element.strategy.rawValue)_\(element.selector.wrappedValue)"
        if let error = mockErrors[key] {
            throw error
        }
        return mockResponses[key] as? Double ?? 0
    }
    
    func checkElementVisibility(
        _ session: Session,
        _ element: Element,
    ) async throws -> Bool {
        let key = "checkElementVisibility_\(element.strategy.rawValue)_\(element.selector.wrappedValue)"
        if let error = mockErrors[key] {
            throw error
        }
        return mockResponses[key] as? Bool ?? false
    }
    
    func checkElementChecked(
        _ session: Session,
        _ element: Element,
    ) async throws -> Bool {
        let key = "checkElementChecked_\(element.strategy.rawValue)_\(element.selector.wrappedValue)"
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
        _ element: Element,
        _ wait: TimeInterval
    ) async throws {
        let key = "clickElement_\(element.strategy.rawValue)_\(element.selector.wrappedValue)"
        if let error = mockErrors[key] {
            throw error
        }
    }
    
    func clickUnsafeElement(
        _ session: Session,
        _ element: Element,
        _ wait: TimeInterval
    ) async throws {
        let key = "clickElement_\(element.strategy.rawValue)_\(element.selector.wrappedValue)"
        if let error = mockErrors[key] {
            throw error
        }
    }
    
    func sendKeys(
        _ session: Session,
        _ element: Element,
        text: String
    ) async throws {
        let key = "sendKeys_\(element.strategy.rawValue)_\(element.selector.wrappedValue)_\(text)"
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
