//
//  Session.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//
import Foundation
import AsyncHTTPClient

public struct Session: Sendable {
    public let client: HTTPClient
    public let id: String
    public let platform: Platform
    public let deviceName: String
    
    public var elements: [String: Element] = [:]
    
    public init(client: HTTPClient, id: String, platform: Platform) {
        self.client = client
        self.id = id
        self.platform = platform
        self.deviceName = ""
    }

    public init(
        client: HTTPClient, id: String, driver: Driver, deviceName: String?
    ) {
        self.client = client
        self.id = id
        self.platform = driver.platform
        self.deviceName = driver.deviceName ?? ""
    }
    
    public static func executeScript(
        _ session: Self,
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
            url: API.execute(session.id), method: .POST
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

    public static func hideKeyboard(_ session: Self) async throws {
        appiumLogger.info(
            "Attempting to hide keyboard in session: \(session.id)")
        
        var request: HTTPClient.Request
        
        request = try HTTPClient.Request(
            url: API.hideKeyboard(session.id), method: .POST
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
    
    public func click(
        _ element: Element,
        _ wait: TimeInterval = 5,
        file: String = #file,
        line: UInt = #line,
        function: StaticString = #function,
        andWaitFor: Element? = nil,
        date: Date = Date()
    ) async throws {
        let fileId = "\(function) in \(file):\(line)"
        let elementId = try await select(element, wait, file: file, line: line, function: function)
        
        var request = try HTTPClient.Request(
            url: API.click(elementId, id),
            method: .POST)
        request.headers.add(name: "Content-Type", value: "application/json")
        
        do {
            let response = try await client.execute(request: request)
                .get()
            switch response.status {
            case .ok:
                break
            case .badRequest:
                print("\(fileId) -- Failed to click element \(elementId): HTTP \(response.status)")
                try await Wait.sleep(for: 1)
                if Date().timeIntervalSince(date) < wait {
                    try await click(element, date: date)
                } else {
                    throw AppiumError.timeoutError("Timed out waiting to click element \(elementId)")
                }
            default:
                throw AppiumError.invalidResponse(
                    "\(fileId) -- Failed to click element \(elementId): HTTP \(response.status)")
                
            }
        } catch {
            // Try one more time
            appiumLogger.info(
                "Retrying click on element: \(element.selector.wrappedValue) in session: \(id)")
            let response = try await client.execute(request: request)
                .get()
            guard response.status == .ok else {
                appiumLogger.debug("\(fileId) -- Retry Failed to click element \(element.selector.wrappedValue): HTTP \(response.status)")
                throw AppiumError.invalidResponse(
                    "\(fileId) -- Failed to click element \(element.selector.wrappedValue): HTTP \(response.status)")
            }
        }
    }
    
    public func type(
        _ element: Element,
        text: String,
        file: String = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) async throws {
        let fileId = "\(function) in \(file):\(line)"
        let elementId: String
        do {
            elementId = try await select(
                element, file: file, line: line, function: function)
        } catch {
            appiumLogger.error("\(fileId) -- Failed to find element: \(error)")
            throw error
        }
        
        let requestBody: Data
        do {
            requestBody = try JSONEncoder().encode(["text": text])
        } catch {
            throw AppiumError.encodingError(
                "\(fileId) -- Failed to encode text for sendKeys")
        }
        
        var request = try HTTPClient.Request(
            url: API.value(elementId, id),
            method: .POST)
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = .data(requestBody)
        
        do {
            let response = try await client.execute(request: request)
                .get()
            guard response.status == .ok else {
                throw AppiumError.invalidResponse(
                    "\(fileId) -- Failed to send keys: HTTP \(response.status)")
            }
        } catch let error as AppiumError {
            throw error
        } catch {
            throw AppiumError.elementNotFound(
                "\(fileId) -- Failed to send keys to element: \(elementId) - \(error.localizedDescription)"
            )
        }
    }
    public func select(
        _ element: Element,
        _ timeout: TimeInterval = 5,
        file: String = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) async throws -> String {
        let fileId = "\(function) in \(file):\(line)"
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            do {
                let elementF = try await selectUnsafe(element)
                return elementF
            } catch {
            }
        }
        
        appiumLogger.debug("\(fileId) -- Timeout reached while waiting for element with selector: \(element.selector.wrappedValue)")
        throw AppiumError.timeoutError(
            "\(fileId) -- Timeout reached while waiting for element with selector: \(element.selector.wrappedValue)"
        )
    }
    
    private func selectUnsafe(
        _ element: Element
    ) async throws -> String {
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
                url: API.element(id), method: .POST
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
            response = try await client.execute(request: request).get()
        } catch {
            appiumLogger.error("Failed to execute request: \(error)")
            throw error
        }
        
        guard response.status == .ok else {
            throw AppiumError.elementNotFound(
                "Failed to find element: \(element.selector.wrappedValue)")
        }
        
        guard var byteBuffer = response.body else {
            appiumLogger.error("No response body")
            throw AppiumError.elementNotFound(
                "No response body: \(element.selector.wrappedValue)")
        }
        
        guard let body = byteBuffer.readString(length: byteBuffer.readableBytes)
        else {
            appiumLogger.error("Cannot read response body")
            throw AppiumError.elementNotFound("Cannot read response body")
        }
        
        do {
            let elementResponse = try JSONDecoder().decode(
                ElementResponse.self, from: Data(body.utf8))
            return elementResponse.value.elementId
        } catch {
            appiumLogger.error(
                "Failed to decode element response: \(error.localizedDescription)"
            )
            throw AppiumError.elementNotFound("Failed to decode element response: \(error.localizedDescription)")
        }
    }
    
    public func hierarchyContains(
        _ text: String,
        timeout: TimeInterval = 5
    ) async throws -> Bool {
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            do {
                let request = try HTTPClient.Request(
                    url: API.source(id),
                    method: .GET
                )
                let response = try await client.execute(request: request)
                    .get()
                
                guard response.status == .ok else {
                    throw AppiumError.invalidResponse(
                        "Failed to get hierarchy: HTTP \(response.status)"
                    )
                }
                
                guard let body = response.body,
                      let hierarchy = body.getString(
                        at: 0,
                        length: body.readableBytes
                      )
                else {
                    try await Wait.sleep(for: 1)
                    continue
                }
                
                if hierarchy.contains(text) {
                    return true
                }
            } catch {
                try await Wait.sleep(for: 1)
            }
        }
        
        return false
    }
    
