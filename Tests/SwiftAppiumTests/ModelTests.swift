import Testing
@testable import SwiftAppium
import AsyncHTTPClient

enum TestError: Throwable {
    case expectedError
    
    var userFriendlyMessage: String {
        switch self {
        case .expectedError:
            return "An expected error occurred during testing"
        }
    }
}

@Suite("Model Tests")
struct ModelTests {
    private var session: Session?
    private var element: Element?
    private var mockClient: MockAppium?
    private var httpClient: HTTPClient?
    
    @Test("Setup and teardown")
    func setupAndTeardown() async throws {
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        let session: Session! = Session(client: httpClient, id: "test-session-id", platform: .android)
        let selector: Selector! = .init("test-button")
        let element: Element? = Element(.id, selector)
        let mockClient: MockAppium! = MockAppium()
        mockClient.clearMocks()
        
        #expect(session != nil)
        #expect(mockClient != nil)
        #expect(selector != nil)
        #expect(element != nil)
        
        try? await httpClient.shutdown()
    }
    
    @Test("Wait for element")
    func waitForElement() async throws {
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        let session = Session(client: httpClient, id: "test-session-id", platform: .android)
        let element = Element(.id, .init("test-button"))
        let elementTimedOut = Element(.id, .init("timeout-button"))
        let mockClient = MockAppium()
        
        // Test successful case
        mockClient.setMockResponse(
            for: "waitForElement_id_test-button",
            response: "element-123"
        )
        
        let elementId = try await mockClient.waitForElement(
            session,
            element,
            timeout: 5
        )
        
        #expect(elementId == "element-123")
        
        // Test timeout case
        mockClient.setMockError(
            for: "waitForElement_id_timeout-button",
            error: AppiumError.timeoutError("Timeout reached")
        )
        
        do {
            _ = try await mockClient.waitForElement(
                session,
                elementTimedOut,
                timeout: 1
            )
            throw TestError.expectedError
        } catch AppiumError.timeoutError {
            // Expected error
        }
        
        try? await httpClient.shutdown()
    }
    
    @Test("Find element")
    func findElement() async throws {
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        let session = Session(client: httpClient, id: "test-session-id", platform: .android)
        let element: Element! = Element(.id, .init("test-input"))
        let elementNonExistent: Element! = Element(.id, .init("non-existent"))
        let mockClient = MockAppium()
        
        // Test successful case
        mockClient.setMockResponse(
            for: "findElement_id_test-input",
            response: "input-123"
        )
        
        let elementId = try await mockClient.findElement(
            session,
            element
        )
        
        #expect(elementId == "input-123")
        
        // Test not found case
        mockClient.setMockError(
            for: "findElement_id_non-existent",
            error: AppiumError.elementNotFound("Element not found")
        )
        
        do {
            _ = try await mockClient.findElement(
                session,
                elementNonExistent
            )
            throw TestError.expectedError
        } catch AppiumError.elementNotFound {
            // Expected error
        }
        
        try? await httpClient.shutdown()
    }
    
    @Test("Contains in hierarchy")
    func containsInHierarchy() async throws {
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        let session = Session(client: httpClient, id: "test-session-id", platform: .android)
        let mockClient = MockAppium()
        
        // Test successful case
        mockClient.setMockResponse(
            for: "containsInHierarchy_Test Text",
            response: true
        )
        
        let contains = try await mockClient.containsInHierarchy(
            session,
            contains: "Test Text"
        )
        #expect(contains)
        
        // Test not found case
        mockClient.setMockResponse(
            for: "containsInHierarchy_Missing Text",
            response: false
        )
        
        let notContains = try await mockClient.containsInHierarchy(
            session,
            contains: "Missing Text"
        )
        #expect(!notContains)
        
        try? await httpClient.shutdown()
    }
    
    @Test("Contains Multiple in hierarchy")
    func containsMultipleInHierarchy() async throws {
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        let session = Session(client: httpClient, id: "test-session-id", platform: .android)
        let mockClient = MockAppium()
        
        // Test successful case
        mockClient.setMockResponse(
            for: "containsMultipleInHierarchy_Test Text",
            response: true
        )
        
        let contains = try await mockClient.containsMultipleInHierarchy(
            session,
            contains: 1, "Test Text"
        )
        #expect(contains)
        
        // Test not found case
        mockClient.setMockResponse(
            for: "containsInHierarchy_Missing Text",
            response: false
        )
        
        let notContains = try await mockClient.containsMultipleInHierarchy(
            session,
            contains: 1, "Missing Text"
        )
        #expect(!notContains)
        
        try? await httpClient.shutdown()
    }
    
    @Test("Element value")
    func elementValue() async throws {
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        let session = Session(client: httpClient, id: "test-session-id", platform: .android)
        let element: Element = Element(.id, .init("visible-element"))
        let elementHidden: Element = Element(.id, .init("hidden-element"))
        let mockClient = MockAppium()
        
        // Test visible case
        mockClient.setMockResponse(
            for: "checkElementValue_id_visible-element",
            response: true
        )
        
        let isVisible = try await mockClient.elementValue(
            session,
            element
        )
        #expect(isVisible == 0)
        
        // Test hidden case
        mockClient.setMockResponse(
            for: "checkElementValue_id_hidden-element",
            response: false
        )
        
        let isHidden = try await mockClient.elementValue(
            session,
            elementHidden
        )
        #expect(isHidden == 0)
        
        try? await httpClient.shutdown()
    }
    
