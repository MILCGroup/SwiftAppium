//
//  AppiumSession.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import Foundation

public protocol AppiumSession {
    func executeScript(
        _ session: Session,
        script: String,
        args: [Any]
    ) async throws -> Any?
    
    func hideKeyboard(
        _ session: Session
    ) async throws
}
