//
//  Wait.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

public struct Wait: Flexible {
    public static let searchAgainDelay: UInt64 = 3
    public static let maxRetries = 5
    public static let retryDelay: UInt64 = 5

    public static func sleep(for duration: UInt64) async throws {
        for remaining in stride(from: duration, to: 0, by: -1) {
            testLogger.info("Sleeping for \(remaining) more second(s)...")
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
}
