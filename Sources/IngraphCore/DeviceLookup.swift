// ingraph/Sources/IngraphCore/DeviceLookup.swift

public enum DeviceLookup {
    public static func serials(_ list: [String]) async throws -> [Device] {
        try await GraphAPIClient.shared.lookup(serials: list)
    }
}
