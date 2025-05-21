//
//  Wait.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

#if os(Linux)
import Glibc
let NSEC_PER_SEC = 1_000_000_000
#else
import Darwin
#endif
import Foundation

public struct Wait: Flexible {
    public static let searchAgainDelay: UInt64 = 3
    public static let maxRetries = 5
    public static let retryDelay: TimeInterval = 0.2

    public static func sleep(for duration: UInt64) async {
        do {
            for remaining in stride(from: duration, to: 0, by: -1) {
                testLogger.info("Sleeping for \(remaining) more second(s)...")
                try await Task.sleep(nanoseconds: NSEC_PER_SEC)
            }
        } catch {
            appiumLogger.error("Error sleeping: \(error)")
        }
    }
}
