// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacPerf",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacPerf",
            path: "Sources/MacPerf",
            linkerSettings: [
                .linkedFramework("IOKit"),
            ]
        )
    ]
)
