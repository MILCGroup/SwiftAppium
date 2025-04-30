//
//  SessionModel.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import Foundation
import AsyncHTTPClient
import Testing

public class SessionModel: AppiumSession, @unchecked Sendable, Normalizable {
    public let client: HTTPClient
    public let device: Driver
    public let session: Session
    public var id: String { session.id }
    public var platform: Platform { session.platform }

    public init(client: HTTPClient, device: Driver) async throws {
        self.client = client
        self.device = device
        do {
            self.session = try await Self.initializeSession(client: client, device: device)
        } catch {
            appiumLogger.critical("Failed to initialize session: \(error)")
            // Attempt to shutdown client before rethrowing
             do {
                 try await client.shutdown()
                 appiumLogger.info("HTTPClient shut down successfully after session initialization failure.")
             } catch {
                 appiumLogger.error("Failed to shut down HTTPClient after session initialization failure: \(error)")
             }
            throw error // Rethrow the original session initialization error
        }
    }

    private static func initializeSession(client: HTTPClient, device: Driver) async throws -> Session {
        if let existingSession = try await getSession(client: client, device: device) {
            appiumLogger.info("Using existing session: \(existingSession.id)")
            return existingSession
        } else {
            appiumLogger.info("Creating a new session for device: \(device.deviceName ?? "N/A")")
            let newSession = try await createTestSession(client: client, device: device)
            appiumLogger.info("Created new session: \(newSession.id)")
            return newSession
        }
    }

    private static func createTestSession(
        client: HTTPClient,
        device: Driver
    ) async throws -> Session {

        let requiredCapabilities: [String: Any] = [
            "platformName": device.platformName,
            "appium:platformVersion": device.platformVersion,
            "appium:newCommandTimeout": 3600,
            "appium:automationName": device.automationName,
        ]

        let conditionalCapabilities: [String: Any?] = [
            "appium:usePreinstalledWDA": device.usePreinstalledWDA,
            "appium:deviceName": device.deviceName,
            "appium:udid": device.udid,
            "appium:app": device.app,
            "appium:browserName": device.browserName,
            "appium:wdaLocalPort": device.wdaLocalPort,
            "appium:espressoBuildConfig": device.espressoBuildConfig,
            "appium:forceEspressoRebuild": device.forceEspressoRebuild
        ]

        let capabilities = requiredCapabilities.merging(
            conditionalCapabilities.compactMapValues { $0 },
            uniquingKeysWith: { current, _ in current }
        )

        let payload: [String: Any] = [
            "capabilities": [
                "alwaysMatch": capabilities
            ]
        ]

        let requestBody = try JSONSerialization.data(
            withJSONObject: payload, options: [])
        
        let normalizedData = try normalizeJSON(requestBody)

        let expectedRequest: String
        if device.platformName == Platform.browser.rawValue {
            expectedRequest =
            "{\"capabilities\":{\"alwaysMatch\":{\"appium:automationName\":\"Chromium\",\"appium:browserName\":\"chrome\",\"appium:newCommandTimeout\":3600,\"appium:platformVersion\":\"\(device.platformVersion)\",\"platformName\":\"\(device.platformName)\"}}}"
        } else if device.platformName == Platform.iOS.rawValue {
            expectedRequest =
                "{\"capabilities\":{\"alwaysMatch\":{\"appium:app\":\"\(device.app!)\",\"appium:automationName\":\"XCUITest\",\"appium:deviceName\":\"\(device.deviceName!)\",\"appium:newCommandTimeout\":3600,\"appium:platformVersion\":\"\(device.platformVersion)\",\"appium:udid\":\"\(device.udid!)\",\"appium:usePreinstalledWDA\":\(device.usePreinstalledWDA!),\"appium:wdaLocalPort\":\(device.wdaLocalPort!),\"platformName\":\"iOS\"}}}"
        } else {
            expectedRequest = normalizedData
        }

        do {
            try #require(normalizedData == expectedRequest)
        } catch {
            appiumLogger.error("Normalized request data does not match expected structure: \(error)")
            throw error
        }
        let url = "\(API.serverURL)/session"
        let expectedURL = "\(API.serverURL)/session"
        do {
            try #require(url == expectedURL)
        } catch {
             appiumLogger.error("Request URL does not match expected URL: \(error)")
             throw error
        }
        var request = try HTTPClient.Request(
            url: url, method: .POST)

        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = .data(requestBody)
        let response = try await client.execute(request: request).get()

        try #require(response.status == .ok)
        guard let byteBuffer = response.body else {
            throw AppiumError.invalidResponse("No response body received for session creation")
        }
        let normalizedBody = try normalizeResponseBody(byteBuffer)

        let expectedBody: String
        switch device {
        case .Chromium:
            expectedBody =
                "{\"value\":{\"capabilities\":{\"acceptInsecureCerts\":false,\"browserName\":\"chrome\",\"browserVersion\":\"[BROWSER_VERSION]\",\"chrome\":{\"chromedriverVersion\":\"[CHROMEDRIVER_VERSION]\",\"userDataDir\":\"[DYNAMIC_PATH]\"},\"fedcm:accounts\":true,\"goog:chromeOptions\":{\"debuggerAddress\":\"localhost:[PORT]\"},\"networkConnectionEnabled\":false,\"pageLoadStrategy\":\"normal\",\"platformName\":\"mac\",\"proxy\":{},\"setWindowRect\":true,\"strictFileInteractability\":false,\"timeouts\":{\"implicit\":0,\"pageLoad\":300000,\"script\":30000},\"unhandledPromptBehavior\":\"dismiss and notify\",\"webauthn:extension:credBlob\":true,\"webauthn:extension:largeBlob\":true,\"webauthn:extension:minPinLength\":true,\"webauthn:extension:prf\":true,\"webauthn:virtualAuthenticators\":true},\"sessionId\":\"[SESSION_ID]\"}}"
        default:
            expectedBody = normalizedBody
        }

        do {
            try #require(normalizedBody == expectedBody)
        } catch {
            appiumLogger.error("Normalized response body does not match expected structure: \(error)")
            throw error
        }
        
        let responseBodyString = byteBuffer.getString(at: 0, length: byteBuffer.readableBytes) ?? ""
        let responseData = Data(responseBodyString.utf8)

        if device.platformName == Platform.browser.rawValue {
            let sessionResponse = try JSONDecoder().decode(WebResponse.self, from: responseData)
            let sessionId = sessionResponse.value.sessionId!
            #expect(sessionId.isEmpty == false)
            return Session(client: client, id: sessionId, platform: .browser)
        } else if device.platformName == Platform.android.rawValue {
            let sessionResponse = try JSONDecoder().decode(AndroidResponse.self, from: responseData)
            let sessionId = sessionResponse.value.sessionId!
            #expect(sessionId.isEmpty == false)
            return Session(client: client, id: sessionId, platform: .android)
        } else {
            let sessionResponse = try JSONDecoder().decode(iOSResponse.self, from: responseData)
            let sessionId = sessionResponse.value.id
            #expect(sessionId.isEmpty == false)
            return Session(client: client, id: sessionId, platform: .iOS)
        }
    }
    
