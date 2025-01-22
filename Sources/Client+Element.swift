//
//  Client+Element.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import AsyncHTTPClient
import Foundation

public struct Client {
    public static func isElementSelected(
        client: HTTPClient, sessionId: String, elementId: String
    ) async throws -> Bool {
        appiumLogger.info(
            "Checking if element: \(elementId) is selected in session: \(sessionId)"
        )
        var request = try HTTPClient.Request(
            url: API.selected(elementId, sessionId).path,
            method: .GET
        )
        request.headers.add(name: "Content-Type", value: "application/json")

        let response = try await client.execute(request: request).get()

        // Assuming the response body contains a JSON object with a "value" key
        guard let body = response.body,
            let json = try? JSONSerialization.jsonObject(
                with: body, options: []) as? [String: Any],
            let selected = json["value"] as? Bool
        else {
            throw NSError(domain: "InvalidResponse", code: 0, userInfo: nil)
        }

        return selected
    }

    public static func getElementText(
        client: HTTPClient, sessionId: String, elementId: String
    ) async throws -> String {
        appiumLogger.info(
            "Checking element text: \(elementId) in session: \(sessionId)"
        )
        var request = try HTTPClient.Request(
            url: API.text(elementId, sessionId).path,
            method: .GET
        )
        request.headers.add(name: "Content-Type", value: "application/json")

        let response = try await client.execute(request: request).get()

        // Assuming the response body contains a JSON object with a "value" key
        guard let body = response.body,
            let json = try? JSONSerialization.jsonObject(
                with: body, options: []) as? [String: Any],
            let text = json["value"] as? String
        else {
            throw NSError(domain: "InvalidResponse", code: 0, userInfo: nil)
        }

        return text
    }

    // MARK: Wait and Click Element
    public static func waitAndClickElement(
        _ client: HTTPClient,
        _ sessionId: String,
        strategy: Strategy,
        selector: String,
        timeout: Int = 2
    ) async throws {
        do {
            let elementId = try await waitForElement(
                client,
                sessionId: sessionId,
                strategy: strategy,
                selector: selector,
                timeout: TimeInterval(timeout)
            )

            try await clickElement(
                client: client,
                sessionId: sessionId,
                elementId: elementId
            )
            webLogger.info(
                "Found and clicked element with selector: \(selector)")
        } catch {
            webLogger.info("Element not found with selector: \(selector)")
        }
    }

    // MARK: Wait For Element
    public static func waitForElement(
        _ client: HTTPClient, sessionId: String, strategy: Strategy,
        selector: String, timeout: TimeInterval
    ) async throws -> String {
        let startTime = Date()
        var searchCount = 0
        while true {
            do {
                let elementFound = try await findElement(
                    client: client, sessionId: sessionId, strategy: strategy,
                    selector: selector
                )

                if let element = elementFound {
                    appiumLogger.info("Element \(element) found!")
                    return element
                }
            } catch {
                appiumLogger.info(
                    "searched \(searchCount) time\(searchCount == 1 ? "" : "s")"
                )
                searchCount += 1
            }

            if Date().timeIntervalSince(startTime) > timeout {
                throw NSError(
                    domain: "ElementNotFound", code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Timeout reached while waiting for element."
                    ]
                )
            }
            try await Wait.sleep(for: Wait.searchAgainDelay)
        }

        func findElement(
            client: HTTPClient, sessionId: String, strategy: Strategy,
            selector: String
        ) async throws -> String? {
            appiumLogger.info(
                "Trying to find element with strategy: \(strategy.rawValue) and selector: \(selector) in session: \(sessionId)"
            )

            let requestBody: Data
            do {
                requestBody = try JSONEncoder().encode(
                    [
                        "using": strategy.rawValue, "value": selector,
                    ]
                )
            } catch {
                throw NSError(
                    domain: "Appium", code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Failed to encode request body"
                    ]
                )
            }

            var request = try HTTPClient.Request(
                url: API.element(sessionId).path, method: .POST
            )
            request.headers.add(name: "Content-Type", value: "application/json")
            request.body = .data(requestBody)

