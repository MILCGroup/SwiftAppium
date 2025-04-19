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
    
    public static func select(
        _ session: Session,
        _ element: Self,
        timeout: TimeInterval
    ) async throws -> String {
        let startTime = Date()
        
        while true {
            do {
                let elementFound = try await selectUnsafe(
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
   
    public static func selectUnsafe(
        _ session: Session,
        _ element: Self
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
    
    public static func value(
         _ session: Session,
         _ element: Self
    ) async throws -> Double {
        appiumLogger.info(
            "Checking value of element with strategy: \(element.strategy.rawValue) and selector: \(element.selector.wrappedValue) in session: \(session.id)"
        )
        
        let elementId: String
        do {
            elementId = try await select(
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
     
    public static func isVisible(
        _ session: Session,
        _ element: Self
    ) async throws -> Bool {
        appiumLogger.info(
            "Checking visibility of element with strategy: \(element.strategy.rawValue) and selector: \(element.selector.wrappedValue) in session: \(session.id)"
        )
        
        let elementId: String
        do {
            elementId = try await Element.select(
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
    
    public static func click(
        _ session: Session,
        _ element: Self,
        _ wait: TimeInterval = 5
    ) async throws {
        let elementId = try await select(
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
    
    public static func clickUnsafe(
        _ session: Session,
        _ element: Self,
        _ wait: TimeInterval = 5
    ) async throws
    {
        let elementId = try await select(
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
    
    public static func type(
        _ session: Session,
        _ element: Self,
        text: String
    ) async throws {
        let elementId: String
        do {
            elementId = try await select(
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

    public static func isChecked(
        _ session: Session,
        _ element: Self
    ) async throws -> Bool {
        appiumLogger.info(
            "Checking visibility of element with strategy: \(element.strategy.rawValue) and selector: \(element.selector.wrappedValue) in session: \(session.id)"
        )

        let elementId: String
        do {
            elementId = try await select(
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
    
    public func select(
        _ session: Session,
        _ timeout: TimeInterval = 3
    ) async throws -> String {
        let startTime = Date()
        
        while true {
            do {
                let elementFound = try await selectUnsafe(
                    session
                )
                
                if let elementF = elementFound {
                    appiumLogger.info("Element \(elementF) found!")
                    return elementF
                }
            } catch AppiumError.elementNotFound {
                if Date().timeIntervalSince(startTime) > timeout {
                    try await session.client.shutdown()
                    try #require(Bool(false), "Timeout reached while waiting for element with selector: \(self.selector.wrappedValue)")
                    throw AppiumError.timeoutError(
                        "Timeout reached while waiting for element with selector: \(self.selector.wrappedValue)"
                    )
                }
            } catch {
                throw error
            }
        }
    }
   
    public func selectUnsafe(
        _ session: Session
    ) async throws -> String? {
        let requestBody: Data
        do {
            requestBody = try JSONEncoder().encode([
                "using": self.strategy.rawValue,
                "value": self.selector.wrappedValue,
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
                "Failed to find element: \(self.selector.wrappedValue)")
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
    
    public func value(
         _ session: Session
    ) async throws -> Double {
        appiumLogger.info(
            "Checking value of element with strategy: \(self.strategy.rawValue) and selector: \(self.selector.wrappedValue) in session: \(session.id)"
        )
        
        let elementId: String
        do {
            elementId = try await select(
                session, 35)
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
     
    public func isVisibility(
        _ session: Session
    ) async throws -> Bool {
        appiumLogger.info(
            "Checking visibility of element with strategy: \(self.strategy.rawValue) and selector: \(self.selector.wrappedValue) in session: \(session.id)"
        )
        
        let elementId: String
        do {
            elementId = try await select(
                session)
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
    
    public func click(
        _ session: Session,
        _ wait: TimeInterval = 5
    ) async throws {
        let elementId = try await select(
            session, wait)

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
            try #require(Bool(false), "Unable to click element: \(self.selector.wrappedValue)")
        }
    }
    
    public func clickUnsafe(
        _ session: Session,
        _ wait: TimeInterval = 5
    ) async throws
    {
        let elementId = try await select(
            session, wait)

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
    
    public func type(
        _ session: Session,
        text: String
    ) async throws {
        let elementId: String
        do {
            elementId = try await select(
                session)
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

    public func isChecked(
        _ session: Session
    ) async throws -> Bool {
        appiumLogger.info(
            "Checking visibility of element with strategy: \(self.strategy.rawValue) and selector: \(self.selector.wrappedValue) in session: \(session.id)"
        )

        let elementId: String
        do {
            elementId = try await select(session)
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
