//
//  Client+Element.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import AsyncHTTPClient
import Foundation

public struct Client {
    public static func waitForElement(
        _ session: Session,
        strategy: Strategy,
        selector: String,
        timeout: TimeInterval
    ) async throws -> String {
        let startTime = Date()

        while true {
            do {
                let elementFound = try await findElement(
                    session,
                    strategy: strategy,
                    selector: selector
                )

                if let element = elementFound {
                    appiumLogger.info("Element \(element) found!")
                    return element
                }
            } catch AppiumError.elementNotFound {
                if Date().timeIntervalSince(startTime) > timeout {
                    try await session.client.shutdown()
                    throw AppiumError.timeoutError(
                        "Timeout reached while waiting for element with selector: \(selector)"
                    )
                }
            } catch {
                throw error
            }
        }
    }

    public static func findElement(
        _ session: Session,
        strategy: Strategy,
        selector: String
    ) async throws -> String? {
        let requestBody: Data
        do {
            requestBody = try JSONEncoder().encode([
                "using": strategy.rawValue,
                "value": selector,
            ])
        } catch {
            appiumLogger.error(
                "Failed to encode request body for findElement: \(error)")
            throw AppiumError.encodingError(
                "Failed to encode findElement request: \(error.localizedDescription)"
            )
        }

        var request: HTTPClient.Request
        do {
            request = try HTTPClient.Request(
                url: API.element(session.id).path, method: .POST
            )
        } catch {
            appiumLogger.error("Failed to create request: \(error)")
            throw AppiumError.invalidResponse(
                "Failed to create request: \(error.localizedDescription)")
        }
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = .data(requestBody)

        let response: HTTPClient.Response
        do {
            response = try await session.client.execute(request: request).get()
        } catch {
            appiumLogger.error("Failed to execute request: \(error)")
            return nil
        }

        guard response.status == .ok else {
            throw AppiumError.elementNotFound(
                "Failed to find element: \(selector)")
        }

        guard var byteBuffer = response.body else {
            appiumLogger.error("No response body")
            return nil
        }

        guard let body = byteBuffer.readString(length: byteBuffer.readableBytes)
        else {
            appiumLogger.error("Cannot read response body")
            return nil
        }

        do {
            let elementResponse = try JSONDecoder().decode(
                ElementResponse.self, from: Data(body.utf8))
            return elementResponse.value.elementId
        } catch {
            appiumLogger.error(
                "Failed to decode element response: \(error.localizedDescription)"
            )
            return nil
        }
    }

    public static func containsInHierarchy(
        _ session: Session,
        contains text: String
    ) async throws -> Bool {
        do {
            let request = try HTTPClient.Request(
                url: API.source(session.id).path, method: .GET)
            let response = try await session.client.execute(request: request)
                .get()

            guard response.status == .ok else {
                throw AppiumError.invalidResponse(
                    "Failed to get hierarchy: HTTP \(response.status)")
            }

            guard let body = response.body,
                let hierarchy = body.getString(
                    at: 0, length: body.readableBytes)
            else {
                throw AppiumError.invalidResponse(
                    "Failed to get element hierarchy content")
            }

            try await Wait.sleep(for: 1)
            return hierarchy.contains(text)

        } catch let error as AppiumError {
            appiumLogger.error("Error while checking hierarchy: \(error)")
            throw error
        } catch {
            appiumLogger.error(
                "Unexpected error while checking hierarchy: \(error)")
            throw AppiumError.invalidResponse(
                "Failed to check hierarchy: \(error.localizedDescription)")
        }
    }

    public static func checkElementVisibility(
        _ session: Session,
        strategy: Strategy,
        selector: String
    ) async throws -> Bool {
        appiumLogger.info(
            "Checking visibility of element with strategy: \(strategy.rawValue) and selector: \(selector) in session: \(session.id)"
        )

        let elementId: String
        do {
            elementId = try await Client.waitForElement(
                session, strategy: strategy, selector: selector, timeout: 3)
        } catch {
            appiumLogger.error("Failed to find element: \(error)")
            throw error
        }

        let request: HTTPClient.Request
        do {
            request = try HTTPClient.Request(
                url:
                    API.displayed(elementId, session.id).path,
                method: .GET
            )
        } catch {
            appiumLogger.error("Failed to create request: \(error)")
            throw AppiumError.invalidResponse(
                "Failed to create request: \(error.localizedDescription)")
        }

        appiumLogger.info("Sending request to URL: \(request.url)")
        let response: HTTPClient.Response
        do {
            response = try await session.client.execute(request: request).get()
        } catch {
            appiumLogger.error("Failed to execute request: \(error)")
            throw error
        }

        appiumLogger.info("Received response with status: \(response.status)")
        guard response.status == .ok else {
            appiumLogger.error(
                "Failed to check element visibility: HTTP \(response.status)")
            throw AppiumError.invalidResponse(
                "Failed to check element visibility: HTTP \(response.status)")
        }

        guard let responseData = response.body else {
            appiumLogger.error("No response body")
            throw AppiumError.invalidResponse(
                "No response data received when checking element visibility.")
        }

        if let responseString = responseData.getString(
            at: 0, length: responseData.readableBytes)
        {
            appiumLogger.info("Raw response data: \(responseString)")
        } else {
            appiumLogger.error("Failed to read response data as string")
        }

        do {
            let visibilityResponse = try JSONDecoder().decode(
                VisibilityResponse.self, from: responseData)
            return visibilityResponse.value
        } catch {
            appiumLogger.error(
                "Failed to decode visibility response: \(error.localizedDescription)"
            )
            throw AppiumError.invalidResponse(
                "Failed to decode visibility response: \(error.localizedDescription)"
            )
        }
    }

