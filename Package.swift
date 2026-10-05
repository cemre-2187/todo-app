// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MacTodo",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "MacTodo", path: "Sources/MacTodo")
    ]
)
