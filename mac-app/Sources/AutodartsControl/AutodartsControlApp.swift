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
            if let symbol = pi.menuBarSymbol {
                Image(systemName: symbol)
            } else {
                Image(nsImage: BrandImages.menuBar)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Autodarts-Marke aus den App-Ressourcen (erzeugt mit tools/make-brand-assets.sh)
enum BrandImages {
    /// Template-Bild: macOS faerbt es passend zur Menueleiste ein
    static let menuBar: NSImage = {
        let image = NSImage(named: "MenuBarIcon")
            ?? NSImage(systemSymbolName: "scope", accessibilityDescription: "Autodarts")
            ?? NSImage()
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }()

    static let logo: NSImage? = NSImage(named: "Logo")
}

struct BrandLogo: View {
    var size: CGFloat = 72

    var body: some View {
        if let logo = BrandImages.logo {
            Image(nsImage: logo)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "scope")
                .font(.system(size: size * 0.6))
                .foregroundStyle(.tint)
                .frame(width: size, height: size)
        }
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