    public static func executeScript(
        _ session: Session,
        script: String,
        args: [Any]
    ) async throws -> Any? {
        appiumLogger.info("Executing script in session: \(session.id)")

        let requestBody: [String: Any] = [
            "script": script,
            "args": args,
        ]

        let requestData: Data
        do {
            requestData = try JSONSerialization.data(
                withJSONObject: requestBody, options: [])
        } catch {
            throw AppiumError.encodingError(
                "Failed to encode request body for execute script")
        }

        var request: HTTPClient.Request
        request = try HTTPClient.Request(
            url: API.execute(session.id).path, method: .POST
        )
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = .data(requestData)

        do {
            let response = try await session.client.execute(request: request)
                .get()
            if response.status == .ok {
                appiumLogger.info("Script executed successfully.")
                if let responseData = response.body {
                    let jsonResponse =
                        try JSONSerialization.jsonObject(
                            with: responseData, options: []) as? [String: Any]
                    return jsonResponse?["value"]
                }
            } else {
                appiumLogger.error(
                    "Failed to execute script. Status: \(response.status)")
                throw AppiumError.invalidResponse(
                    "Failed to execute script")
            }
        } catch {
            appiumLogger.error("Error while executing script: \(error)")
            throw AppiumError.invalidResponse(
                "Failed to execute script: \(error.localizedDescription)")
        }
        return nil
    }

    public static func hideKeyboard(
        _ session: Session
    )
        async throws
    {
        appiumLogger.info(
            "Attempting to hide keyboard in session: \(session.id)")

        var request: HTTPClient.Request

        request = try HTTPClient.Request(
            url: API.hideKeyboard(session.id).path, method: .POST
        )

        request.headers.add(name: "Content-Type", value: "application/json")

        do {
            let response = try await session.client.execute(request: request)
                .get()
            if response.status == .ok {
                appiumLogger.info("Keyboard hidden successfully.")
            } else {
                appiumLogger.error(
                    "Failed to hide keyboard. Status: \(response.status)")
                throw AppiumError.invalidResponse(
                    "Failed to hide keyboard. Status: \(response.status)")
            }
        } catch {
            appiumLogger.error("Error while hiding keyboard: \(error)")
            throw AppiumError.elementNotFound(
                "Error while hiding keyboard: \(error)")
        }
    }
}

extension Client {
    public static func clickElement(
        _ session: Session,
        strategy: Strategy,
        selector: String,
        _ wait: TimeInterval = 5
    ) async throws {
        let elementId = try await waitForElement(
            session, strategy: strategy, selector: selector, timeout: wait)

        appiumLogger.info(
            "Clicking element: \(elementId) in session: \(session.id)")
        var request = try HTTPClient.Request(
            url: API.click(elementId, session.id).path,
            method: .POST)
        request.headers.add(name: "Content-Type", value: "application/json")

        do {
            let response = try await session.client.execute(request: request)
                .get()
            guard response.status == .ok else {
                throw AppiumError.invalidResponse(
                    "Failed to click element: HTTP \(response.status)")
            }
        } catch let error as AppiumError {
            throw error
        } catch {
            throw AppiumError.elementNotFound(
                "Failed to click element: \(elementId) - \(error.localizedDescription)"
            )
        }
    }

    public static func sendKeys(
        _ session: Session,
        strategy: Strategy,
        selector: String,
        text: String
    ) async throws {

        let elementId: String
        do {
            elementId = try await Client.waitForElement(
                session, strategy: strategy, selector: selector, timeout: 3)
        } catch {
            appiumLogger.error("Failed to find element: \(error)")
            throw error
        }

        appiumLogger.info(
            "Sending keys to element: \(elementId) in session: \(session.id) with text: \(text)"
        )

        let requestBody: Data
        do {
            requestBody = try JSONEncoder().encode(["text": text])
        } catch {
            throw AppiumError.encodingError(
                "Failed to encode text for sendKeys")
        }

        var request = try HTTPClient.Request(
            url: API.value(elementId, session.id).path,
            method: .POST)
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = .data(requestBody)

        do {
            let response = try await session.client.execute(request: request)
                .get()
            guard response.status == .ok else {
                throw AppiumError.invalidResponse(
                    "Failed to send keys: HTTP \(response.status)")
            }
        } catch let error as AppiumError {
            throw error
        } catch {
            throw AppiumError.elementNotFound(
                "Failed to send keys to element: \(elementId) - \(error.localizedDescription)"
            )
        }
    }
}

