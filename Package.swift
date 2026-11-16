// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ColaySDK",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [
        .library(name: "ColaySDK", targets: ["ColaySDK"]),
    ],
    targets: [
        .target(
            name: "ColaySDK",
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")]
        ),
        .testTarget(name: "ColaySDKTests", dependencies: ["ColaySDK"]),
    ]
)
