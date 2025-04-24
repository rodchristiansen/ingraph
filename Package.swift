// Package.swift
// Created by Rod Christiansen on 2025-04-19.
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Ingraph",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Ingraph",     targets: ["IngraphApp"]),
        .executable(name: "ingraphutil", targets: ["IngraphCLI"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc.git",
            from: "1.2.0"
        )
    ],
    targets: [
        .target(
            name: "IngraphCore",
            dependencies: [
                .product(name: "MSAL", package: "microsoft-authentication-library-for-objc")
            ]
        ),
        .executableTarget(
            name: "IngraphApp",
            dependencies: ["IngraphCore"]
            //   resources: [.process("Resources")]  ← keep or delete per earlier note
        ),
        .executableTarget(
            name: "IngraphCLI",
            dependencies: ["IngraphCore"]
        )
    ]
)
