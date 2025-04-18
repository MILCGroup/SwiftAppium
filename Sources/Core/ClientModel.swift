//
//  ClientModel.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import Foundation

public class ClientModel: AppiumClient {
    public init() {}
    
    public func containsInHierarchy(
        _ session: Session,
        contains text: String
    ) async throws -> Bool {
        return try await Client.containsInHierarchy(
            session,
            contains: text
        )
    }
    
    public func containsMultipleInHierarchy(
        _ session: Session,
        contains times: Int, _ text: String
    ) async throws -> Bool {
        return try await Client.containsMultipleInHierarchy(
            session,
            contains: times, text
        )
    }
}
