//
//  Client+Element.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import AsyncHTTPClient

public class Client: @unchecked Sendable {
    public let client: HTTPClient
    
    public init() {
        self.client = HTTPClient(eventLoopGroupProvider: .singleton)
    }
}