    private static func getSession(
        client: HTTPClient,
        device: Driver
    ) async throws -> Session? {
        let sessions: ([AndroidResponse.ResponseValue], [iOSResponse.Value], [WebResponse.Session])
        do {
            sessions = try await findSessions(client: client)
        } catch {
            appiumLogger.error("Failed to find existing sessions: \(error)")
            return nil // Treat failure to find sessions as no session found
        }

        let totalSessions = sessions.0.count + sessions.1.count + sessions.2.count
        appiumLogger.info("Found \(totalSessions) total active sessions")

        if totalSessions == 0 {
            appiumLogger.warning("No active sessions found")
            return nil
        }

        switch device.platformName {
        case Platform.android.rawValue:
            let matchingSession = sessions.0.first { $0.capabilities.platformVersion == device.platformVersion }
            guard let androidSession = matchingSession, let sessionId = androidSession.sessionId else {
                appiumLogger.warning("No matching Android session found for version \(device.platformVersion)")
                return nil
            }
            appiumLogger.info("Found matching Android session: \(sessionId) for version \(device.platformVersion)")
            return Session(client: client, id: sessionId, driver: device, deviceName: "Emulator\(androidSession.capabilities.platformVersion)")

        case Platform.iOS.rawValue:
            let matchingSession = sessions.1.first { $0.capabilities.platformVersion == device.platformVersion && $0.capabilities.udid == device.udid }
            guard let iOSSession = matchingSession else {
                appiumLogger.warning("No matching iOS session found for version \(device.platformVersion) and UDID \(device.udid ?? "unknown")")
                return nil
            }
            appiumLogger.info("Found matching iOS session: \(iOSSession.id) for version \(device.platformVersion)")
            return Session(client: client, id: iOSSession.id, driver: device, deviceName: iOSSession.capabilities.udid)

        case Platform.browser.rawValue:
            fallthrough
        default:
             guard let webSession = sessions.2.first, let sessionId = webSession.sessionId else {
                 appiumLogger.warning("No matching browser session found")
                 return nil
             }
             appiumLogger.info("Found matching \(device.automationName) session: \(sessionId)")
             return Session(client: client, id: sessionId, driver: device, deviceName: webSession.capabilities.browserName)
         }
    }
    
