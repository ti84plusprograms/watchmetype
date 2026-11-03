// swift-tools-version: 5.9
import PackageDescription

// Pure Swift regression harness for code insertion and line-aware diffing.
// The macOS application itself continues to build from the Xcode project.
let package = Package(
    name: "WatchMeTypeCodeCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodeModeCore", targets: ["CodeModeCore"])
    ],
    targets: [
        .target(
            name: "CodeModeCore",
            path: "Watch Me Type",
            sources: ["CodeInputCore.swift", "PythonSyntaxHighlighter.swift"]
        ),
        .testTarget(
            name: "CodeModeCoreTests",
            dependencies: ["CodeModeCore"],
            path: "CodeModeCoreTests"
        )
    ]
)
