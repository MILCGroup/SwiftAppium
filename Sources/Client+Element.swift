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
        _ client: HTTPClient,
        sessionId: String,
        strategy: Strategy,
        selector: String,
        timeout: TimeInterval
    ) async throws -> String {
        let startTime = Date()
        var searchCount = 0
        while true {
            do {
                let elementFound = try await findElement(
                    client: client, sessionId: sessionId, strategy: strategy,
                    selector: selector
                )
                
                if let element = elementFound {
                    appiumLogger.info("Element \(element) found!")
                    return element
                }
            } catch {
                appiumLogger.info(
                    "searched \(searchCount) time\(searchCount == 1 ? "" : "s")"
                )
                searchCount += 1
            }
            
            if Date().timeIntervalSince(startTime) > timeout {
                throw AppiumError.timeoutError(
                    "Timeout reached while waiting for element with selector: \(selector)"
                )
            }
            try await Wait.sleep(for: Wait.searchAgainDelay)
        }
    }
    
    public static func findElement(
        client: HTTPClient,
        sessionId: String,
        strategy: Strategy,
        selector: String
    ) async throws -> String? {
        appiumLogger.info(
            "Trying to find element with strategy: \(strategy.rawValue) and selector: \(selector) in session: \(sessionId)"
        )
        
        let requestBody: Data
        do {
            requestBody = try JSONEncoder().encode([
                "using": strategy.rawValue,
                "value": selector,
            ])
        } catch {
            throw AppiumError.encodingError("Failed to encode request body for findElement")
        }
        
        var request = try HTTPClient.Request(
            url: API.element(sessionId).path, method: .POST
        )
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = .data(requestBody)
        
        do {
            appiumLogger.info("Sending request to URL: \(request.url)")
            let response = try await client.execute(request: request).get()
            appiumLogger.info("Received response with status: \(response.status)")
            
            guard response.status == .ok else {
                throw AppiumError.invalidResponse("Failed to find element: HTTP \(response.status)")
            }
            
            guard var byteBuffer = response.body else {
                throw AppiumError.invalidResponse("No response body")
            }
            
            guard let body = byteBuffer.readString(length: byteBuffer.readableBytes) else {
                throw AppiumError.invalidResponse("Cannot read response body")
            }
            
            appiumLogger.info("Element response body: \(body)")
            
            do {
                let elementResponse = try JSONDecoder().decode(
                    ElementResponse.self, from: Data(body.utf8))
                return elementResponse.value.elementId
            } catch {
                throw AppiumError.invalidResponse("Failed to decode element response: \(error.localizedDescription)")
            }
        } catch let error as AppiumError {
            throw error
        } catch {
            throw AppiumError.elementNotFound(
                "Failed to find element with strategy: \(strategy.rawValue) and selector: \(selector) - \(error.localizedDescription)"
            )
        }
    }
    
    public static func containsInHierarchy(
        _ client: HTTPClient,
        sessionId: String,
        contains text: String
    ) async throws -> Bool {
        do {
            let request = try HTTPClient.Request(
                url: API.source(sessionId).path, method: .GET)
            let response = try await client.execute(request: request).get()
            
            guard response.status == .ok else {
                throw AppiumError.invalidResponse("Failed to get hierarchy: HTTP \(response.status)")
            }
            
            guard let body = response.body,
                  let hierarchy = body.getString(at: 0, length: body.readableBytes)
            else {
                throw AppiumError.invalidResponse("Failed to get element hierarchy content")
            }
            
            try await Wait.sleep(for: 1)
            return hierarchy.contains(text)
            
        } catch let error as AppiumError {
            appiumLogger.error("Error while checking hierarchy: \(error)")
            throw error
        } catch {
            appiumLogger.error("Unexpected error while checking hierarchy: \(error)")
            throw AppiumError.invalidResponse("Failed to check hierarchy: \(error.localizedDescription)")
        }
    }
}

extension Client {
    public static func waitAndClickElement(
        _ client: HTTPClient,
        _ sessionId: String,
        strategy: Strategy,
        selector: String,
        timeout: Int = 2
    ) async throws {
        let elementId = try await waitForElement(
            client,
            sessionId: sessionId,
            strategy: strategy,
            selector: selector,
            timeout: TimeInterval(timeout)
        )

        try await clickElement(
            client: client,
            sessionId: sessionId,
            elementId: elementId
        )
        webLogger.info(
            "Found and clicked element with selector: \(selector)")
    }

    public static func clickElement(
        client: HTTPClient,
        sessionId: String,
        elementId: String
    ) async throws {
        appiumLogger.info(
            "Clicking element: \(elementId) in session: \(sessionId)")
        var request = try HTTPClient.Request(
            url: API.click(elementId, sessionId).path,
            method: .POST)
        request.headers.add(name: "Content-Type", value: "application/json")
        
        do {
            let response = try await client.execute(request: request).get()
            guard response.status == .ok else {
                throw AppiumError.invalidResponse("Failed to click element: HTTP \(response.status)")
            }
        } catch let error as AppiumError {
            throw error
        } catch {
            throw AppiumError.elementNotFound("Failed to click element: \(elementId) - \(error.localizedDescription)")
        }
    }

    public static func sendKeys(
        client: HTTPClient,
        sessionId: String,
        elementId: String,
        text: String
    ) async throws {
        appiumLogger.info(
            "Sending keys to element: \(elementId) in session: \(sessionId) with text: \(text)"
        )
        
        let requestBody: Data
        do {
            requestBody = try JSONEncoder().encode(["text": text])
        } catch {
            throw AppiumError.encodingError("Failed to encode text for sendKeys")
        }
        
        var request = try HTTPClient.Request(
            url: API.value(elementId, sessionId).path,
            method: .POST)
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = .data(requestBody)
        
        do {
            let response = try await client.execute(request: request).get()
            guard response.status == .ok else {
                throw AppiumError.invalidResponse("Failed to send keys: HTTP \(response.status)")
            }
        } catch let error as AppiumError {
            throw error
        } catch {
            throw AppiumError.elementNotFound("Failed to send keys to element: \(elementId) - \(error.localizedDescription)")
        }
    }
}
