//
//  Session.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import AsyncHTTPClient

public struct Session: Sendable {
    @MainActor private static var sharedWeb = Session(id: "", platform: .browser)
    public static let sharedAndroid = Session(id: "", platform: .android)
    public static let sharediOS = Session(id: "", platform: .iOS)
    
    public let client: HTTPClient
    public var id: String
    public let platform: Platform
    public let deviceName: String

    public init(client: HTTPClient = HTTPClient(eventLoopGroupProvider: .singleton), id: String, platform: Platform) {
        self.client = client
        self.id = id
        self.platform = platform
        self.deviceName = ""
    }

    public init(
        client: HTTPClient, id: String, device: Device, deviceName: String?
    ) {
        self.client = client
        self.id = id
        self.platform = device.platform
        self.deviceName = device.deviceName ?? ""
    }
    
}
