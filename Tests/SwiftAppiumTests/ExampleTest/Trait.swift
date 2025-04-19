import Testing
import SwiftAppium

public extension Trait where Self == ExampleSessionTrait {
    static func exampleDevice(_ device: Driver) -> Self {
        Self(device: device)
    }
}
