// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotepadMac",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "NotepadMac", targets: ["NotepadMac"])],
    targets: [
        .target(name: "NotepadCore"),
        .executableTarget(name: "NotepadMac", dependencies: ["NotepadCore"]),
        .executableTarget(name: "NotepadUpdater", dependencies: ["NotepadCore"]),
        .executableTarget(name: "CoreChecks", dependencies: ["NotepadCore"], path: "Tests/NotepadCoreTests")
    ]
)