    private static func findSessions(
        client: HTTPClient
    ) async throws -> (
        [AndroidResponse.ResponseValue],
        [iOSResponse.Value],
        [WebResponse.Session]
    ) {
        
        appiumLogger.info("Requesting active sessions...")

        var request = try HTTPClient.Request(
            url: API.sessions(), method: .GET)
            request.headers.add(name: "Content-Type", value: "application/json")

        let response = try await client.execute(request: request).get()
        appiumLogger.info("Received response with status: \(response.status)")
        guard let byteBuffer = response.body else {
            throw AppiumError.invalidResponse("No response body when querying sessions")
        }
        guard let body = byteBuffer.getString(at: 0, length: byteBuffer.readableBytes) else {
            throw AppiumError.invalidResponse("Cannot read response body when querying sessions")
        }

        let sessionListResponse = try JSONDecoder().decode(
            SessionResponse.self, from: Data(body.utf8))

        let androidSessions = sessionListResponse.value.filter { $0.capabilities.platformName?.lowercased() == "android" }
        let iOSSessions = sessionListResponse.value.filter { $0.capabilities.platformName?.lowercased() == "ios" }
        let webSessions = sessionListResponse.value.filter { $0.capabilities.browserName != nil }

        appiumLogger.info("Active Android sessions found: \(androidSessions.count)")
        appiumLogger.info("Active iOS sessions found: \(iOSSessions.count)")
        appiumLogger.info("Active Web sessions found: \(webSessions.count)")

        return (
            androidSessions.map { AndroidResponse.ResponseValue(from: $0) },
            iOSSessions.map { iOSResponse.Value(from: $0) },
            webSessions.map { WebResponse.Session(from: $0) }
        )
    }
    
    public func executeScript(
        script: String,
        args: [Any]
    ) async throws -> Any? {
        return try await Session.executeScript(
            session,
            script: script,
            args: args
        )
    }
    
    public func hideKeyboard() async throws {
        try await Session.hideKeyboard(session)
    }

    public func click(
        _ element: Element,
        _ wait: TimeInterval = 5,
        pollInterval: TimeInterval = Wait.retryDelay,
        log: LogData = LogData(),
        andWaitFor: Element? = nil,
        date: Date = Date()
    ) async throws {
        try await session.click(
            element,
            wait,
            pollInterval: pollInterval,
            log: log,
            andWaitFor: andWaitFor,
            date: date
        )
    }

    public func type(
        _ element: Element,
        text: String,
        pollInterval: TimeInterval = Wait.retryDelay,
        log: LogData = LogData()
    ) async throws {
        try await session.type(
            element,
            text: text,
            pollInterval: pollInterval,
            log: log
        )
    }

    public func select(
        _ element: Element,
        _ timeout: TimeInterval = 5,
        pollInterval: TimeInterval = Wait.retryDelay,
        log: LogData = LogData()
    ) async throws -> String {
        return try await session.select(
            element,
            timeout,
            pollInterval: pollInterval,
            log: log
        )
    }

    public func has(
        _ times: Int, _ text: String,
        timeout: TimeInterval = 5,
        pollInterval: TimeInterval = Wait.retryDelay
    ) async throws -> Bool {
        return try await session.has(
            times, text, timeout: timeout, pollInterval: pollInterval
        )
    }
    
    public func has(
        _ text: String,
        timeout: TimeInterval = 5,
        pollInterval: TimeInterval = Wait.retryDelay
    ) async throws -> Bool {
        return try await session.has(text, timeout: timeout, pollInterval: pollInterval)
    }

    public func hasNo(
        _ text: String,
        timeout: TimeInterval = 5,
        pollInterval: TimeInterval = Wait.retryDelay
    ) async throws -> Bool {
        return try await session.hasNo(text, timeout: timeout, pollInterval: pollInterval)
    }

    public func isChecked(
        _ element: Element
    ) async throws -> Bool {
        return try await session.isChecked(element)
    }

    public func value(
        _ element: Element
    ) async throws -> Double {
        return try await session.value(element)
    }

    public func isVisible(
        _ element: Element
    ) async throws -> Bool {
        return try await session.isVisible(element)
    }
}
