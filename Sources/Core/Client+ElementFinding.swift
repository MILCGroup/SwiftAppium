//
//  Client+ElementFinding.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import Foundation
import AsyncHTTPClient
import Testing

extension Client {
    public static func waitForElement(
        _ session: Session,
        _ element: Element,
        timeout: TimeInterval
    ) async throws -> String {
        let startTime = Date()
        
        while true {
            do {
                let elementFound = try await findElement(
                    session,
                    element
                )
                
                if let elementF = elementFound {
                    appiumLogger.info("Element \(elementF) found!")
                    return elementF
                }
            } catch AppiumError.elementNotFound {
                if Date().timeIntervalSince(startTime) > timeout {
                    try await session.client.shutdown()
                    try #require(Bool(false), "Timeout reached while waiting for element with selector: \(element.selector.wrappedValue)")
                    throw AppiumError.timeoutError(
                        "Timeout reached while waiting for element with selector: \(element.selector.wrappedValue)"
                    )
                }
            } catch {
                throw error
            }
        }
    }
   
    public static func findElement(
        _ session: Session,
        _ element: Element
    ) async throws -> String? {
        let requestBody: Data
        do {
            requestBody = try JSONEncoder().encode([
                "using": element.strategy.rawValue,
                "value": element.selector.wrappedValue,
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
                "Failed to find element: \(element.selector.wrappedValue)")
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
}
