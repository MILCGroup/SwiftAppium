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

    private func executeRequest(_ request: HTTPClient.Request, description: String, logData: LogData = LogData()) async throws -> HTTPClient.Response {
        do {
            return try await client.execute(request: request).get()
        } catch {
            let userMessage = (error as? Throwable)?.userFriendlyMessage ?? "An unexpected error occurred: \(error.localizedDescription)"
            appiumLogger.error(userMessage, logData: logData)
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

    public static func executeScript(_ session: Self, script: String, args: [Any], logData: LogData = LogData()) async throws -> Any? {
        appiumLogger.info("Running script in session \(session.id)", logData: logData)
        let dictionary: [String: Any] = [
            "script": script,
            "args": args
        ]

        let body = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        let request = try session.makeRequest(url: API.execute(session.id), method: .POST, body: body)
        let response = try await session.executeRequest(request, description: "executing script", logData: logData)
        try session.validateOKResponse(response, errorMessage: "Failed to execute script")

        if let responseData = response.body {
            let jsonResponse = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any]
            return jsonResponse?["value"]
        }
        return nil
    }

    public static func hideKeyboard(_ session: Self, logData: LogData = LogData()) async throws {
        appiumLogger.info("Requesting to hide keyboard in session \(session.id)", logData: logData)
        let request = try session.makeRequest(url: API.hideKeyboard(session.id), method: .POST)
        let response = try await session.executeRequest(request, description: "hiding keyboard", logData: logData)
        try session.validateOKResponse(response, errorMessage: "Failed to hide keyboard")
        appiumLogger.info("Keyboard was hidden successfully.", logData: logData)
    }
    
    public func click(
        _ element: Element,
        _ timeout: TimeInterval = 5,
        pollInterval: TimeInterval = Wait.retryDelay,
        logData: LogData = LogData(),
        andWaitFor: Element? = nil,
        date: Date = Date()
    ) async throws {
        appiumLogger.info("Clicking...", logData: logData)
        var lastError: Error?
        let internalSelectPollInterval = pollInterval
        while Date().timeIntervalSince(date) < timeout {
            let iterationStartTime = Date()
            var remainingOverallTimeForIteration = timeout - iterationStartTime.timeIntervalSince(date)
            if remainingOverallTimeForIteration < (internalSelectPollInterval + 0.1) {
                appiumLogger.warning("Not enough time left to select and click \(element.selector.wrappedValue)", logData: logData)
                if lastError == nil {
                    lastError = AppiumError.timeoutError("Not enough time left for click attempt on \(element.selector.wrappedValue).")
                }
                break
            }
            var elementId: String
            do {
                appiumLogger.debug("Selecting element \(element.selector.wrappedValue)", logData: logData)
                elementId = try await select(element, remainingOverallTimeForIteration, pollInterval: internalSelectPollInterval, logData: logData)
            } catch let error {
                lastError = error
                let userMessage = (error as? Throwable)?.userFriendlyMessage ?? "Could not select element: \(error.localizedDescription)"
                appiumLogger.warning(userMessage, logData: logData)
                if Date().timeIntervalSince(date) >= timeout - pollInterval { break }
                try await Wait.sleep(for: UInt64(pollInterval))
                continue
            }
            remainingOverallTimeForIteration = timeout - Date().timeIntervalSince(date)
            if remainingOverallTimeForIteration <= 0.05 {
                appiumLogger.warning("Not enough time left to send click command for \(elementId)", logData: logData)
                if lastError == nil {
                    lastError = AppiumError.timeoutError("Not enough time for click API call on \(elementId).")
                }
                break
            }
            let request = try makeRequest(url: API.click(elementId, id), method: .POST)
            do {
                appiumLogger.debug("Attempting to click element \(elementId)", logData: logData)
                let response = try await executeRequest(request, description: "clicking element \(elementId)", logData: logData)
                switch response.status {
                case .ok:
                    appiumLogger.info("Click succeeded for \(elementId)", logData: logData)
                    if let elementToWaitFor = andWaitFor {
                        let timeRemainingForWaitFor = timeout - Date().timeIntervalSince(date)
                        if timeRemainingForWaitFor <= internalSelectPollInterval / 2 {
                            appiumLogger.error("Clicked, but not enough time to wait for next element \(elementToWaitFor.selector.wrappedValue)", logData: logData)
                            throw AppiumError.timeoutError("Clicked \(elementId), but not enough time for \(elementToWaitFor.selector.wrappedValue).")
                        }
                        appiumLogger.info("Waiting for next element \(elementToWaitFor.selector.wrappedValue)", logData: logData)
                        do {
                            _ = try await select(elementToWaitFor, timeRemainingForWaitFor, pollInterval: internalSelectPollInterval, logData: logData)
                            appiumLogger.info("Click and wait succeeded for \(elementToWaitFor.selector.wrappedValue)", logData: logData)
                            return
                        } catch let waitError {
                            let userMessage = (waitError as? Throwable)?.userFriendlyMessage ?? "Element did not appear: \(waitError.localizedDescription)"
                            appiumLogger.error(userMessage, logData: logData)
                            throw AppiumError.timeoutError(userMessage)
                        }
                    }
                    appiumLogger.info("Click succeeded for \(elementId)", logData: logData)
                    return
                case .badRequest:
                    lastError = AppiumError.invalidResponse("Bad request clicking element \(elementId).")
                    let userMessage = (lastError as? Throwable)?.userFriendlyMessage ?? "Bad request clicking element."
                    appiumLogger.warning(userMessage, logData: logData)
                default:
                    lastError = AppiumError.invalidResponse("Failed to click element \(elementId): HTTP \(response.status).")
                    let userMessage = (lastError as? Throwable)?.userFriendlyMessage ?? "Server error clicking element."
                    appiumLogger.warning(userMessage, logData: logData)
                }
            } catch let error {
                lastError = error
                let userMessage = (error as? Throwable)?.userFriendlyMessage ?? "Error during click: \(error.localizedDescription)"
                appiumLogger.warning(userMessage, logData: logData)
            }
            if Date().timeIntervalSince(date) >= timeout - pollInterval {
                appiumLogger.info("Not enough time for another retry after click attempt for \(element.selector.wrappedValue)", logData: logData)
                break
            }
            appiumLogger.debug("Retrying click after waiting for \(element.selector.wrappedValue)", logData: logData)
            try await Wait.sleep(for: UInt64(pollInterval))
        }
        let finalErrorMessagePt1 = "Click operation failed for \(element.selector.wrappedValue)."
        let finalErrorDetail = lastError != nil ? ((lastError as? Throwable)?.userFriendlyMessage ?? lastError!.localizedDescription) : "Timeout before completion."
        let finalErrorMessage = "\(finalErrorMessagePt1) Last error: \(finalErrorDetail)"
        appiumLogger.error(finalErrorMessage, logData: logData)
        throw lastError ?? AppiumError.timeoutError(finalErrorMessage)
    }

    public func type(
        _ element: Element,
        text: String,
        pollInterval: TimeInterval = Wait.retryDelay,
        logData: LogData = LogData()
    ) async throws {
        let fileId = "\(logData.function) in \(logData.file):\(logData.line)"
        let elementId: String
        do {
            elementId = try await select(element, pollInterval: pollInterval, logData: logData)
        } catch {
            let message = (error as? Throwable)?.userFriendlyMessage ?? error.localizedDescription
            appiumLogger.error("\(fileId) -- Failed to find element: \(message)", logData: logData)
            throw error
        }

        let requestBody = try encodeJSON(["text": text])
        let request = try makeRequest(url: API.value(elementId, id), method: .POST, body: requestBody)

        do {
            let response = try await executeRequest(request, description: "typing into element", logData: logData)
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
        logData: LogData = LogData()
    ) async throws -> String {
        let fileId = "\(logData.function) in \(logData.file):\(logData.line)"
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            do {
                return try await selectUnsafe(element)
            } catch {
                let message = (error as? Throwable)?.userFriendlyMessage ?? error.localizedDescription
                appiumLogger.debug("\(fileId) -- Retry: \(message)", logData: logData)
                try await Wait.sleep(for: UInt64(pollInterval))
            }
        }

        appiumLogger.debug("\(fileId) -- Timeout reached while waiting for element with selector: \(element.selector.wrappedValue)", logData: logData)
        throw AppiumError.timeoutError(
            "\(fileId) -- Timeout reached while waiting for element with selector: \(element.selector.wrappedValue)"
        )
    }
    
    private func selectUnsafe(_ element: Element, logData: LogData = LogData()) async throws -> String {
        let body = try encodeJSON([
            "using": element.strategy.rawValue,
            "value": element.selector.wrappedValue
        ])
        let request = try makeRequest(url: API.element(id), method: .POST, body: body)
        let response = try await executeRequest(request, description: "finding element unsafe", logData: logData)
        try validateOKResponse(response, errorMessage: "Failed to find element")

        guard let body = response.body else {
            throw AppiumError.invalidResponse("No response body while finding element")
        }

        let bufferData = Data(buffer: body)
        let elementResponse = try decodeJSON(ElementResponse.self, from: bufferData)
        return elementResponse.value.elementId
    }
    
    public func isVisible(_ element: Element, logData: LogData = LogData()) async throws -> Bool {
        let elementId = try await select(element, logData: logData)
        let request = try makeRequest(url: API.displayed(elementId, id), method: .GET)
        let response = try await executeRequest(request, description: "checking visibility", logData: logData)
        try validateOKResponse(response, errorMessage: "Failed to check visibility")

        guard let body = response.body else {
            throw AppiumError.invalidResponse("No response body for visibility")
        }

        let bufferData = Data(buffer: body)
        let visibilityResponse = try decodeJSON(VisibilityResponse.self, from: bufferData)
        return visibilityResponse.value
    }

    public func isChecked(_ element: Element, logData: LogData = LogData()) async throws -> Bool {
        return try await isVisible(element, logData: logData)
    }

    public func value(_ element: Element, logData: LogData = LogData()) async throws -> Double {
        let elementId = try await select(element, logData: logData)
        let request = try makeRequest(url: API.attributeValue(elementId, id), method: .GET)
        let response = try await executeRequest(request, description: "getting element value", logData: logData)
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
    
    private func getHierarchy(logData: LogData = LogData()) async throws -> String? {
        let request = try makeRequest(url: API.source(id), method: .GET)
        let response = try await executeRequest(request, description: "fetching hierarchy", logData: logData)
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
