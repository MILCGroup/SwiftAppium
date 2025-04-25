import AsyncHTTPClient
import SwiftAppium
import Testing
import Foundation

@Suite("SwiftAppium Test", .tags(.device.browser.chrome), .serialized, .server("http://10.172.1.157:4723"), .exampleDevice(.chrome)) struct WebTest {
    @Test("[Feed] Sessions") func addTestSessionInFeed() async throws {
        try await Environment.test.navigate("https://www.milcgroup.com")
    }
}
