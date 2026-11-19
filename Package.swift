// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CleanBunsho",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "CleanBunshoCore", targets: ["CleanBunshoCore"]),
        .executable(name: "CleanBunsho", targets: ["CleanBunsho"]),
    ],
    targets: [
        // 文字処理（UI に依存しない。Windows 版へ移植するときの基準）
        .target(
            name: "CleanBunshoCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // メニューバー常駐アプリ本体
        .executableTarget(
            name: "CleanBunsho",
            dependencies: ["CleanBunshoCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "CleanBunshoCoreTests",
            dependencies: ["CleanBunshoCore"],
            resources: [.copy("Fixtures")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
