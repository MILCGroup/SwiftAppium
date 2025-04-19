//
//  Client+Element.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import AsyncHTTPClient
import Observation

@Observable
public class Client: @unchecked Sendable {
    let client: HTTPClient
    
    public init() {
        self.client = HTTPClient(eventLoopGroupProvider: .singleton)
    }
}