public protocol AppiumClient {
    func waitForElement(
        _ session: Session,
        strategy: Strategy,
        selector: String,
        timeout: TimeInterval
    ) async throws -> String
    
    func findElement(
        _ session: Session,
        strategy: Strategy,
        selector: String
    ) async throws -> String?
    
    func containsInHierarchy(
        _ session: Session,
        contains text: String
    ) async throws -> Bool
    
    func checkElementVisibility(
        _ session: Session,
        strategy: Strategy,
        selector: String
    ) async throws -> Bool
    
    func executeScript(
        _ session: Session,
        script: String,
        args: [Any]
    ) async throws -> Any?
    
    func hideKeyboard(
        _ session: Session
    ) async throws
    
    func clickElement(
        _ session: Session,
        strategy: Strategy,
        selector: String,
        _ wait: TimeInterval
    ) async throws
    
    func sendKeys(
        _ session: Session,
        strategy: Strategy,
        selector: String,
        text: String
    ) async throws
}

public class AppiumClientModel: AppiumClient {
    private let session: Session
    
    public init(session: Session) {
        self.session = session
    }
    
    public func waitForElement(
        _ session: Session,
        strategy: Strategy,
        selector: String,
        timeout: TimeInterval
    ) async throws -> String {
        return try await Client.waitForElement(
            session,
            strategy: strategy,
            selector: selector,
            timeout: timeout
        )
    }
    
    public func findElement(
        _ session: Session,
        strategy: Strategy,
        selector: String
    ) async throws -> String? {
        return try await Client.findElement(
            session,
            strategy: strategy,
            selector: selector
        )
    }
    
    public func containsInHierarchy(
        _ session: Session,
        contains text: String
    ) async throws -> Bool {
        return try await Client.containsInHierarchy(
            session,
            contains: text
        )
    }
    
    public func checkElementVisibility(
        _ session: Session,
        strategy: Strategy,
        selector: String
    ) async throws -> Bool {
        return try await Client.checkElementVisibility(
            session,
            strategy: strategy,
            selector: selector
        )
    }
    
    public func executeScript(
        _ session: Session,
        script: String,
        args: [Any]
    ) async throws -> Any? {
        return try await Client.executeScript(
            session,
            script: script,
            args: args
        )
    }
    
    public func hideKeyboard(
        _ session: Session
    ) async throws {
        try await Client.hideKeyboard(session)
    }
    
    public func clickElement(
        _ session: Session,
        strategy: Strategy,
        selector: String,
        _ wait: TimeInterval
    ) async throws {
        try await Client.clickElement(
            session,
            strategy: strategy,
            selector: selector,
            wait
        )
    }
    
    public func sendKeys(
        _ session: Session,
        strategy: Strategy,
        selector: String,
        text: String
    ) async throws {
        try await Client.sendKeys(
            session,
            strategy: strategy,
            selector: selector,
            text: text
        )
    }
    
    // Convenience methods that use the stored session
    public func waitForElement(
        strategy: Strategy,
        selector: String,
        timeout: TimeInterval
    ) async throws -> String {
        return try await waitForElement(
            session,
            strategy: strategy,
            selector: selector,
            timeout: timeout
        )
    }
    
    public func findElement(
        strategy: Strategy,
        selector: String
    ) async throws -> String? {
        return try await findElement(
            session,
            strategy: strategy,
            selector: selector
        )
    }
    
    public func containsInHierarchy(
        contains text: String
    ) async throws -> Bool {
        return try await containsInHierarchy(
            session,
            contains: text
        )
    }
    
    public func checkElementVisibility(
        strategy: Strategy,
        selector: String
    ) async throws -> Bool {
        return try await checkElementVisibility(
            session,
            strategy: strategy,
            selector: selector
        )
    }
    
    public func executeScript(
        script: String,
        args: [Any]
    ) async throws -> Any? {
        return try await executeScript(
            session,
            script: script,
            args: args
        )
    }
    
    public func hideKeyboard() async throws {
        try await hideKeyboard(session)
    }
    
    public func clickElement(
        strategy: Strategy,
        selector: String,
        _ wait: TimeInterval = 5
    ) async throws {
        try await clickElement(
            session,
            strategy: strategy,
            selector: selector,
            wait
        )
    }
    
    public func sendKeys(
        strategy: Strategy,
        selector: String,
        text: String
    ) async throws {
        try await sendKeys(
            session,
            strategy: strategy,
            selector: selector,
            text: text
        )
    }
}
