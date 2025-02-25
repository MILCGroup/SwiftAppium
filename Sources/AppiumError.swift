//
//  AppiumError.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

public enum AppiumError: Error {
    case invalidResponse(String)
    case elementNotFound(String)
    case encodingError(String)
    case timeoutError(String)
}
