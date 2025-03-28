import Testing
@testable import SwiftAppium
import AsyncHTTPClient

enum TestError: Error {
    case expectedError
}

@Suite("AppiumClientModel Tests")
struct AppiumClientModelTests {
    private var session: Session?
    private var client: AppiumClientModel?
    private var mockClient: MockAppiumClient?
    private var httpClient: HTTPClient?
    
    @Test("Setup and teardown")
    func setupAndTeardown() async throws {
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        let session = Session(client: httpClient, id: "test-session-id", platform: .android)
        let client = AppiumClientModel(session: session)
        let mockClient = MockAppiumClient()
        mockClient.clearMocks()
        
        #expect(session != nil)
        #expect(client != nil)
        #expect(mockClient != nil)
        
        try? await httpClient.shutdown()
    }
    
    @Test("Wait for element")
    func waitForElement() async throws {
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        let session = Session(client: httpClient, id: "test-session-id", platform: .android)
        let mockClient = MockAppiumClient()
        
        // Test successful case
        mockClient.setMockResponse(
            for: "waitForElement_id_test-button",
            response: "element-123"
        )
        
        let elementId = try await mockClient.waitForElement(
            session,
            strategy: .id,
            selector: "test-button",
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
                strategy: .id,
                selector: "timeout-button",
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
        let mockClient = MockAppiumClient()
        
        // Test successful case
        mockClient.setMockResponse(
            for: "findElement_id_test-input",
            response: "input-123"
        )
        
        let elementId = try await mockClient.findElement(
            session,
            strategy: .id,
            selector: "test-input"
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
                strategy: .id,
                selector: "non-existent"
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
        let mockClient = MockAppiumClient()
        
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
    
    @Test("Check element visibility")
    func checkElementVisibility() async throws {
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        let session = Session(client: httpClient, id: "test-session-id", platform: .android)
        let mockClient = MockAppiumClient()
        
        // Test visible case
        mockClient.setMockResponse(
            for: "checkElementVisibility_id_visible-element",
            response: true
        )
        
        let isVisible = try await mockClient.checkElementVisibility(
            session,
            strategy: .id,
            selector: "visible-element"
        )
        #expect(isVisible)
        
        // Test hidden case
        mockClient.setMockResponse(
            for: "checkElementVisibility_id_hidden-element",
            response: false
        )
        
        let isHidden = try await mockClient.checkElementVisibility(
            session,
            strategy: .id,
            selector: "hidden-element"
        )
        #expect(!isHidden)
        
        try? await httpClient.shutdown()
    }
    
    @Test("Execute script")
    func executeScript() async throws {
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        let session = Session(client: httpClient, id: "test-session-id", platform: .android)
        let mockClient = MockAppiumClient()
        
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
        let mockClient = MockAppiumClient()
        
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
        let mockClient = MockAppiumClient()
        
        // Test successful case
        mockClient.setMockResponse(
            for: "clickElement_id_clickable-button",
            response: true
        )
        
        try await mockClient.clickElement(
            session,
            strategy: .id,
            selector: "clickable-button",
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
                strategy: .id,
                selector: "error-button",
                5
            )
            throw TestError.expectedError
        } catch AppiumError.elementNotFound {
            // Expected error
        }
        
        try? await httpClient.shutdown()
    }
    
    @Test("Send keys")
    func sendKeys() async throws {
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        let session = Session(client: httpClient, id: "test-session-id", platform: .android)
        let mockClient = MockAppiumClient()
        
        // Test successful case
        mockClient.setMockResponse(
            for: "sendKeys_id_text-input_Hello, World!",
            response: true
        )
        
        try await mockClient.sendKeys(
            session,
            strategy: .id,
            selector: "text-input",
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
                strategy: .id,
                selector: "error-input",
                text: "Test"
            )
            throw TestError.expectedError
        } catch AppiumError.elementNotFound {
            // Expected error
        }
        
        try? await httpClient.shutdown()
    }
} 
