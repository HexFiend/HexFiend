// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "HexFiend",
    platforms: [
        .macOS(.v10_14),
    ],
    products: [
        .library(
            name: "HexFiend",
            targets: ["HexFiend"]),
    ],
    targets: [
        .target(
            name: "HexFiend",
            path: "framework",
            exclude: [
                "sources/BTree/BTree_Testing/",
                "sources/HFByteTheme.swift",
                "sources/HFPrivilegedHelperConnection.m",
                "tests",
            ],
            resources: [
                .process("resources/HFModalProgress.xib"),
            ],
            cSettings: [
                .define("HF_NO_PRIVILEGED_FILE_OPERATIONS", to: "1")
            ])
    ]
)
