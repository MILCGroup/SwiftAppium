//
//  TestModel.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import AsyncHTTPClient
import Foundation
import Testing
import Observation

@Observable
public class TestModel: @unchecked Sendable {
    public let client: Client
    public let device: Driver
    public let sessionModel: SessionModel
    
    public init(_ device: Driver) async throws {
        self.client = Client()
        self.device = device
        self.sessionModel = try await SessionModel(client: client.client, device: device)
    }
    
    public var session: SessionModel {
        return sessionModel
    }
}
