// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "RVWebServer",
    platforms: [.macOS(.v10_15)],
    products: [
        .library(
            name: "RVWebServer",
            targets: ["RVWebServer"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/robbiehanson/CocoaAsyncSocket",
                 from: "7.6.4")
    ],
    targets: [
        .target(
            name: "RVWebServer",
            dependencies: [
                "CocoaAsyncSocket"
            ],
            path: "Source",
            publicHeadersPath: "include"
        )
    ]
)
