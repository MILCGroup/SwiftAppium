//
//  AppiumError.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

public enum AppiumError: Throwable {
    case invalidResponse(String)
    case elementNotFound(String)
    case encodingError(String)
    case timeoutError(String)
    case notFound(String)

    public var userFriendlyMessage: String {
        switch self {
        case .invalidResponse(let message):
            return "Server returned an invalid response: \(message)"
        case .elementNotFound(let details):
            return "Could not find the requested element: \(details)"
        case .encodingError(let details):
            return "Failed to encode request data: \(details)"
        case .timeoutError(let details):
            return "Operation timed out: \(details)"
        case .notFound(let details):
            return "Resource not found: \(details)"
        }
    }
}
