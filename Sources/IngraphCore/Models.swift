// ingraph/Sources/IngraphCore/Models.swift
import Foundation

public struct Device: Identifiable, Codable, Sendable {
    public let id: String
    public let serialNumber: String
    public let userPrincipalName: String?
}

public enum MDMCommand: String, CaseIterable, Identifiable, Sendable {
    case sync           = "sync"
    case reboot         = "reboot"
    case retire         = "retire"
    case wipe           = "wipe"
    case scanDefender   = "scandefender"
    case customScript   = "custom"

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .sync: return "Sync device"
        case .reboot: return "Restart device"
        case .retire: return "Retire"
        case .wipe: return "Wipe"
        case .scanDefender: return "Run Defender scan"
        case .customScript: return "Custom script"
        }
    }
}