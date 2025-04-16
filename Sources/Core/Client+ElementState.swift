//
//  Client+ElementState.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import Foundation
import AsyncHTTPClient

extension Client {
    public static func elementValue(
         _ session: Session,
         _ element: Element
    ) async throws -> Double {
        appiumLogger.info(
            "Checking value of element with strategy: \(element.strategy.rawValue) and selector: \(element.selector.wrappedValue) in session: \(session.id)"
        )
        
        let elementId: String
        do {
            elementId = try await Client.waitForElement(
                session, element, timeout: 35)
        } catch {
            appiumLogger.error("Failed to find element: \(error)")
            throw error
        }
        
        let request: HTTPClient.Request
        do {
            request = try HTTPClient.Request(
                url: API.attributeValue(elementId, session.id).path,
                method: .GET
            )
        } catch {
            appiumLogger.error("Failed to create request: \(error)")
            throw AppiumError.invalidResponse(
                "Failed to create request: \(error.localizedDescription)"
            )
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
                "Failed to check element value: HTTP \(response.status)"
            )
            throw AppiumError.invalidResponse(
                "Failed to check element value: HTTP \(response.status)"
            )
        }
        
        guard let responseData = response.body else {
            appiumLogger.error("No response body")
            throw AppiumError.invalidResponse(
                "No response data received when checking element value."
            )
        }
        
        if let responseString = responseData.getString(
            at: 0, length: responseData.readableBytes
        ) {
            appiumLogger.info("Raw response data: \(responseString)")
        } else {
            appiumLogger.error("Failed to read response data as string")
        }
        
        do {
            let valueResponse = try JSONDecoder().decode(
                ValueResponse.self, from: responseData
            )
            let valueString = valueResponse.value
            let numericString = valueString.trimmingCharacters(in: CharacterSet(charactersIn: "0123456789.-").inverted)
            guard var doubleValue = Double(numericString) else {
                appiumLogger.error("Failed to convert value to Double")
                throw AppiumError.invalidResponse(
                    "Failed to convert value to Double"
                )
            }
            if valueString.contains("%") {
                doubleValue /= 100
            }
            if valueString.contains(".") {
                let decimalPart = valueString.split(separator: ".")[1].trimmingCharacters(in: CharacterSet(charactersIn: "0123456789.-").inverted)
                if decimalPart.count == 2 {
                    return doubleValue + 0.01 // Carry two decimals into Tests
                }
            }
            return doubleValue
        } catch {
            appiumLogger.error(
                "Failed to decode value response: \(error.localizedDescription)"
            )
            throw AppiumError.invalidResponse(
                "Failed to decode value response: \(error.localizedDescription)"
            )
        }
    }
     
    public static func checkElementVisibility(
        _ session: Session,
        _ element: Element
    ) async throws -> Bool {
        appiumLogger.info(
            "Checking visibility of element with strategy: \(element.strategy.rawValue) and selector: \(element.selector.wrappedValue) in session: \(session.id)"
        )
        
        let elementId: String
        do {
            elementId = try await Client.waitForElement(
                session, element, timeout: 3)
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

    public static func checkElementChecked(
        _ session: Session,
        _ element: Element
    ) async throws -> Bool {
        appiumLogger.info(
            "Checking visibility of element with strategy: \(element.strategy.rawValue) and selector: \(element.selector.wrappedValue) in session: \(session.id)"
        )

        let elementId: String
        do {
            elementId = try await Client.waitForElement(
                session,
                element,
                timeout: 3
            )
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
