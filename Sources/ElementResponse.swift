//
//  ElementResponse.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

struct ElementResponse: Codable {
    let value: ElementValue

    struct ElementValue: Codable {
        let elementId: String

        private enum CodingKeys: String, CodingKey {
            case elementId = "ELEMENT"
        }
    }
}
