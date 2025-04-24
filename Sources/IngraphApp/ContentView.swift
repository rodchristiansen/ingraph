// ingraph/Sources/IngraphApp/ContentView.swift
import SwiftUI
import IngraphCore

@MainActor
final class ContentViewModel: ObservableObject {
    @Published var rawSerials = ""
    @Published var devices: [Device] = []
    @Published var selected: MDMCommand = .sync
    @Published var log: [String] = []

    func lookup() {
        Task { @MainActor in
            do {
                let serials = rawSerials
                    .split { $0 == "," || $0 == " " || $0 == "\n" }
                    .map(String.init)
                devices = try await DeviceLookup.serials(serials)
                log.append("Found \(devices.count) device(s)")
            } catch {
                log.append("Lookup error: \(error.localizedDescription)")
            }
        }
    }

    func execute() {
        Task { @MainActor in
            do {
                try await GraphAPIClient.shared.perform(selected, on: devices)
                log.append("Executed \(selected.displayName) on \(devices.count) device(s)")
            } catch {
                log.append("Exec error: \(error.localizedDescription)")
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var vm: ContentViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Serial numbers").bold()
            TextEditor(text: $vm.rawSerials)
                .font(.system(.body, design: .monospaced))
                .frame(height: 100)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder())
            Picker("Command", selection: $vm.selected) {
                ForEach(MDMCommand.allCases) { cmd in
                    Text(cmd.displayName).tag(cmd)
                }
            }.pickerStyle(MenuPickerStyle())
            HStack {
                Button("Lookup") { vm.lookup() }.disabled(vm.rawSerials.isEmpty)
                Button("Run") { vm.execute() }.disabled(vm.devices.isEmpty)
            }
            List(vm.devices) { d in
                HStack {
                    Text(d.serialNumber)
                    Spacer()
                    Text(d.userPrincipalName ?? "")
                        .foregroundStyle(.secondary)
                }
            }
            List(vm.log, id: \.self) { line in
                Text(line).font(.footnote).monospaced()
            }
        }
        .padding()
        .frame(minWidth: 600, minHeight: 600)
    }
}
