// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FolderPeek",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "FolderPeekCore", targets: ["FolderPeekCore"])
    ],
    targets: [
        .target(
            name: "FolderPeekCore",
            path: "FolderPeek/Shared"
        )
    ]
)
