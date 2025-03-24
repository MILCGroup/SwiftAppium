//
//  ElementResponse.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

public struct ElementResponse: Codable {
    public let value: ElementValue

    public struct ElementValue: Codable {
        public let elementId: String

        public enum CodingKeys: String, CodingKey {
            case elementId = "ELEMENT"
        }
    }
}
