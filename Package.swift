// swift-tools-version: 6.2
import PackageDescription

// FloatingTabBar: a Liquid Glass tab bar that floats over the pages. At compact width it is a
// pill of the pinned tabs whose last slot grows into a menu of every tab; at regular width it
// stands up at the side of the pages. A finger slides across either with the highlight riding
// under it (Scrub, usable on its own).
let package = Package(
  name: "FloatingTabBar",
  platforms: [.iOS(.v26)],
  products: [
    .library(name: "FloatingTabBar", targets: ["FloatingTabBar"]),
  ],
  targets: [
    .target(name: "FloatingTabBar"),
    .testTarget(name: "FloatingTabBarTests", dependencies: ["FloatingTabBar"]),
  ],
  swiftLanguageModes: [.v6]
)
