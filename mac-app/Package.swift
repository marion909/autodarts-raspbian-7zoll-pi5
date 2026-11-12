// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AutodartsControl",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AutodartsControl", targets: ["AutodartsControl"]),
    ],
    targets: [
        // SSH-Anbindung, Parser und Validierung (ohne UI, testbar)
        .target(
            name: "AutodartsControlCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // SwiftUI-App (Fenster + Menüleiste)
        .executableTarget(
            name: "AutodartsControl",
            dependencies: ["AutodartsControlCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "AutodartsControlCoreTests",
            dependencies: ["AutodartsControlCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
