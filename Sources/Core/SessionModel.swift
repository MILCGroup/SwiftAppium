//
//  SessionModel.swift
//  SwiftAppium
//
//  Created by Dalton Alexandre on 4/18/25.
//


import Foundation

public class SessionModel: AppiumSession {
    public init() {}
    
    public func executeScript(
        _ session: Session,
        script: String,
        args: [Any]
    ) async throws -> Any? {
        return try await Session.executeScript(
            session,
            script: script,
            args: args
        )
    }
    
    public func hideKeyboard(
        _ session: Session
    ) async throws {
        try await Session.hideKeyboard(session)
    }
}
