import SwiftAppium
import Testing

public struct ExampleSessionTrait: TestTrait, SuiteTrait, TestScoping {
    let device: Driver

    public init(device: Driver) {
        self.device = device
    }

    public func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        let appiumTest = try await ExampleTest(device)
        
        try await Environment.$test.withValue(appiumTest) {
            appiumLogger.info("ExampleTest instance for \(device.deviceName ?? device.browserName ?? "unknown") provided via TaskLocal.")
            try await function()
            
            appiumLogger.info("Shutting down Appium client for \(device.deviceName ?? device.browserName ?? "unknown") after test scope.")
            try await appiumTest.client.client.shutdown()
        }
        appiumLogger.info("ExampleTest scope for \(device.deviceName ?? device.browserName ?? "unknown") finished.")
    }
}
