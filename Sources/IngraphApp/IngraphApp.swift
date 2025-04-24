// ingraph/Sources/IngraphApp/IngraphApp.swift
import SwiftUI
import IngraphCore

@main
struct IngraphApp: App {
    @StateObject private var vm = ContentViewModel()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(vm)
        }
    }
}