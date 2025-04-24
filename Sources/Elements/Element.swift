//
//  Element.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import Foundation
import Testing
import AsyncHTTPClient

//public struct ElementID: Sendable {
//    public let id: String
//}


public struct Element: Sendable {
    public let strategy: Strategy
    public let selector: Selector
    
    public init(_ strategy: Strategy,_ selector: Selector) {
        self.strategy = strategy
        self.selector = selector
    }
    
    public func isVisible(
        _ session: Session,
    ) async throws -> Bool {
        appiumLogger.info(
            "Checking visibility of element with strategy: \(strategy.rawValue) and selector: \(selector.wrappedValue) in session: \(session.id)"
        )
        
        let elementId: String
        do {
            elementId = try await session.select(self, 3)
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
    
    public func isChecked(
        _ session: Session,
    ) async throws -> Bool {
        appiumLogger.info(
            "Checking visibility of element with strategy: \(strategy.rawValue) and selector: \(selector.wrappedValue) in session: \(session.id)"
        )

        let elementId: String
        do {
            elementId = try await session.select(self, 3)
        } catch {
            appiumLogger.error("Failed to find element: \(error)")
            throw error
        }

        let request = try HTTPClient.Request(
            url: API.displayed(elementId, session.id).path,
            method: .GET
        )

        appiumLogger.info("Sending request to URL: \(request.url)")
        
        let response: HTTPClient.Response
        do {
            response = try await session.client.execute(request: request).get()
        } catch {
            appiumLogger.error("Failed to execute request: \(error)")
            throw error
        }

        guard response.status == .ok else {
            appiumLogger.error("Failed to check element visibility: HTTP \(response.status)")
            throw AppiumError.invalidResponse(
                "Failed to check element visibility: HTTP \(response.status)"
            )
        }

        guard let responseData = response.body else {
            appiumLogger.error("No response body")
            throw AppiumError.invalidResponse(
                "No response data received when checking element visibility."
            )
        }

        if let responseString = responseData.getString(
            at: 0,
            length: responseData.readableBytes
        ) {
            appiumLogger.info("Raw response data: \(responseString)")
        }

        do {
            let checkedResponse = try JSONDecoder().decode(
                CheckedResponse.self,
                from: responseData
            )
            return checkedResponse.value
        } catch {
            appiumLogger.error(
                "Failed to decode visibility response: \(error.localizedDescription)"
            )
            throw AppiumError.invalidResponse(
                "Failed to decode visibility response: \(error.localizedDescription)"
            )
        }
    }
}
