import Testing
import AsyncHTTPClient
import Foundation
import SwiftAppium

public class ExampleTest: @unchecked Sendable, Normalizable {
    public let client: Client!
    public var sessionModel: SessionModel!
    public var device: Driver
    
    public init(_ device: Driver) async throws {
        self.client = Client()
        self.device = device
        self.sessionModel = try await SessionModel(client: client.client, device: device)
    }
    
    public var test: ExampleTest {
        guard let currentTest = Environment.test else {
            fatalError("MILCTest instance not found in environment. Trait not applied correctly?")
        }
        return currentTest
    }
    
    func sessionCall(client: HTTPClient) async throws -> SessionModel {
        return try await SessionModel(client: client, device: device)
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
    
    public func navigate(
        _ url: String
    ) async throws {
        if !(try await getCurrentUrl())
            .hasPrefix(url)
        {
            let navigatePayload = ["url": url]
            let requestBody = try JSONSerialization.data(
                withJSONObject: navigatePayload, options: [])
            let normalizedData = try Self.normalizeJSON(requestBody)
            let expectedRequest = "{\"url\":\"\(url)\"}"
            do {
                try #require(normalizedData == expectedRequest)
            } catch {
                try await client.client.shutdown()
            }
            let url = "\(API.serverURL)/session"
            let expectedURL = "\(API.serverURL)/session"
            do {
                try #require(url == expectedURL)
            } catch {
                try await client.client.shutdown()
            }

            var request = try HTTPClient.Request(url: url, method: .POST)
            request.headers.add(name: "Content-Type", value: "application/json")
            request.body = .data(requestBody)
            let response = try await sessionModel.client.execute(request: request)
                .get()
            #expect(response.status == .ok)
        }
    }
    
    public func getCurrentUrl(
    ) async throws -> String {
        let request = try HTTPClient.Request(
            url: API.url(sessionModel.id),
            method: .GET
        )

        let response = try await sessionModel.client.execute(request: request).get()
        guard let body = response.body else {
            throw NSError(
                domain: "Appium",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No response body"]
            )
        }

        guard let bodyString = body.getString(at: 0, length: body.readableBytes)
        else {
            throw NSError(
                domain: "Appium",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Cannot read response body"
                ]
            )
        }

        let urlResponse = try JSONDecoder().decode(
            URLResponse.self, from: Data(bodyString.utf8))
        return urlResponse.value
    }

}
