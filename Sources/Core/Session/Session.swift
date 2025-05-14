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
            let message = (error as? Throwable)?.userFriendlyMessage ?? error.localizedDescription
            appiumLogger.error("Failed \(description): \(message)")
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
        pollInterval: TimeInterval = Wait.retryDelay,
        file: String = #file,
        line: UInt = #line,
        function: StaticString = #function,
        andWaitFor: Element? = nil,
        date: Date = Date()
    ) async throws {
        let fileId = "\(function) in \(file):\(line)"
        var lastError: Error?

        let internalSelectPollInterval = pollInterval

        while Date().timeIntervalSince(date) < wait {
            let iterationStartTime = Date()
            var remainingOverallTimeForIteration = wait - iterationStartTime.timeIntervalSince(date)

            if remainingOverallTimeForIteration < (internalSelectPollInterval + 0.1) {
                appiumLogger.warning("\(fileId) -- Not enough time remaining (\(String(format: "%.2fs", remainingOverallTimeForIteration))) for a select poll (\(internalSelectPollInterval)s) and click for \(element.selector.wrappedValue).")
                if lastError == nil {
                    lastError = AppiumError.timeoutError("\(fileId) -- Not enough time remaining for click attempt on \(element.selector.wrappedValue).")
                }
                break
            }

            var elementId: String
            do {
                appiumLogger.debug("\(fileId) -- Selecting element \(element.selector.wrappedValue) with timeout \(String(format: "%.2fs", remainingOverallTimeForIteration)) and internal poll \(internalSelectPollInterval)s.")
                elementId = try await select(element, remainingOverallTimeForIteration, pollInterval: internalSelectPollInterval, file: file, line: line, function: function)
            } catch let error {
                lastError = error
                let message = (error as? Throwable)?.userFriendlyMessage ?? error.localizedDescription
                appiumLogger.warning("\(fileId) -- Failed to select element \(element.selector.wrappedValue) during click: \(message)")
                
                if Date().timeIntervalSince(date) >= wait - pollInterval { break }
                try await Wait.sleep(for: UInt64(pollInterval))
                continue
            }
            
            remainingOverallTimeForIteration = wait - Date().timeIntervalSince(date)
            if remainingOverallTimeForIteration <= 0.05 {
                 appiumLogger.warning("\(fileId) -- Not enough time remaining (\(String(format: "%.2fs", remainingOverallTimeForIteration))) for click API call for \(elementId).")
                 if lastError == nil {
                    lastError = AppiumError.timeoutError("\(fileId) -- Not enough time for click API call on \(elementId).")
                 }
                 break
            }

            let request = try makeRequest(url: API.click(elementId, id), method: .POST)
            do {
                appiumLogger.debug("\(fileId) -- Attempting click on element \(elementId)")
                let response = try await executeRequest(request, description: "clicking element \(elementId)")

                switch response.status {
                case .ok:
                    appiumLogger.info("\(fileId) -- Click on \(elementId) reported OK by server.")
                    if let elementToWaitFor = andWaitFor {
                        let timeRemainingForWaitFor = wait - Date().timeIntervalSince(date)
                        if timeRemainingForWaitFor <= internalSelectPollInterval / 2 {
                            appiumLogger.error("\(fileId) -- Clicked \(elementId), but not enough time (\(String(format: "%.2fs",timeRemainingForWaitFor))) to wait for \(elementToWaitFor.selector.wrappedValue).")
                            throw AppiumError.timeoutError("\(fileId) -- Clicked \(elementId), but not enough time for \(elementToWaitFor.selector.wrappedValue).")
                        }
                        appiumLogger.info("\(fileId) -- Waiting for \(elementToWaitFor.selector.wrappedValue) for up to \(String(format: "%.2fs",timeRemainingForWaitFor))s.")
                        do {
                            _ = try await select(elementToWaitFor, timeRemainingForWaitFor, pollInterval: internalSelectPollInterval, file: file, line: line, function: function)
                            appiumLogger.info("\(fileId) -- Successfully clicked \(elementId) and found \(elementToWaitFor.selector.wrappedValue).")
                            return
                        } catch let waitError {
                            let message = (waitError as? Throwable)?.userFriendlyMessage ?? waitError.localizedDescription
                            appiumLogger.error("\(fileId) -- Clicked \(elementId), but \(elementToWaitFor.selector.wrappedValue) did not appear: \(message)")
                            throw AppiumError.timeoutError("\(fileId) -- Clicked \(elementId), but \(elementToWaitFor.selector.wrappedValue) did not appear: \(message)")
                        }
                    }
                    appiumLogger.info("\(fileId) -- Successfully clicked \(elementId).")
                    return

                case .badRequest:
                    lastError = AppiumError.invalidResponse("\(fileId) -- Bad request clicking element \(elementId).")
                    let message = (lastError as? Throwable)?.userFriendlyMessage ?? lastError?.localizedDescription ?? "Unknown bad request error"
                    appiumLogger.warning("\(message)")

                default:
                    lastError = AppiumError.invalidResponse("\(fileId) -- Failed to click element \(elementId): HTTP \(response.status).")
                    let message = (lastError as? Throwable)?.userFriendlyMessage ?? lastError?.localizedDescription ?? "Unknown server error"
                    appiumLogger.warning("\(message)")
                }
            } catch let error {
                lastError = error
                let message = (error as? Throwable)?.userFriendlyMessage ?? error.localizedDescription
                appiumLogger.warning("\(fileId) -- Error during click API call for \(elementId): \(message).")
            }

            if Date().timeIntervalSince(date) >= wait - pollInterval {
                appiumLogger.info("\(fileId) -- Not enough time for another retry poll (\(pollInterval)s) after click attempt for \(element.selector.wrappedValue).")
                break
            }
            appiumLogger.debug("\(fileId) -- Click attempt for \(element.selector.wrappedValue) requires retry. Sleeping for \(pollInterval)s.")
            try await Wait.sleep(for: UInt64(pollInterval))
        }

        let finalErrorMessagePt1 = "\(fileId) -- Click operation failed for \(element.selector.wrappedValue)."
        let finalErrorDetail = lastError != nil ? ((lastError as? Throwable)?.userFriendlyMessage ?? lastError!.localizedDescription) : "Timeout before completion."
        let finalErrorMessage = "\(finalErrorMessagePt1) Last error: \(finalErrorDetail)"
        
        appiumLogger.error("\(finalErrorMessage)")
        throw lastError ?? AppiumError.timeoutError(finalErrorMessage)
    }

    public func type(
        _ element: Element,
        text: String,
        pollInterval: TimeInterval = Wait.retryDelay,
        file: String = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) async throws {
        let fileId = "\(function) in \(file):\(line)"
        let elementId: String
        do {
            elementId = try await select(element, pollInterval: pollInterval, file: file, line: line, function: function)
        } catch {
            let message = (error as? Throwable)?.userFriendlyMessage ?? error.localizedDescription
            appiumLogger.error("\(fileId) -- Failed to find element: \(message)")
            throw error
        }

        let requestBody = try encodeJSON(["text": text])
        let request = try makeRequest(url: API.value(elementId, id), method: .POST, body: requestBody)

        do {
            let response = try await executeRequest(request, description: "typing into element")
            try validateOKResponse(response, errorMessage: "\(fileId) -- Failed to type into element")
        } catch {
            let message = (error as? Throwable)?.userFriendlyMessage ?? error.localizedDescription
            throw AppiumError.elementNotFound("\(fileId) -- Failed typing into element: \(message)")
        }
    }

    public func select(
        _ element: Element,
        _ timeout: TimeInterval = 5,
        pollInterval: TimeInterval = Wait.retryDelay,
        file: String = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) async throws -> String {
        let fileId = "\(function) in \(file):\(line)"
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            do {
                return try await selectUnsafe(element)
            } catch {
                let message = (error as? Throwable)?.userFriendlyMessage ?? error.localizedDescription
                appiumLogger.debug("\(fileId) -- Retry: \(message)")
                try await Wait.sleep(for: UInt64(pollInterval))
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
        let elementId = try await select(element)
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
        let elementId = try await select(element)
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
    
    private func getHierarchy() async throws -> String? {
        let request = try makeRequest(url: API.source(id), method: .GET)
        let response = try await executeRequest(request, description: "fetching hierarchy")
        try validateOKResponse(response, errorMessage: "Failed to get hierarchy")

        guard let body = response.body else { return nil }
        return body.getString(at: 0, length: body.readableBytes)
    }
    
    private func waitForHierarchy(
        timeout: TimeInterval,
        pollInterval: TimeInterval = Wait.retryDelay,
        matchCondition: (String) -> Bool
    ) async throws -> Bool {
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            do {
                if let hierarchy = try await getHierarchy(),
                   matchCondition(hierarchy) {
                    return true
                }
            } catch {
                let message = (error as? Throwable)?.userFriendlyMessage ?? error.localizedDescription
                appiumLogger.warning("Hierarchy fetch failed: \(message)")
            }

            try await Wait.sleep(for: UInt64(pollInterval))
        }
        return false
    }
    
    public func has(_ text: String) async throws -> Bool {
        guard let hierarchy = try await getHierarchy() else { return false }
        return hierarchy.contains(text)
    }

    public func has(_ times: Int, _ text: String) async throws -> Bool {
        guard let hierarchy = try await getHierarchy() else { return false }
        let occurrences = hierarchy.components(separatedBy: text).count - 1
        return occurrences >= times
    }

    public func willHave(_ text: String, timeout: TimeInterval = 5, pollInterval: TimeInterval = Wait.retryDelay) async throws -> Bool {
        try await waitForHierarchy(timeout: timeout, pollInterval: pollInterval) {
                $0.contains(text)
        }
    }
    
    public func hasNo(_ text: String) async throws -> Bool {
        guard let hierarchy = try await getHierarchy() else { return false }
                return !hierarchy.contains(text)
    }
    
    public func wontHave(_ text: String, timeout: TimeInterval = 5, pollInterval: TimeInterval = Wait.retryDelay) async throws -> Bool {
        try await waitForHierarchy(timeout: timeout, pollInterval: pollInterval) {
                !$0.contains(text)
        }
    }
}
