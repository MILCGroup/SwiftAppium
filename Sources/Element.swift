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
}

public struct Selector {
    public let wrappedValue: String
}
