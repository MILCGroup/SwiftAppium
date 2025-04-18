//
//  AppiumClient.swift
//  SwiftAppium
//
//  Created by Dalton Alexandre on 3/28/25.
//

public protocol AppiumClient {
    func containsInHierarchy(
        _ session: Session,
        contains text: String
    ) async throws -> Bool
    
    func containsMultipleInHierarchy(
        _ session: Session,
        contains times: Int, _ text: String
    ) async throws -> Bool
}
