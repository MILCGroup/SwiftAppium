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
        return try await Element.select(
            session,
            element,
            timeout: timeout
        )
    }
    
    public func findElement(
        _ session: Session,
        _ element: Element
    ) async throws -> String? {
        return try await Element.selectUnsafe(
            session,
            element
        )
    }
    
    public func elementValue(
        _ session: Session,
        _ element: Element
    ) async throws -> Double {
        return try await Element.value(
            session,
            element
        )
    }
    
    public func checkElementVisibility(
        _ session: Session,
        _ element: Element
    ) async throws -> Bool {
        return try await Element.isVisible(
            session,
            element
        )
    }
    
    public func checkElementChecked(
        _ session: Session,
        _ element: Element
    ) async throws -> Bool {
        return try await Element.isChecked(
            session,
            element
        )
    }
    
   
    public func clickElement(
        _ session: Session,
        _ element: Element,
        _ wait: TimeInterval = 5
    ) async throws {
        try await Element.click(
            session,
            element,
            wait
        )
    }
    
    public func clickUnsafeElement(
        _ session: Session,
        _ element: Element,
        _ wait: TimeInterval = 5
    ) async throws {
        try await Element.clickUnsafe(
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
        try await Element.type(
            session,
            element,
            text: text
        )
    }
}
