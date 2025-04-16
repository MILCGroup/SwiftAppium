//
//  Selector.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

public struct Selector: Sendable {
    public let wrappedValue: String
    
    public init(_ wrappedValue: String) {
        self.wrappedValue = wrappedValue
    }
}
