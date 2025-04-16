//
//  ClientModel.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import Foundation

public class ClientModel: AppiumClient {
    public init() {}
    
    public func waitForElement(
        _ session: Session,
        _ element: Element,
        timeout: TimeInterval
    ) async throws -> String {
        return try await Client.waitForElement(
            session,
            element,
            timeout: timeout
        )
    }
    
    public func findElement(
        _ session: Session,
        _ element: Element
    ) async throws -> String? {
        return try await Client.findElement(
            session,
            element
        )
    }
    
    public func containsInHierarchy(
        _ session: Session,
        contains text: String
    ) async throws -> Bool {
        return try await Client.containsInHierarchy(
            session,
            contains: text
        )
    }
    
    public func checkElementVisibility(
        _ session: Session,
        _ element: Element
    ) async throws -> Bool {
        return try await Client.checkElementVisibility(
            session,
            element
        )
    }
    
    public func executeScript(
        _ session: Session,
        script: String,
        args: [Any]
    ) async throws -> Any? {
        return try await Client.executeScript(
            session,
            script: script,
            args: args
        )
    }
    
    public func hideKeyboard(
        _ session: Session
    ) async throws {
        try await Client.hideKeyboard(session)
    }
    
    public func clickElement(
        _ session: Session,
        _ element: Element,
        _ wait: TimeInterval = 5
    ) async throws {
        try await Client.clickElement(
            session,
            element,
            wait
        )
    }
    
    public func sendKeys(
        _ session: Session,
        _ element: Element,
        text: String
    ) async throws {
        try await Client.sendKeys(
            session,
            element,
            text: text
        )
    }
}
