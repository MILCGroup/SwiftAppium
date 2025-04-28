//
//  Session.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//
import Foundation
import NIOHTTP1
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

    public init(client: HTTPClient, id: String, driver: Driver, deviceName: String?) {
        self.client = client
        self.id = id
        self.platform = driver.platform
        self.deviceName = driver.deviceName ?? ""
    }

    // MARK: - Helper Functions

    private func makeRequest(url: URL, method: HTTPMethod, body: Data? = nil) throws -> HTTPClient.Request {
        var request = try HTTPClient.Request(url: url, method: method)
        request.headers.add(name: "Content-Type", value: "application/json")
        if let body = body {
            request.body = .data(body)
        }
        return request
    }

    private func executeRequest(_ request: HTTPClient.Request, description: String) async throws -> HTTPClient.Response {
        do {
            return try await client.execute(request: request).get()
        } catch {
            appiumLogger.error("Failed \(description): \(error.localizedDescription)")
            throw error
        }
    }

    private func encodeJSON<T: Encodable>(_ object: T) throws -> Data {
        try JSONEncoder().encode(object)
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }

    private func validateOKResponse(_ response: HTTPClient.Response, errorMessage: String) throws {
        guard response.status == .ok else {
            throw AppiumError.invalidResponse("\(errorMessage): HTTP \(response.status)")
        }
    }

    private func waitForHierarchy(timeout: TimeInterval, matchCondition: (String) -> Bool) async throws -> Bool {
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            do {
                let request = try makeRequest(url: API.source(id), method: .GET)
                let response = try await executeRequest(request, description: "fetching hierarchy")
                try validateOKResponse(response, errorMessage: "Failed to get hierarchy")
                
                guard let body = response.body,
                      let hierarchy = body.getString(at: 0, length: body.readableBytes) else {
                    appiumLogger.warning("Failed to read hierarchy, retrying...")
                    try await Wait.sleep(for: UInt64(0.2)) 
                    continue
                }
                
                if matchCondition(hierarchy) {
                    return true
                }
                
            } catch {
                appiumLogger.warning("Hierarchy fetch failed: \(error.localizedDescription)")
                try await Wait.sleep(for: UInt64(0.2))
            }
            
            try await Wait.sleep(for: UInt64(0.2))
        }
        return false
    }

    private func fetchElementId(_ element: Element, timeout: TimeInterval = 5) async throws -> String {
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            do {
                let body = try encodeJSON(["using": element.strategy.rawValue, "value": element.selector.wrappedValue])
                let request = try makeRequest(url: API.element(id), method: .POST, body: body)
                let response = try await executeRequest(request, description: "finding element")
                try validateOKResponse(response, errorMessage: "Failed to find element")

                guard let responseBody = response.body,
                      let responseString = responseBody.getString(at: 0, length: responseBody.readableBytes),
                      let elementResponse = try? decodeJSON(ElementResponse.self, from: Data(responseString.utf8)) else {
                    throw AppiumError.elementNotFound("Element not found or invalid response")
                }
                return elementResponse.value.elementId
            } catch {
                try await Wait.sleep(for: 1)
            }
        }
        throw AppiumError.timeoutError("Timeout reached while waiting for element")
    }

    // MARK: - Main Functions

    public static func executeScript(_ session: Self, script: String, args: [Any]) async throws -> Any? {
        appiumLogger.info("Executing script in session: \(session.id)")
        let dictionary: [String: Any] = [
            "script": script,
            "args": args
        ]

        let body = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        let request = try session.makeRequest(url: API.execute(session.id), method: .POST, body: body)
        let response = try await session.executeRequest(request, description: "executing script")
        try session.validateOKResponse(response, errorMessage: "Failed to execute script")

        if let responseData = response.body {
            let jsonResponse = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any]
            return jsonResponse?["value"]
        }
        return nil
    }

    public static func hideKeyboard(_ session: Self) async throws {
        appiumLogger.info("Attempting to hide keyboard in session: \(session.id)")
        let request = try session.makeRequest(url: API.hideKeyboard(session.id), method: .POST)
        let response = try await session.executeRequest(request, description: "hiding keyboard")
        try session.validateOKResponse(response, errorMessage: "Failed to hide keyboard")
        appiumLogger.info("Keyboard hidden successfully.")
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

        let request = try makeRequest(url: API.click(elementId, id), method: .POST)
        
        do {
            let response = try await executeRequest(request, description: "clicking element")
            switch response.status {
            case .ok:
                break
            case .badRequest:
                appiumLogger.error("\(fileId) -- Bad request clicking element \(elementId)")
                try await Wait.sleep(for: 1)
                if Date().timeIntervalSince(date) < wait {
                    try await click(element, wait, file: file, line: line, function: function, andWaitFor: andWaitFor, date: date)
                } else {
                    throw AppiumError.timeoutError("Timed out clicking element \(elementId)")
                }
            default:
                throw AppiumError.invalidResponse("\(fileId) -- Failed to click element: HTTP \(response.status)")
            }
        } catch {
            appiumLogger.info("Retrying click on element: \(element.selector.wrappedValue)")
            let response = try await executeRequest(request, description: "retry clicking element")
            guard response.status == .ok else {
                appiumLogger.error("\(fileId) -- Retry failed clicking element \(element.selector.wrappedValue)")
                throw AppiumError.invalidResponse("\(fileId) -- Retry failed clicking element: HTTP \(response.status)")
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
            elementId = try await select(element, file: file, line: line, function: function)
        } catch {
            appiumLogger.error("\(fileId) -- Failed to find element: \(error)")
            throw error
        }

        let requestBody = try encodeJSON(["text": text])
        let request = try makeRequest(url: API.value(elementId, id), method: .POST, body: requestBody)

        do {
            let response = try await executeRequest(request, description: "typing into element")
            try validateOKResponse(response, errorMessage: "\(fileId) -- Failed to type into element")
        } catch {
            throw AppiumError.elementNotFound("\(fileId) -- Failed typing into element: \(error.localizedDescription)")
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
    
    private func selectUnsafe(_ element: Element) async throws -> String {
        let body = try encodeJSON([
            "using": element.strategy.rawValue,
            "value": element.selector.wrappedValue
        ])
        let request = try makeRequest(url: API.element(id), method: .POST, body: body)
        let response = try await executeRequest(request, description: "finding element unsafe")
        try validateOKResponse(response, errorMessage: "Failed to find element")

        guard let body = response.body else {
            throw AppiumError.invalidResponse("No response body while finding element")
        }

        let bufferData = Data(buffer: body)
        let elementResponse = try decodeJSON(ElementResponse.self, from: bufferData)
        return elementResponse.value.elementId
    }
    
    public func isVisible(_ element: Element) async throws -> Bool {
        let elementId = try await fetchElementId(element)
        let request = try makeRequest(url: API.displayed(elementId, id), method: .GET)
        let response = try await executeRequest(request, description: "checking visibility")
        try validateOKResponse(response, errorMessage: "Failed to check visibility")

        guard let body = response.body else {
            throw AppiumError.invalidResponse("No response body for visibility")
        }

        let bufferData = Data(buffer: body)
        let visibilityResponse = try decodeJSON(VisibilityResponse.self, from: bufferData)
        return visibilityResponse.value
    }

    public func isChecked(_ element: Element) async throws -> Bool {
        return try await isVisible(element)
    }

    public func value(_ element: Element) async throws -> Double {
        let elementId = try await fetchElementId(element)
        let request = try makeRequest(url: API.attributeValue(elementId, id), method: .GET)
        let response = try await executeRequest(request, description: "getting element value")
        try validateOKResponse(response, errorMessage: "Failed to get element value")

        guard let body = response.body,
              let responseString = body.getString(at: 0, length: body.readableBytes) else {
            throw AppiumError.invalidResponse("No value data received")
        }

        let valueResponse = try decodeJSON(ValueResponse.self, from: Data(responseString.utf8))
        let valueString = valueResponse.value
        let numericString = valueString.trimmingCharacters(in: CharacterSet(charactersIn: "0123456789.-").inverted)

        guard var doubleValue = Double(numericString) else {
            throw AppiumError.invalidResponse("Failed to convert value to Double")
        }

        if valueString.contains("%") {
            doubleValue /= 100
        }
        return doubleValue
    }
    
    public func containsMultipleInHierarchy(contains times: Int, _ text: String, timeout: TimeInterval = 5) async throws -> Bool {
        try await waitForHierarchy(timeout: timeout) { hierarchy in
            let occurrences = hierarchy.components(separatedBy: text).count - 1
            return occurrences >= times
        }
    }
    
    public func hierarchyContains(_ text: String, timeout: TimeInterval = 5) async throws -> Bool {
        try await waitForHierarchy(timeout: timeout) { $0.contains(text) }
    }

    public func waitFor(_ text: String, timeout: TimeInterval = 5) async throws -> Bool {
        try await waitForHierarchy(timeout: timeout) { $0.contains(text) }
    }

    public func hierarchyDoesNotContain(_ text: String, timeout: TimeInterval = 5) async throws -> Bool {
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            do {
                let request = try makeRequest(url: API.source(id), method: .GET)
                let response = try await executeRequest(request, description: "fetching hierarchy")
                try validateOKResponse(response, errorMessage: "Failed to get hierarchy")
                if let body = response.body,
                   let hierarchy = body.getString(at: 0, length: body.readableBytes) {
                    if hierarchy.contains(text) {
                        return false
                    }
                }
            } catch {
                try await Wait.sleep(for: 1)
            }
        }
        return true
    }
    public func waitForDismissed(_ text: String, timeout: TimeInterval = 5) async throws -> Bool {
        try await waitForHierarchy(timeout: timeout) { !$0.contains(text) }
    }
}
