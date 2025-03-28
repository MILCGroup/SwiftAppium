//
//  AppiumClientModel.swift
//  SwiftAppium
//
//  Created by Dalton Alexandre on 3/28/25.
//

import Foundation

public class AppiumClientModel: AppiumClient {
    private let session: Session
    
    public init(session: Session) {
        self.session = session
    }
    
    public func waitForElement(
        _ session: Session,
        strategy: Strategy,
        selector: String,
        timeout: TimeInterval
    ) async throws -> String {
        return try await Client.waitForElement(
            session,
            strategy: strategy,
            selector: selector,
            timeout: timeout
        )
    }
    
    public func findElement(
        _ session: Session,
        strategy: Strategy,
        selector: String
    ) async throws -> String? {
        return try await Client.findElement(
            session,
            strategy: strategy,
            selector: selector
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
        strategy: Strategy,
        selector: String
    ) async throws -> Bool {
        return try await Client.checkElementVisibility(
            session,
            strategy: strategy,
            selector: selector
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
        strategy: Strategy,
        selector: String,
        _ wait: TimeInterval
    ) async throws {
        try await Client.clickElement(
            session,
            strategy: strategy,
            selector: selector,
            wait
        )
    }
    
    public func sendKeys(
        _ session: Session,
        strategy: Strategy,
        selector: String,
        text: String
    ) async throws {
        try await Client.sendKeys(
            session,
            strategy: strategy,
            selector: selector,
            text: text
        )
    }
    
    // Convenience methods that use the stored session
    public func waitForElement(
        strategy: Strategy,
        selector: String,
        timeout: TimeInterval
    ) async throws -> String {
        return try await waitForElement(
            session,
            strategy: strategy,
            selector: selector,
            timeout: timeout
        )
    }
    
    public func findElement(
        strategy: Strategy,
        selector: String
    ) async throws -> String? {
        return try await findElement(
            session,
            strategy: strategy,
            selector: selector
        )
    }
    
    public func containsInHierarchy(
        contains text: String
    ) async throws -> Bool {
        return try await containsInHierarchy(
            session,
            contains: text
        )
    }
    
    public func checkElementVisibility(
        strategy: Strategy,
        selector: String
    ) async throws -> Bool {
        return try await checkElementVisibility(
            session,
            strategy: strategy,
            selector: selector
        )
    }
    
    public func executeScript(
        script: String,
        args: [Any]
    ) async throws -> Any? {
        return try await executeScript(
            session,
            script: script,
            args: args
        )
    }
    
    public func hideKeyboard() async throws {
        try await hideKeyboard(session)
    }
    
    public func clickElement(
        strategy: Strategy,
        selector: String,
        _ wait: TimeInterval = 5
    ) async throws {
        try await clickElement(
            session,
            strategy: strategy,
            selector: selector,
            wait
        )
    }
    
    public func sendKeys(
        strategy: Strategy,
        selector: String,
        text: String
    ) async throws {
        try await sendKeys(
            session,
            strategy: strategy,
            selector: selector,
            text: text
        )
    }
}