            do {
                appiumLogger.info("Sending request to URL: \(request.url)")
                let response = try await client.execute(request: request).get()
                appiumLogger.info(
                    "Received response with status: \(response.status)")

                guard var byteBuffer = response.body else {
                    throw NSError(
                        domain: "Appium", code: -1,
                        userInfo: [
                            NSLocalizedDescriptionKey: "No response body"
                        ]
                    )
                }

                guard
                    let body = byteBuffer.readString(
                        length: byteBuffer.readableBytes)
                else {
                    throw NSError(
                        domain: "Appium", code: -1,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Cannot read response body"
                        ]
                    )
                }

                appiumLogger.info("Element response body: \(body)")

                let elementResponse = try JSONDecoder().decode(
                    ElementResponse.self, from: Data(body.utf8))
                return elementResponse.value.elementId
            } catch {
                appiumLogger.error(
                    "Failed to find element with strategy: \(strategy.rawValue) and selector: \(selector) - \(error.localizedDescription)"
                )
            }

            return nil
        }
    }

    // MARK: Click Element
    public static func clickElement(
        client: HTTPClient, sessionId: String, elementId: String
    )
        async throws
    {
        appiumLogger.info(
            "Clicking element: \(elementId) in session: \(sessionId)")
        var request = try HTTPClient.Request(
            url: API.click(elementId, sessionId).path,
            method: .POST)
        request.headers.add(name: "Content-Type", value: "application/json")
        _ = try await client.execute(request: request).get()
    }

    // MARK: Send Keys
    public static func sendKeys(
        client: HTTPClient, sessionId: String, elementId: String, text: String
    ) async throws {
        appiumLogger.info(
            "Sending keys to element: \(elementId) in session: \(sessionId) with text: \(text)"
        )
        let requestBody = try JSONEncoder().encode(["text": text])
        var request = try HTTPClient.Request(
            url: API.value(elementId, sessionId).path,
            method: .POST)
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = .data(requestBody)
        _ = try await client.execute(request: request).get()
    }

    // MARK: Log Element Hierarchy
    public static func logElementHierarchy(
        _ client: HTTPClient, sessionId: String
    )
        async
    {
        do {
            let request = try HTTPClient.Request(
                url: API.source(sessionId).path, method: .GET)
            let response = try await client.execute(request: request).get()
            if let body = response.body,
                let hierarchy = body.getString(
                    at: 0, length: body.readableBytes)
            {
                dump(
                    hierarchy, name: "\(sessionId) Element hierarchy", indent: 2
                )
                //  appiumLogger.info("\(sessionId) Element hierarchy:\n\(hierarchy)")
            } else {
                appiumLogger.info("Failed to retrieve element hierarchy")
            }
        } catch {
            appiumLogger.info(
                "Error while retrieving element hierarchy: \(error)")
        }
    }

    public static func findElement(
        client: HTTPClient, sessionId: String, strategy: Strategy,
        selector: String
    ) async throws -> String? {
        appiumLogger.info(
            "Trying to find element with strategy: \(strategy.rawValue) and selector: \(selector) in session: \(sessionId)"
        )

        let requestBody: Data
        do {
            requestBody = try JSONEncoder().encode(
                [
                    "using": strategy.rawValue, "value": selector,
                ]
            )
        } catch {
            throw NSError(
                domain: "Appium", code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Failed to encode request body"
                ]
            )
        }

        var request = try HTTPClient.Request(
            url: API.element(sessionId).path, method: .POST
        )
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = .data(requestBody)

        do {
            appiumLogger.info("Sending request to URL: \(request.url)")
            let response = try await client.execute(request: request).get()
            appiumLogger.info(
                "Received response with status: \(response.status)")

            guard var byteBuffer = response.body else {
                throw NSError(
                    domain: "Appium", code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "No response body"
                    ]
                )
            }

            guard
                let body = byteBuffer.readString(
                    length: byteBuffer.readableBytes)
            else {
                throw NSError(
                    domain: "Appium", code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Cannot read response body"
                    ]
                )
            }

            appiumLogger.info("Element response body: \(body)")

            let elementResponse = try JSONDecoder().decode(
                ElementResponse.self, from: Data(body.utf8))
            return elementResponse.value.elementId
        } catch {
            appiumLogger.error(
                "Failed to find element with strategy: \(strategy.rawValue) and selector: \(selector) - \(error.localizedDescription)"
            )
        }

        return nil
    }
}
