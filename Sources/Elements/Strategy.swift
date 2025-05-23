//
//  Strategy.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

public enum Strategy: String, Sendable {
    case accessibilityId = "accessibility id"
    case className = "class name"
    case cssSelector = "css selector"
    case id = "id"
    case iOSClassChain = "-ios class chain"
    case iOSPredicateString = "-ios predicate string"
    case androidDataMatcher = "-android datamatcher"
    case androidViewMatcher = "-android viewmatcher"
    case androidUIAutomator = "-android uiautomator"
    case androidViewTag = "-android viewtag"
    case text = "text"
    case xpath = "xpath"
}
