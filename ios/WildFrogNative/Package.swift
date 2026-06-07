// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WildFrogNative",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .executable(name: "WildFrogNative", targets: ["WildFrogNative"]),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.0.0"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS.git", from: "9.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "WildFrogNative",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
            ],
            exclude: [
                "Info.plist",
                "WildFrogNative.entitlements",
            ],
            resources: [
                .process("Assets.xcassets"),
                .copy("GoogleService-Info.plist"),
            ]
        ),
    ]
)
