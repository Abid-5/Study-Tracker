// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StudyTracker",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "StudyTracker", targets: ["StudyTracker"])
    ],
    targets: [
        .executableTarget(
            name: "StudyTracker",
            path: "Sources/StudyTracker"
        )
    ]
)
