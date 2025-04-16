//
//  Element.swift
//  SwiftAppium
//
//  Created by Dalton Alexandre on 4/15/25.
//

import Foundation

public struct Element {
    public let strategy: Strategy
    public let selector: Selector
    
    public init(_ strategy: Strategy,_ selector: Selector) {
        self.strategy = strategy
        self.selector = selector
    }
}

public struct Selector {
    public let wrappedValue: String
    
    public init(_ wrappedValue: String) {
        self.wrappedValue = wrappedValue
    }
}
