//
//  Client+Hierarchy.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import AsyncHTTPClient
import Foundation

extension Client {
    public static func containsInHierarchy(
        _ session: Session,
        contains text: String
    ) async throws -> Bool {
        do {
            let request = try HTTPClient.Request(
                url: API.source(session.id),
                method: .GET
            )
            let response = try await session.client.execute(request: request)
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
                throw AppiumError.invalidResponse(
                    "Failed to get element hierarchy content"
                )
            }

            try await Wait.sleep(for: 1)
            return hierarchy.contains(text)

        } catch let error as AppiumError {
            appiumLogger.error("Error while checking hierarchy: \(error)")
            throw error
        } catch {
            appiumLogger.error(
                "Unexpected error while checking hierarchy: \(error)"
            )
            throw AppiumError.invalidResponse(
                "Failed to check hierarchy: \(error.localizedDescription)"
            )
        }
    }

    public static func containsMultipleInHierarchy(
        _ session: Session,
        contains times: Int,
        _ text: String
    ) async throws -> Bool {
        do {
            let request = try HTTPClient.Request(
                url: API.source(session.id),
                method: .GET
            )
            let response = try await session.client.execute(request: request)
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
                throw AppiumError.invalidResponse(
                    "Failed to get element hierarchy content"
                )
            }

            try await Wait.sleep(for: 1)
            let occurrences = hierarchy.components(separatedBy: text).count - 1
            return occurrences >= times

        } catch let error as AppiumError {
            appiumLogger.error("Error while checking hierarchy: \(error)")
            throw error
        } catch {
            appiumLogger.error(
                "Unexpected error while checking hierarchy: \(error)"
            )
            throw AppiumError.invalidResponse(
                "Failed to check hierarchy: \(error.localizedDescription)"
            )
        }
    }
}
