// swift-tools-version:5.9
import PackageDescription

// Platform-independent logic shared by the OBD Live app: channel table, OBD-II reply parsing,
// the Freematics BLE command framing and the demo-data simulator. Builds and tests on macOS and Linux.
let package = Package(
    name: "OBDCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "OBDCore", targets: ["OBDCore"])],
    targets: [
        .target(name: "OBDCore"),
        .testTarget(name: "OBDCoreTests", dependencies: ["OBDCore"]),
    ]
)
