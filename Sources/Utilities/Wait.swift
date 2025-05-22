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
    public static let searchAgainDelay: Double = 3
    public static let maxRetries = 5
    public static let retryDelay: TimeInterval = 0.2

    public static func sleep(for seconds: Double) async {
        guard seconds > 0 else { return }

        do {
            let nanoseconds = UInt64(seconds * 1_000_000_000)
            testLogger.info("Sleeping for \(String(format: "%.2f", seconds)) \(seconds == 1 ? "second" : "seconds")...")
            try await Task.sleep(nanoseconds: nanoseconds)
            testLogger.info("Woke up after \(String(format: "%.2f", seconds)) \(seconds == 1 ? "second" : "seconds")")
        } catch {
            appiumLogger.error("Error sleeping: \(error)")
        }
    }
    
    public static func retry(for seconds: Double = retryDelay) async {
        guard seconds > 0 else { return }

        do {
            let nanoseconds = UInt64(seconds * 1_000_000_000)
            testLogger.info("Retrying in \(String(format: "%.2f", seconds)) \(seconds == 1 ? "second" : "seconds")...")
            try await Task.sleep(nanoseconds: nanoseconds)
        } catch {
            appiumLogger.error("Error retrying: \(error)")
        }
    }
}
