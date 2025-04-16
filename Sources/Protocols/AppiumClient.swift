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
        _ element: Element,
        timeout: TimeInterval
    ) async throws -> String
    
    func findElement(
        _ session: Session,
        _ element: Element
    ) async throws -> String?
    
    func containsInHierarchy(
        _ session: Session,
        contains text: String
    ) async throws -> Bool
    
    func checkElementVisibility(
        _ session: Session,
        _ element: Element
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
        _ element: Element,
        _ wait: TimeInterval
    ) async throws
    
    func sendKeys(
        _ session: Session,
        _ element: Element,
        text: String
    ) async throws
}
