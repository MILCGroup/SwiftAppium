//
//  TestModel.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import AsyncHTTPClient
import Foundation
import Testing
import Observation

@Observable
public class TestModel: @unchecked Sendable, Normalizable {
    public let client: Client!
    public var session: Session!
    public var device: Driver
    
    public init(_ device: Driver) async throws {
        self.client = Client()
        self.device = device
        self.session = try await sessionCall(client: client.client)
    }
    
    public var clientModel: ClientModel {
        return ClientModel()
    }
    
    public var sessionModel: SessionModel {
        return SessionModel()
    }
    
    func sessionCall(client: HTTPClient) async throws -> Session {
        do {
            if let existingSession = try await getSession(client: client, device: device) {
                webLogger.info("We already have a session")
                session = existingSession
                return session
            } else {
                webLogger.info("We need a new session")
                session = try await createTestSession(client: client, device: device)
                return session
            }
        } catch {
            try await client.shutdown()
            throw error
        }
    }
    
    func createTestSession(
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

        do {
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
                try await client.shutdown()
            }
            let url = "\(API.serverURL)/session"
            let expectedURL = "http://localhost:4723/session"
            do {
                try #require(url == expectedURL)
            } catch {
                try await client.shutdown()
            }
            var request = try HTTPClient.Request(
                url: url, method: .POST)

            request.headers.add(name: "Content-Type", value: "application/json")
            request.body = .data(requestBody)
            let response = try await client.execute(request: request).get()

            try #require(response.status == .ok)
            guard let byteBuffer = response.body else {
                throw NSError(
                    domain: "Appium", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No response body"]
                )
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
                try await client.shutdown()
            }

            if device.platformName == Platform.browser.rawValue {
                let sessionResponse: WebResponse = try JSONDecoder().decode(
                    WebResponse.self,
                    from: Data(
                        byteBuffer.getString(
                            at: 0, length: byteBuffer.readableBytes)!.utf8))
                let sessionId = sessionResponse.value.sessionId!
                #expect(sessionId.isEmpty == false)

                return Session(
                    client: client, id: sessionId, platform: .browser)
            } else if device.platformName == Platform.android.rawValue {
                let sessionResponse: AndroidResponse = try JSONDecoder()
                    .decode(
                        AndroidResponse.self,
                        from: Data(
                            byteBuffer.getString(
                                at: 0, length: byteBuffer.readableBytes)!.utf8))
                let sessionId = sessionResponse.value.sessionId!
                #expect(sessionId.isEmpty == false)

                return Session(
                    client: client, id: sessionId, platform: .android)
            } else {
                let sessionResponse: iOSResponse = try JSONDecoder().decode(
                    iOSResponse.self,
                    from: Data(
                        byteBuffer.getString(
                            at: 0, length: byteBuffer.readableBytes)!.utf8))
                let sessionId = sessionResponse.value.id
                #expect(sessionId.isEmpty == false)

                return Session(
                    client: client, id: sessionId, platform: .iOS)
            }
        }
    }
    
    func getSession(
        client: HTTPClient,
        device: Driver
    ) async throws -> Session? {
        let sessions:
            (
                [AndroidResponse.ResponseValue],
                [iOSResponse.Value],
                [WebResponse.Session]
            ) = try await findSessions(client: client)

        let totalSessions =
            sessions.0.count + sessions.1.count + sessions.2.count
        appiumLogger.info("Found \(totalSessions) total active sessions")

        if totalSessions == 0 {
            appiumLogger.warning("No active sessions found")
            return nil
        }

        let session: Session?
        switch device.platformName {
        case Platform.android.rawValue:
            // Find matching Android session with the same platform version
            let matchingSession = sessions.0.first { androidSession in
                androidSession.capabilities.platformVersion
                    == device.platformVersion
            }

            guard let androidSession = matchingSession,
                let sessionId = androidSession.sessionId
            else {
                appiumLogger.warning(
                    "No matching Android session found for version \(device.platformVersion)"
                )
                return nil
            }
            appiumLogger.info(
                "Found matching Android session: \(sessionId) for version \(device.platformVersion)"
            )
            session = Session(
                client: client, id: sessionId, driver: device,
                deviceName:
                    "Emulator\(androidSession.capabilities.platformVersion)")

        case Platform.iOS.rawValue:
            // Find matching iOS session with the same platform version and UDID
            let matchingSession = sessions.1.first { iOSSession in
                iOSSession.capabilities.platformVersion
                    == device.platformVersion
                    && iOSSession.capabilities.udid == device.udid
            }

            guard let iOSSession = matchingSession
            else {
                appiumLogger.warning(
                    "No matching iOS session found for version \(device.platformVersion) and UDID \(device.udid ?? "unknown")"
                )
                return nil
            }
            appiumLogger.info(
                "Found matching iOS session: \(iOSSession.id) for version \(device.platformVersion)"
            )
            session = Session(
                client: client, id: iOSSession.id, driver: device,
                deviceName: iOSSession.capabilities.udid
            )

        case Platform.browser.rawValue:
            guard let webSession = sessions.2.first,
                let sessionId = webSession.sessionId
            else {
                appiumLogger.warning("No matching browser session found")
                return nil
            }
            appiumLogger.info(
                "Found matching \(device.automationName) session: \(sessionId)"
            )
            session = Session(
                client: client, id: sessionId, driver: device,
                deviceName: webSession.capabilities.browserName)
        default:
            guard let webSession = sessions.2.first,
                let sessionId = webSession.sessionId
            else {
                appiumLogger.warning("No matching browser session found")
                return nil
            }
            appiumLogger.info(
                "Found matching \(device.automationName) session: \(sessionId)"
            )
            session = Session(
                client: client, id: sessionId, driver: device,
                deviceName: webSession.capabilities.browserName)
        }

        return session
    }
    
    func findSessions(
        client: HTTPClient,
    ) async throws -> (
        [AndroidResponse.ResponseValue],
        [iOSResponse.Value],
        [WebResponse.Session]
    ) {
        
        appiumLogger.info("Requesting active sessions...")

        var request = try HTTPClient.Request(
            url: API.sessions.path, method: .GET)
            request.headers.add(name: "Content-Type", value: "application/json")

        let response = try await client.execute(request: request).get()
        appiumLogger.info("Received response with status: \(response.status)")
        guard let byteBuffer = response.body else {
            throw NSError(
                domain: "Appium",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No response body"]
            )
        }
        guard
            let body = byteBuffer.getString(
                at: 0, length: byteBuffer.readableBytes)
        else {
            throw NSError(
                domain: "Appium",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Cannot read response body"
                ]
            )
        }

        let sessionListResponse = try JSONDecoder().decode(
            SessionResponse.self, from: Data(body.utf8))

        // Separate Android, iOS and Web sessions
        let androidSessions = sessionListResponse.value.filter {
            $0.capabilities.platformName?.lowercased() == "android"
        }
        let iOSSessions = sessionListResponse.value.filter {
            $0.capabilities.platformName?.lowercased() == "ios"
        }
        let webSessions = sessionListResponse.value.filter {
            $0.capabilities.browserName != nil
        }

        if androidSessions.isEmpty {
            appiumLogger.info("No active Android sessions found.")
        } else {
            appiumLogger.info(
                "Returning active Android sessions... \(androidSessions)")
        }

        if iOSSessions.isEmpty {
            appiumLogger.info("No active iOS sessions found.")
        } else {
            appiumLogger.info("Returning active iOS sessions... \(iOSSessions)")
        }

        if webSessions.isEmpty {
            appiumLogger.info("No active Web sessions found.")
        } else {
            appiumLogger.info("Returning active Web sessions... \(webSessions)")
        }
        return (
            androidSessions.map { AndroidResponse.ResponseValue(from: $0) },
            iOSSessions.map { iOSResponse.Value(from: $0) },
            webSessions.map { WebResponse.Session(from: $0) }
        )
    }
}
