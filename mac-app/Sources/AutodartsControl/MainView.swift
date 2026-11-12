import AppKit
import AutodartsControlCore
import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case overview, display, bluetooth, updates, logs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Übersicht"
        case .display: return "Display"
        case .bluetooth: return "Bluetooth"
        case .updates: return "Updates"
        case .logs: return "Logs"
        }
    }

    var symbol: String {
        switch self {
        case .overview: return "gauge.with.dots.needle.67percent"
        case .display: return "display"
        case .bluetooth: return "speaker.wave.2"
        case .updates: return "arrow.triangle.2.circlepath"
        case .logs: return "doc.text"
        }
    }
}

struct MainView: View {
    @EnvironmentObject var pi: PiController
    @State private var selection: SidebarItem? = .overview

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: 170)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pi.status?.hostname ?? pi.host).font(.caption.bold())
                    Text("\(pi.user)@\(pi.host)").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
            }
        } detail: {
            Group {
                switch selection ?? .overview {
                case .overview: OverviewView()
                case .display: DisplayView()
                case .bluetooth: BluetoothView()
                case .updates: UpdatesView()
                case .logs: LogsView()
                }
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        Task { await pi.refreshStatus() }
                    } label: {
                        Label("Aktualisieren", systemImage: "arrow.clockwise")
                    }
                    .help("Status neu laden")
                }
            }
        }
    }
}

// MARK: - Übersicht

struct OverviewView: View {
    @EnvironmentObject var pi: PiController
    @State private var confirmReboot = false
    @State private var confirmShutdown = false

