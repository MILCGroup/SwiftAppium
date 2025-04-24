//
//  ElementModel.swift
//  SwiftAppium
//
//  Created by Dalton Alexandre on 4/18/25.
//

import Foundation

public class ElementModel: AppiumElement {
    public init() {}
    
    public func waitForElement(
        _ session: Session,
        _ element: Element,
        timeout: TimeInterval
    ) async throws -> String {
        return try await session.select(
            element,
            timeout
        )
    }
    
    public func elementValue(
        _ session: Session,
        _ element: Element
    ) async throws -> Double {
        return try await session.value(
            element
        )
    }
    
    public func checkElementVisibility(
        _ session: Session,
        _ element: Element
    ) async throws -> Bool {
        return try await element.isVisible(
            session
        )
    }
    
    public func checkElementChecked(
        _ session: Session,
        _ element: Element
    ) async throws -> Bool {
        return try await element.isChecked(
            session
        )
    }
    
   
    public func clickElement(
        _ session: Session,
        _ element: Element,
        _ wait: TimeInterval = 5
    ) async throws {
        try await session.click(
            element,
            wait
        )
    }
    
    public func sendKeys(
        _ session: Session,
        _ element: Element,
        text: String
    ) async throws {
        try await session.type(
            element,
            text: text
        )
    }
}
