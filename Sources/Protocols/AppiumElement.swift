//
//  AppiumElement.swift
//  SwiftAppium
//
//  Created by Dalton Alexandre on 4/18/25.
//

import Foundation

public protocol AppiumElement {
    func waitForElement(
        _ session: Session,
        _ element: Element,
        timeout: TimeInterval
    ) async throws -> String
    
    func findElement(
        _ session: Session,
        _ element: Element
    ) async throws -> String?
    
    func elementValue(
        _ session: Session,
        _ element: Element
    ) async throws -> Double
    
    func checkElementVisibility(
        _ session: Session,
        _ element: Element
    ) async throws -> Bool
    
    func checkElementChecked(
        _ session: Session,
        _ element: Element
    ) async throws -> Bool
    
    func clickElement(
        _ session: Session,
        _ element: Element,
        _ wait: TimeInterval
    ) async throws
    
    func clickUnsafeElement(
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
