// ingraph/Sources/IngraphCLI/main.swift
import Foundation   // FileHandle & exit()
import Darwin       // fputs / stderr
import IngraphCore

@main
struct IngraphUtil {

    // MARK: – CLI help
    static func usage() -> Never {
        fputs("""
        usage:
          ingraphutil --login
              ⟶ opens interactive browser window once, caches token

          ingraphutil <sync|reboot|retire|wipe|scandefender> <serial[,serial…]>

        """, stderr)
        exit(1)
    }

    // MARK: – entry‑point
    static func main() async {
        var args = Array(CommandLine.arguments.dropFirst())
        guard args.isEmpty == false else { usage() }

        // --- optional one‑time login ----------------------------------------
        if args.first == "--login" {
            args.removeFirst()
            do {
                // Use token() to force interactive login if needed
                _ = try await GraphAPIClient.shared.token()
                print("✅  Login successful – token cached in Keychain.")
                exit(0)
            } catch {
                fputs("error: \(error)\n", stderr)
                exit(2)
            }
        }

        // --- normal command -------------------------------------------------
        guard args.count == 2,
              let cmd = MDMCommand(rawValue: args[0]) else { usage() }

        let serials = args[1].split(separator: ",").map(String.init)

        do {
            let devices = try await DeviceLookup.serials(serials)
            try await GraphAPIClient.shared.perform(cmd, on: devices)
            print("OK (\(devices.count) device\(devices.count == 1 ? "" : "s"))")
        } catch {
            fputs("error: \(error)\n", stderr)
            exit(2)
        }
    }
}