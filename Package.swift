// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-ical",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(name: "ICalendar", targets: ["ICalendar"])
    ],
    targets: [
        .target(name: "ICalendar"),
        .testTarget(
            name: "ICalendarTests",
            dependencies: ["ICalendar"],
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