    var body: some View {
        Form {
            if let status = pi.status {
                Section("Raspberry Pi") {
                    LabeledContent("Name", value: status.hostname)
                    LabeledContent("IP-Adresse", value: status.ips.isEmpty ? "–" : status.ips.joined(separator: ", "))
                    if !status.model.isEmpty { LabeledContent("Modell", value: status.model) }
                    LabeledContent("System", value: status.os.isEmpty ? "–" : status.os)
                    LabeledContent("Laufzeit", value: Format.uptime(status.uptimeSeconds))
                    LabeledContent("CPU-Temperatur", value: status.temperatureC.map { String(format: "%.1f °C", $0) } ?? "–")
                    LabeledContent("Arbeitsspeicher", value: Format.memory(used: status.memUsedMB, total: status.memTotalMB))
                    LabeledContent("Speicher belegt", value: status.diskUsed.isEmpty ? "–" : status.diskUsed)
                }

                Section("Stromversorgung") {
                    PowerRow(throttled: status.throttled)
                }

                Section("AutoDarts") {
                    LabeledContent("Version", value: status.autodartsVersion.isEmpty ? "nicht installiert" : status.autodartsVersion)
                    LabeledContent("Kanal", value: status.channel)
                    LabeledContent("AutoDarts Desktop") { StatusDot(on: status.autodartsRunning, onText: "läuft", offText: "gestoppt") }
                    LabeledContent("Kiosk (Chromium)") { StatusDot(on: status.kioskRunning, onText: "läuft", offText: "gestoppt") }
                    LabeledContent("Grafische Sitzung") {
                        Text(status.session == "x11" ? "X11" : status.session == "wayland" ? "Wayland (X11 nötig!)" : status.session)
                            .foregroundStyle(status.session == "wayland" ? .orange : .primary)
                    }
                    HStack {
                        Button("Weboberfläche öffnen") { pi.openWebUI() }
                        Text("Kamera, Board und Konto (Port \(status.webPort))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Aktionen") {
                    HStack {
                        Button("AutoDarts neu starten") { Task { await pi.restartApp() } }
                        Button("Kiosk neu starten") { Task { await pi.restartKiosk() } }
                        Button("Screenshot") { Task { await pi.takeScreenshot() } }
                    }
                    HStack {
                        Button("Pi neu starten …") { confirmReboot = true }
                        Button("Pi ausschalten …", role: .destructive) { confirmShutdown = true }
                    }
                }
                .disabled(pi.isBusy)
            } else {
                Section { ProgressView("Lade Status …") }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Übersicht")
        .confirmationDialog("Pi neu starten?", isPresented: $confirmReboot) {
            Button("Neu starten", role: .destructive) { Task { await pi.reboot() } }
        } message: {
            Text("Ein laufendes Spiel wird unterbrochen.")
        }
        .confirmationDialog("Pi ausschalten?", isPresented: $confirmShutdown) {
            Button("Ausschalten", role: .destructive) { Task { await pi.shutdown() } }
        } message: {
            Text("Zum Wiedereinschalten muss die Stromversorgung kurz getrennt werden.")
        }
    }
}

struct PowerRow: View {
    let throttled: Throttled?

    var body: some View {
        if let throttled {
            if throttled.isClean {
                Label("In Ordnung – keine Unterspannung", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(throttled.descriptions, id: \.self) { line in
                        Label(line, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(throttled.hasActiveProblem ? .red : .orange)
                    }
                    if throttled.underVoltageNow || throttled.underVoltageOccurred {
                        Text("Tipp: offizielles 5,1 V/5 A-Netzteil und ein kurzes, dickes Kabel verwenden. Unterspannung kann Abstürze und defekte SD-Karten verursachen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } else {
            Text("nicht verfügbar").foregroundStyle(.secondary)
        }
    }
}

struct StatusDot: View {
    let on: Bool
    let onText: String
    let offText: String

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(on ? Color.green : Color.red).frame(width: 8, height: 8)
            Text(on ? onText : offText)
        }
    }
}

enum Format {
    static func uptime(_ seconds: Int?) -> String {
        guard let seconds else { return "–" }
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60
        if days > 0 { return "\(days) Tg. \(hours) Std. \(minutes) Min." }
        if hours > 0 { return "\(hours) Std. \(minutes) Min." }
        return "\(minutes) Min."
    }

    static func memory(used: Int?, total: Int?) -> String {
        guard let used, let total else { return "–" }
        return "\(used) von \(total) MB"
    }
}

// MARK: - Display

struct DisplayView: View {
    @EnvironmentObject var pi: PiController
    @State private var rotation: Rotation = .normal
    @State private var scale = "1.2x1.2"
    @State private var mode = "800x480"
    @State private var mirror = true
    @State private var loaded = false

    var body: some View {
        Form {
            Section("Touch-Display (DSI)") {
                Picker("Rotation", selection: $rotation) {
                    ForEach(Rotation.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                LabeledContent("Skalierung") {
                    HStack {
                        TextField("1.2x1.2", text: $scale)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Menu("Vorgabe") {
                            Button("1.0x1.0 (keine)") { scale = "1.0x1.0" }
                            Button("1.2x1.2 (Standard)") { scale = "1.2x1.2" }
                            Button("1.4x1.4") { scale = "1.4x1.4" }
                        }
                        .fixedSize()
                    }
                }

                LabeledContent("Auflösung") {
                    TextField("800x480", text: $mode)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
            }

            Section("HDMI / Fernseher") {
                Toggle("HDMI auf das Touch-Display spiegeln", isOn: $mirror)
                Text("Bei stark abweichenden Seitenverhältnissen (Display vs. TV) können Ränder entstehen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Button("Anwenden") {
                        Task { await pi.applyDisplay(rotation: rotation, scale: scale, mirror: mirror, mode: mode) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pi.isBusy)

                    Button("Zurücksetzen") { load(force: true) }

                    Text("Wird sofort angewendet und für den nächsten Start gespeichert.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Display")
        .onAppear { load(force: false) }
    }

    private func load(force: Bool) {
        guard let status = pi.status, force || !loaded else { return }
        rotation = status.rotation
        scale = status.dsiScale
        mode = status.dsiMode
        mirror = status.mirror
        loaded = true
    }
}

// MARK: - Bluetooth

struct BluetoothView: View {
    @EnvironmentObject var pi: PiController
    @State private var confirmForget = false

    var body: some View {
        Form {
            Section("Gespeicherter Lautsprecher") {
                if let status = pi.status, status.hasBluetoothSpeaker {
                    LabeledContent("Name", value: status.btName.isEmpty ? status.btMAC : status.btName)
                    LabeledContent("Adresse", value: status.btMAC)
                    LabeledContent("Verbindung") { StatusDot(on: status.btConnected, onText: "verbunden", offText: "getrennt") }
                    HStack {
                        if status.btConnected {
                            Button("Trennen") { Task { await pi.bluetoothDisconnect() } }
                        } else {
                            Button("Verbinden") { Task { await pi.bluetoothConnect() } }
                        }
                        Button("Entfernen …", role: .destructive) { confirmForget = true }
                    }
                    .disabled(pi.isBusy)
                } else {
                    Text("Kein Lautsprecher eingerichtet.").foregroundStyle(.secondary)
                }
            }

            Section("Neuen Lautsprecher koppeln") {
                Text("Lautsprecher einschalten und in den Pairing-Modus versetzen (meist Bluetooth-Taste halten, bis die LED blinkt), dann suchen.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Suchen (ca. 25 s)") { Task { await pi.scanBluetooth() } }
                    .disabled(pi.isBusy)

                if pi.btScanned && pi.btDevices.isEmpty {
                    Text("Keine Geräte gefunden. Pairing-Modus aktiv?").foregroundStyle(.secondary)
                }
                ForEach(pi.btDevices) { device in
                    HStack {
                        Image(systemName: device.isAudio ? "speaker.wave.2.fill" : "dot.radiowaves.left.and.right")
                            .foregroundStyle(device.isAudio ? Color.accentColor : .secondary)
                            .frame(width: 22)
                        VStack(alignment: .leading) {
                            Text(device.name)
                            Text(device.mac).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Koppeln") { Task { await pi.pair(device) } }
                            .disabled(pi.isBusy)
                    }
                }
            }

            Section {
                Text("Kommt nach dem Koppeln kein Ton: Dienste auf dem Pi neu starten oder den Pi neu booten, dann das Gerät im Lautsprecher-Menü der Taskleiste wählen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Bluetooth")
        .confirmationDialog("Lautsprecher entfernen?", isPresented: $confirmForget) {
            Button("Entfernen", role: .destructive) { Task { await pi.bluetoothForget() } }
        } message: {
            Text("Die Kopplung wird auf dem Pi gelöscht.")
        }
    }
}

// MARK: - Updates

struct UpdatesView: View {
    @EnvironmentObject var pi: PiController
    @State private var channel = "stable"

    var body: some View {
        Form {
            Section("AutoDarts Desktop") {
                LabeledContent("Installierte Version", value: pi.status?.autodartsVersion.isEmpty == false ? pi.status!.autodartsVersion : "–")
                Picker("Update-Kanal", selection: $channel) {
                    Text("stable (empfohlen)").tag("stable")
                    Text("beta").tag("beta")
                }
                .onChange(of: channel) { _, new in
                    if new != pi.status?.channel { Task { await pi.setChannel(new) } }
                }
                HStack {
                    Button("Nach Update suchen und installieren") { Task { await pi.checkForUpdates() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(pi.isBusy)
                    Text("Prüft zusätzlich bei jedem Boot automatisch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Pi-Einrichtung") {
                Text("Führt das Setup aus GitHub erneut aus: aktualisiert Skripte, Kiosk und Dienste auf dem Pi. Bestehende Einstellungen bleiben erhalten. Dauert einige Minuten.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Setup aus GitHub aktualisieren") { Task { await pi.selfUpdate() } }
                    .disabled(pi.isBusy)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Updates")
        .onAppear { channel = pi.status?.channel ?? "stable" }
        .onChange(of: pi.status?.channel) { _, new in
            if let new { channel = new }
        }
    }
}

// MARK: - Logs

struct LogsView: View {
    @EnvironmentObject var pi: PiController
    @State private var kind = "update"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("Log", selection: $kind) {
                    Text("AutoDarts-Updates").tag("update")
                    Text("Bluetooth").tag("bluetooth")
                    Text("System (Warnungen)").tag("system")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 440)
                Button("Neu laden") { Task { await pi.loadLog(kind) } }
                Button("Kopieren") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(pi.logText, forType: .string)
                }
                Spacer()
            }
            ScrollView {
                Text(pi.logText.isEmpty ? "Noch nichts geladen." : pi.logText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(16)
        .navigationTitle("Logs")
        .onAppear { Task { await pi.loadLog(kind) } }
        .onChange(of: kind) { _, new in Task { await pi.loadLog(new) } }
    }
}
