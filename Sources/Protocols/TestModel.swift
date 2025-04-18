//
//  TestModel.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

public protocol TestModel: Normalizable {
    var clientModel: ClientModel { get }
    var sessionModel: SessionModel { get }
    var elementModel: ElementModel { get }
}
