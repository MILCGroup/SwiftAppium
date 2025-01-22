//
//  Strategy.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

public enum Strategy: String {
    case accessibilityId = "accessibility id"
    case className = "class name"
    case cssSelector = "css selector"
    case id = "id"
    case iOSClassChain = "-ios class chain"
    case iOSPredicateString = "-ios predicate string"
    case android = "-android uiautomator"
    case xpath = "xpath"
}
