//
//  ExampleServerTrait.swift
//  SwiftAppium
//
//  Created by Dalton Alexandre on 4/25/25.
//

import Testing

public enum Environment {
    @TaskLocal public static var api: API!
}

public extension Trait where Self == SessionServerTrait {
    static func server(_ url: String) -> Self {
        Self(serverURL: url)
    }
}

public struct SessionServerTrait: SuiteTrait, TestScoping {
    public let serverURL: String

    public init(serverURL: String = "http://localhost:4723") {
        self.serverURL = serverURL
    }

    public func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        let appiumTest = API(serverURL)
        
        try await Environment.$api.withValue(appiumTest) {
            try await function()
        }
    }
}

