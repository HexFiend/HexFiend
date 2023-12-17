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
            targets: [
                "HexFiendObjC",
            ]),
    ],
    targets: [
        .target(
            name: "HexFiendCoreObjC",
            path: "framework",
            exclude: [
                "include/HFPrivilegedHelperConnection.h",
            ],
            sources: [
                "sources/HFFunctions.m",
            ],
            cSettings: [
                .define("HF_NO_PRIVILEGED_FILE_OPERATIONS", to: "1")
            ]),
        .target(
            name: "HexFiendSwift",
            dependencies: [
                "HexFiendCoreObjC",
            ],
            path: "framework",
            sources: [
                "sources/HFByteTheme.swift",
            ],
            cSettings: [
                .define("HF_NO_PRIVILEGED_FILE_OPERATIONS", to: "1")
            ]),
        .target(
            name: "HexFiendObjC",
            dependencies: [
                "HexFiendSwift",
            ],
            path: "framework",
            exclude: [
                "sources/BTree/BTree_Testing/",
                "sources/HFByteTheme.swift",
                "sources/HFFunctions.m",
                "sources/HFPrivilegedHelperConnection.m",
                "tests",
            ],
            resources: [
                .process("resources/HFModalProgress.xib"),
            ],
            cSettings: [
                .define("HF_NO_PRIVILEGED_FILE_OPERATIONS", to: "1")
            ]),
    ]
)
