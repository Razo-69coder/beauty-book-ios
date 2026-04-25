// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BeautyBook",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .executable(
            name: "BeautyBook",
            targets: ["App"]
        )
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [],
            path: "."
        )
    ]
)