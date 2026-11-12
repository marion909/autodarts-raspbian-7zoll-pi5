import AppKit
import AutodartsControlCore
import SwiftUI

@main
struct AutodartsControlApp: App {
    @StateObject private var pi = PiController()

    var body: some Scene {
        Window("Autodarts Control", id: "main") {
            RootView()
                .environmentObject(pi)
        }
        .defaultSize(width: 880, height: 640)

        MenuBarExtra {
            MenuBarContent()
                .environmentObject(pi)
        } label: {
            Image(systemName: pi.menuBarSymbol)
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuBarContent: View {
    @EnvironmentObject var pi: PiController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Autodarts Control öffnen") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Divider()

        if pi.isConnected, let status = pi.status {
            Text("\(status.hostname) · \(status.ips.first ?? "")")
            Text("AutoDarts \(status.autodartsVersion.isEmpty ? "–" : status.autodartsVersion) · \(status.autodartsRunning ? "läuft" : "gestoppt")")
            if let temp = status.temperatureC {
                Text("CPU \(temp, specifier: "%.0f") °C")
            }
            if status.throttled?.hasActiveProblem == true {
                Text("⚠︎ Unterspannung/Drosselung aktiv")
            }

            Divider()

            Button("AutoDarts-Weboberfläche öffnen") { pi.openWebUI() }
            Button("AutoDarts neu starten") { Task { await pi.restartApp() } }
                .disabled(pi.isBusy)
            Button("Kiosk neu starten") { Task { await pi.restartKiosk() } }
                .disabled(pi.isBusy)
        } else {
            switch pi.connection {
            case .connecting, .idle: Text("Verbinde …")
            case .unreachable(let message): Text("Nicht erreichbar: \(message)")
            default: Text("Einrichtung erforderlich")
            }
            Button("Erneut verbinden") { Task { await pi.probe() } }
        }

        Divider()

        Button("Beenden") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
