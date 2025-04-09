//
//  Session.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import AsyncHTTPClient

public struct Session: Sendable {
    public let client: HTTPClient
    public let id: String
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
