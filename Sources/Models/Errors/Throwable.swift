//
//  Throwable.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import Foundation

public protocol Throwable: LocalizedError {
    var userFriendlyMessage: String { get }
}

extension Throwable {
    public var errorDescription: String? {
        userFriendlyMessage
    }
}
