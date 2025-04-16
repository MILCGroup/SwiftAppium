//
//  Element.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

public struct Element: Sendable {
    public let strategy: Strategy
    public let selector: Selector
    
    public init(_ strategy: Strategy,_ selector: Selector) {
        self.strategy = strategy
        self.selector = selector
    }
}
