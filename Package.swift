// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacPerf",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "MacPerf",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/MacPerf",
            linkerSettings: [
                .linkedFramework("IOKit"),
                // The binary ships inside MacPerf.app and must find
                // Sparkle.framework at Contents/Frameworks/. dyld searches
                // rpaths relative to the binary; without this the framework
                // only resolves when it happens to sit next to the binary
                // (which SPM-built apps don't do). build-dmg.sh embed_sparkle()
                // copies the framework into Contents/Frameworks/.
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        )
    ]
)
