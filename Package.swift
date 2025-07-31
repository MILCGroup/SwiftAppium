// swift-tools-version: 6.0
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import PackageDescription

let package = Package(
    name: "SwiftAppium",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "SwiftAppium", targets: ["SwiftAppium"]),
        .executable(name: "swiftappium", targets: ["SwiftAppiumCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0")
    ],
    targets: [
        .target(
            name: "SwiftAppium",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client")
            ],
            path: "Sources",
            exclude: ["SwiftAppiumCLI", "Documentation.docc"]
        ),
        .executableTarget(
            name: "SwiftAppiumCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "AsyncHTTPClient", package: "async-http-client")
            ]
        ),
        .testTarget(
            name: "SwiftAppiumTests",
            dependencies: ["SwiftAppium"]
        )
    ]
)
