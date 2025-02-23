//
//  Testable.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import Testing

public protocol Parameter: Codable, CaseIterable, CustomTestStringConvertible, Sendable {}
