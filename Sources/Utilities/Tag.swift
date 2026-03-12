//
//  Tag.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import Testing

extension Tag {
    public enum device {}

    /// Test has specific infrastructure needs unlikely to be present outside of central CI
    @Tag public static var infra: Tag
}

extension Tag.device {
    @Tag public static var android: Tag
    @Tag public static var iOS: Tag
    public enum browser {}
}

extension Tag.device.browser {
    @Tag public static var chrome: Tag
    @Tag public static var safari: Tag
}
