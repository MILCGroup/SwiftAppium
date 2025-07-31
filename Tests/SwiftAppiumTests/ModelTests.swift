import Testing
@testable import SwiftAppium

@Suite
struct ModelTests {
    let session: Session = Session(client: MockAppium(), platform: "iOS", automationName: "XCUITest")
    
    @Test
    func testElementInitializer() {
        let selector = "test-selector"
        let element: Element? = Element(.id, selector)
        #expect(element != nil)
        #expect(element?.strategy == .id)
        #expect(element?.selector.wrappedValue == selector)
    }
    /*
    @Test
    func testWaitForElement() async throws {
        let selector = "test-button"
        let element: Element? = Element(.id, selector)
        let elementTimedOut: Element? = Element(.id, "timeout-button")
        let mockClient: MockAppium! = MockAppium()
        mockClient.clearMocks()
        
        #expect(session != nil)
        
        // Test successful case
        mockClient.setMockResponse(
            for: "waitForElement_id_test-button",
            response: "element-123"
        )
        
        let elementId = try await mockClient.waitForElement(
            session,
            element,
            timeout: 5.0
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
                timeout: 1.0
            )
            throw TestError.expectedError
        } catch AppiumError.timeoutError {
            // Expected error
        } catch {
            throw TestError.unexpectedError
        }
    }
    
    @Test
    func testFindElement() async throws {
        let selector = "test-input"
        let element: Element? = Element(.id, selector)
        let elementNonExistent: Element? = Element(.id, "non-existent")
        let mockClient: MockAppium! = MockAppium()
        
        #expect(session != nil)
        
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
        } catch {
            throw TestError.unexpectedError
        }
    }
    
    @Test
    func testContainsInHierarchy() async throws {
        let mockClient: MockAppium! = MockAppium()
        
        // Test successful case
        mockClient.setMockResponse(
            for: "containsInHierarchy_Test Text",
            response: true
        )
        
        let contains = try await mockClient.containsInHierarchy(
            session,
            contains: "Test Text"
        )
        #expect(contains == true)
        
        // Test not found case
        mockClient.setMockResponse(
            for: "containsInHierarchy_Missing Text",
            response: false
        )
        
        let notContains = try await mockClient.containsInHierarchy(
            session,
            contains: "Missing Text"
        )
        #expect(notContains == false)
    }
    
    @Test
    func testContainsMultipleInHierarchy() async throws {
        let mockClient: MockAppium! = MockAppium()
        
        // Test successful case
        mockClient.setMockResponse(
            for: "containsMultipleInHierarchy_Test Text",
            response: true
        )
        
        let contains = try await mockClient.containsMultipleInHierarchy(
            session,
            contains: 1, "Test Text"
        )
        #expect(contains == true)
        
        // Test not found case
        mockClient.setMockResponse(
            for: "containsInHierarchy_Missing Text",
            response: false
        )
        
        let notContains = try await mockClient.containsMultipleInHierarchy(
            session,
            contains: 1, "Missing Text"
        )
        #expect(notContains == false)
    }
    
    @Test
    func testElementValue() async throws {
        let selector = "visible-element"
        let element: Element? = Element(.id, selector)
        let elementHidden: Element? = Element(.id, "hidden-element")
        let mockClient: MockAppium! = MockAppium()
        
        #expect(session != nil)
        
        // Test visible case
        mockClient.setMockResponse(
            for: "checkElementValue_id_visible-element",
            response: true
        )
        
        let isVisible = try await mockClient.elementValue(
            session,
            element
        )
        #expect(isVisible == true)
        
        // Test hidden case
        mockClient.setMockResponse(
            for: "checkElementValue_id_hidden-element",
            response: false
        )
        
        let isHidden = try await mockClient.elementValue(
            session,
            elementHidden
        )
        #expect(isHidden == false)
    }
    
    @Test
    func testCheckElementVisibility() async throws {
        let selector = "visible-element"
        let element: Element? = Element(.id, selector)
        let elementHidden: Element? = Element(.id, "hidden-element")
        let mockClient: MockAppium! = MockAppium()
        
        #expect(session != nil)
        
        // Test visible case
        mockClient.setMockResponse(
            for: "checkElementVisibility_id_visible-element",
            response: true
        )
        
        let isVisible = try await mockClient.checkElementVisibility(
            session,
            element
        )
        #expect(isVisible == true)
        
        // Test hidden case
        mockClient.setMockResponse(
            for: "checkElementVisibility_id_hidden-element",
            response: false
        )
        
        let isHidden = try await mockClient.checkElementVisibility(
            session,
            elementHidden
        )
        #expect(isHidden == false)
    }
    
    @Test
    func testCheckElementChecked() async throws {
        let selector = "visible-element"
        let element: Element? = Element(.id, selector)
        let elementHidden: Element? = Element(.id, "hidden-element")
        let mockClient: MockAppium! = MockAppium()
        
        #expect(session != nil)
        
        // Test visible case
        mockClient.setMockResponse(
            for: "checkElementChecked_id_visible-element",
            response: true
        )
        
        let isVisible = try await mockClient.checkElementChecked(
            session,
            element
        )
        #expect(isVisible == true)
        
        // Test hidden case
        mockClient.setMockResponse(
            for: "checkElementChecked_id_hidden-element",
            response: false
        )
        
        let isHidden = try await mockClient.checkElementChecked(
            session,
            elementHidden
        )
        #expect(isHidden == false)
    }
    
    @Test
    func testExecuteScript() async throws {
        let mockClient: MockAppium! = MockAppium()
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
        ) as? [String: String]
        
        #expect(result?["status"] == "success")
    }
    
    @Test
    func testHideKeyboard() async throws {
        let mockClient: MockAppium! = MockAppium()
        
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
        } catch {
            throw TestError.unexpectedError
        }
    }
    
    @Test
    func testClickElement() async throws {
        let selector = "clickable-button"
        let element: Element? = Element(.id, selector)
        let elementError: Element? = Element(.id, "error-button")
        let mockClient: MockAppium! = MockAppium()
        
        #expect(session != nil)
        
        // Test successful case
        mockClient.setMockResponse(
            for: "clickElement_id_clickable-button",
            response: true
        )
        
        try await mockClient.clickElement(
            session,
            element,
            wait: 5.0
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
                wait: 1.0
            )
            throw TestError.expectedError
        } catch AppiumError.elementNotFound {
            // Expected error
        } catch {
            throw TestError.unexpectedError
        }
    }
    
    @Test
    func testClickUnsafeElement() async throws {
        let selector = "clickable-button"
        let element: Element? = Element(.id, selector)
        let elementError: Element? = Element(.id, "error-button")
        let mockClient: MockAppium! = MockAppium()
        
        #expect(session != nil)
        
        // Test successful case
        mockClient.setMockResponse(
            for: "clickElement_id_clickable-button",
            response: true
        )
        
        try await mockClient.clickUnsafeElement(
            session,
            element,
            wait: 5.0
        )
       
        do {
            try await mockClient.clickUnsafeElement(
                session,
                elementError,
                wait: 1.0
            )
            throw TestError.expectedError
        } catch AppiumError.elementNotFound {
            // Expected error
        } catch {
            throw TestError.unexpectedError
        }
    }
    
    @Test
    func testSendKeys() async throws {
        let selector = "text-input"
        let element: Element? = Element(.id, selector)
        let elementError: Element? = Element(.id, "error-input")
        let mockClient: MockAppium! = MockAppium()
        
        #expect(session != nil)
        
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
        } catch {
            throw TestError.unexpectedError
        }
    }
}

enum TestError: Error {
    case expectedError
    case unexpectedError
}
*/