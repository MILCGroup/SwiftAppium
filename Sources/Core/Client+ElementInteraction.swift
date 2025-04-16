//
//  Client+ElementInteraction.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import Foundation
import AsyncHTTPClient
import Testing

extension Client {
    public static func clickElement(
        _ session: Session,
        _ element: Element,
        _ wait: TimeInterval = 5
    ) async throws {
        let elementId = try await waitForElement(
            session, element, timeout: wait)

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
        } catch {
            try await session.client.shutdown()
            try #require(Bool(false), "Unable to click element: \(element.selector.wrappedValue)")
        }
    }
    
    public static func clickUnsafeElement(
        _ session: Session,
        _ element: Element,
        _ wait: TimeInterval = 5
    ) async throws
    {
        let elementId = try await waitForElement(
            session, element, timeout: wait)

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
        } catch {
            throw AppiumError.invalidResponse("Failed to click element: \(error)")
        }
    }
    
    public static func sendKeys(
        _ session: Session,
        _ element: Element,
        text: String
    ) async throws {
        let elementId: String
        do {
            elementId = try await Client.waitForElement(
                session, element, timeout: 3)
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
