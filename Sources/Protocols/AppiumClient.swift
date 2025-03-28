//
//  AppiumClient.swift
//  SwiftAppium
//
//  Created by Dalton Alexandre on 3/28/25.
//

import Foundation

public protocol AppiumClient {
    func waitForElement(
        _ session: Session,
        strategy: Strategy,
        selector: String,
        timeout: TimeInterval
    ) async throws -> String
    
    func findElement(
        _ session: Session,
        strategy: Strategy,
        selector: String
    ) async throws -> String?
    
    func containsInHierarchy(
        _ session: Session,
        contains text: String
    ) async throws -> Bool
    
    func checkElementVisibility(
        _ session: Session,
        strategy: Strategy,
        selector: String
    ) async throws -> Bool
    
    func executeScript(
        _ session: Session,
        script: String,
        args: [Any]
    ) async throws -> Any?
    
    func hideKeyboard(
        _ session: Session
    ) async throws
    
    func clickElement(
        _ session: Session,
        strategy: Strategy,
        selector: String,
        _ wait: TimeInterval
    ) async throws
    
    func sendKeys(
        _ session: Session,
        strategy: Strategy,
        selector: String,
        text: String
    ) async throws
}
