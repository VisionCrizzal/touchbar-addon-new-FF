// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "touchbar-browser-helper",
  platforms: [
    .macOS(.v13),
  ],
  products: [
    .executable(
      name: "touchbar-browser-helper",
      targets: ["touchbar-browser-helper"]
    ),
  ],
  targets: [
    .target(
      name: "CTouchBar",
      path: "Sources/CTouchBar",
      publicHeadersPath: "include",
      linkerSettings: [
        .unsafeFlags(["-F", "/System/Library/PrivateFrameworks", "-framework", "DFRFoundation"]),
        .linkedFramework("AppKit"),
      ]
    ),
    .executableTarget(
      name: "touchbar-browser-helper",
      dependencies: ["CTouchBar"],
      path: "Sources/touchbar-browser-helper",
      linkerSettings: [
        .unsafeFlags(["-F", "/System/Library/PrivateFrameworks", "-framework", "DFRFoundation"]),
        .linkedFramework("AppKit"),
      ]
    ),
  ]
)