    public func waitFor(
        _ text: String,
        timeout: TimeInterval = 5
    ) async throws -> Bool {
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            do {
                let request = try HTTPClient.Request(
                    url: API.source(id),
                    method: .GET
                )
                let response = try await client.execute(request: request)
                    .get()
                
                guard response.status == .ok else {
                    throw AppiumError.invalidResponse(
                        "Failed to get hierarchy: HTTP \(response.status)"
                    )
                }
                
                guard let body = response.body,
                      let hierarchy = body.getString(
                        at: 0,
                        length: body.readableBytes
                      )
                else {
                    try await Wait.sleep(for: 1)
                    continue
                }
                
                if !hierarchy.contains(text) {
                    return true
                }
            } catch {
                try await Wait.sleep(for: 1)
            }
        }
        
        return false
    }

    public func waitForDismissed(
        _ text: String,
        timeout: TimeInterval = 5
    ) async throws -> Bool {
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            do {
                let request = try HTTPClient.Request(
                    url: API.source(id),
                    method: .GET
                )
                let response = try await client.execute(request: request)
                    .get()
                
                guard response.status == .ok else {
                    throw AppiumError.invalidResponse(
                        "Failed to get hierarchy: HTTP \(response.status)"
                    )
                }
                
                guard let body = response.body,
                      let hierarchy = body.getString(
                        at: 0,
                        length: body.readableBytes
                      )
                else {
                    try await Wait.sleep(for: 1)
                    continue
                }
                
                if !hierarchy.contains(text) {
                    return true
                }
            } catch {
                try await Wait.sleep(for: 1)
            }
        }
        
        return false
    }

    public func isChecked(
        _ element: Element
    ) async throws -> Bool {
        appiumLogger.info(
            "Checking visibility of element with strategy: \(element.strategy.rawValue) and selector: \(element.selector.wrappedValue) in session: \(id)"
        )

        let elementId: String
        do {
            elementId = try await select(element)
        } catch {
            appiumLogger.error("Failed to find element: \(error)")
            throw error
        }

        let request = try HTTPClient.Request(
            url: API.displayed(elementId, id),
            method: .GET
        )

        appiumLogger.info("Sending request to URL: \(request.url)")
        
        let response: HTTPClient.Response
        do {
            response = try await client.execute(request: request).get()
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
    
    public func value(
         _ element: Element
    ) async throws -> Double {
        appiumLogger.info(
            "Checking value of element with strategy: \(element.strategy.rawValue) and selector: \(element.selector.wrappedValue) in session: \(id)"
        )
        
        let elementId: String
        do {
            elementId = try await select(
                element, 35)
        } catch {
            appiumLogger.error("Failed to find element: \(error)")
            throw error
        }
        
        let request: HTTPClient.Request
        do {
            request = try HTTPClient.Request(
                url: API.attributeValue(elementId, id),
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
            response = try await client.execute(request: request).get()
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
    
    public func isVisible(
        _ element: Element
    ) async throws -> Bool {
        appiumLogger.info(
            "Checking visibility of element with strategy: \(element.strategy.rawValue) and selector: \(element.selector.wrappedValue) in session: \(id)"
        )
        
        let elementId: String
        do {
            elementId = try await select(
                element)
        } catch {
            appiumLogger.error("Failed to find element: \(error)")
            throw error
        }
        
        let request: HTTPClient.Request
        do {
            request = try HTTPClient.Request(
                url:
                    API.displayed(elementId, id),
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
            response = try await client.execute(request: request).get()
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
}