    @Test("Check element visibility")
    func checkElementVisibility() async throws {
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        let session = Session(client: httpClient, id: "test-session-id", platform: .android)
        let element: Element = Element(.id, .init("visible-element"))
        let elementHidden: Element = Element(.id, .init("hidden-element"))
        let mockClient = MockAppium()
        
        // Test visible case
        mockClient.setMockResponse(
            for: "checkElementVisibility_id_visible-element",
            response: true
        )
        
        let isVisible = try await mockClient.checkElementVisibility(
            session,
            element
        )
        #expect(isVisible)
        
        // Test hidden case
        mockClient.setMockResponse(
            for: "checkElementVisibility_id_hidden-element",
            response: false
        )
        
        let isHidden = try await mockClient.checkElementVisibility(
            session,
            elementHidden
        )
        #expect(!isHidden)
        
        try? await httpClient.shutdown()
    }
    
    @Test("Check element checked")
    func checkElementChecked() async throws {
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        let session = Session(client: httpClient, id: "test-session-id", platform: .android)
        let element: Element = Element(.id, .init("visible-element"))
        let elementHidden: Element = Element(.id, .init("hidden-element"))
        let mockClient = MockAppium()
        
        // Test visible case
        mockClient.setMockResponse(
            for: "checkElementChecked_id_visible-element",
            response: true
        )
        
        let isVisible = try await mockClient.checkElementChecked(
            session,
            element
        )
        #expect(isVisible)
        
        // Test hidden case
        mockClient.setMockResponse(
            for: "checkElementChecked_id_hidden-element",
            response: false
        )
        
        let isHidden = try await mockClient.checkElementChecked(
            session,
            elementHidden
        )
        #expect(!isHidden)
        
        try? await httpClient.shutdown()
    }
    
    @Test("Execute script")
    func executeScript() async throws {
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        let session = Session(client: httpClient, id: "test-session-id", platform: .android)
        let mockClient = MockAppium()
        
        // Test successful case
        let expectedResult = ["status": "success"]
        mockClient.setMockResponse(
            for: "executeScript_return { status: 'success' }",
            response: expectedResult
        )
        
        let result = try await mockClient.executeScript(
            session,
            script: "return { status: 'success' }",
            args: []
        )
        
        #expect(result as? [String: String] == expectedResult)
        
        try? await httpClient.shutdown()
    }
    
    @Test("Hide keyboard")
    func hideKeyboard() async throws {
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        let session = Session(client: httpClient, id: "test-session-id", platform: .android)
        let mockClient = MockAppium()
        
        // Test successful case
        try await mockClient.hideKeyboard(session)
        
        // Test error case
        mockClient.setMockError(
            for: "hideKeyboard",
            error: AppiumError.invalidResponse("Failed to hide keyboard")
        )
        
        do {
            try await mockClient.hideKeyboard(session)
            throw TestError.expectedError
        } catch AppiumError.invalidResponse {
            // Expected error
        }
        
        try? await httpClient.shutdown()
    }
    
    @Test("Click element")
    func clickElement() async throws {
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        let session = Session(client: httpClient, id: "test-session-id", platform: .android)
        let element: Element! = Element(.id, .init("clickable-button"))
        let elementError: Element! = Element(.id, .init("error-button"))
        let mockClient = MockAppium()
        
        // Test successful case
        mockClient.setMockResponse(
            for: "clickElement_id_clickable-button",
            response: true
        )
        
        try await mockClient.clickElement(
            session,
            element,
            5
        )
        
        // Test error case
        mockClient.setMockError(
            for: "clickElement_id_error-button",
            error: AppiumError.elementNotFound("Button not found")
        )
        
        do {
            try await mockClient.clickElement(
                session,
                elementError,
                5
            )
            throw TestError.expectedError
        } catch AppiumError.elementNotFound {
            // Expected error
        }
        
        try? await httpClient.shutdown()
    }
    
    @Test("Click unsafe element")
    func clickUnsafeElement() async throws {
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        let session = Session(client: httpClient, id: "test-session-id", platform: .android)
        let element: Element! = Element(.id, .init("clickable-button"))
        let elementError: Element! = Element(.id, .init("error-button"))
        let mockClient = MockAppium()
        
        // Test successful case
        mockClient.setMockResponse(
            for: "clickElement_id_clickable-button",
            response: true
        )
        
        try await mockClient.clickUnsafeElement(
            session,
            element,
            5
        )
       
        do {
            try await mockClient.clickUnsafeElement(
                session,
                elementError,
                5
            )
        } catch AppiumError.elementNotFound {
            throw TestError.expectedError
        }
        
        try? await httpClient.shutdown()
    }
    
    @Test("Send keys")
    func sendKeys() async throws {
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        let session = Session(client: httpClient, id: "test-session-id", platform: .android)
        let element: Element! = Element(.id, .init("text-input"))
        let elementError: Element! = Element(.id, .init("error-input"))
        let mockClient = MockAppium()
        
        // Test successful case
        mockClient.setMockResponse(
            for: "sendKeys_id_text-input_Hello, World!",
            response: true
        )
        
        try await mockClient.sendKeys(
            session,
            element,
            text: "Hello, World!"
        )
        
        // Test error case
        mockClient.setMockError(
            for: "sendKeys_id_error-input_Test",
            error: AppiumError.elementNotFound("Input not found")
        )
        
        do {
            try await mockClient.sendKeys(
                session,
                elementError,
                text: "Test"
            )
            throw TestError.expectedError
        } catch AppiumError.elementNotFound {
            // Expected error
        }
        
        try? await httpClient.shutdown()
    }
} 
