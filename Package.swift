// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "NetSwitch",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .executableTarget(
            name: "NetSwitch",
            path: "Sources"
        )
    ]
)
