import AppKit
import AutodartsControlCore
import SwiftUI

struct Notice: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isError: Bool
}

/// Zentrale Steuerung: Verbindung, Status und alle Aktionen auf dem Pi (per SSH + autodarts-ctl).
@MainActor
final class PiController: ObservableObject {
    enum Connection: Equatable {
        case idle
        case connecting
        case needsKey
        case hostKeyChanged
        case unreachable(String)
        case needsTools(outdated: Bool)
        case connected
    }

    private enum Keys {
        static let host = "pi.host"
        static let user = "pi.user"
    }

    private let defaults = UserDefaults.standard

    @Published var host: String {
        didSet {
            defaults.set(host, forKey: Keys.host)
            rebuildClient()
        }
    }

    @Published var user: String {
        didSet {
            defaults.set(user, forKey: Keys.user)
            rebuildClient()
        }
    }

    @Published private(set) var connection: Connection = .idle
    @Published private(set) var status: PiStatus?
    @Published private(set) var lastUpdate: Date?
    @Published var notice: Notice?
    @Published private(set) var task: String?
    @Published var output = ""
    @Published var showOutput = false
    @Published private(set) var btDevices: [BluetoothDevice] = []
    @Published private(set) var btScanned = false
    @Published var logText = ""
    @Published var screenshot: NSImage?

    private var client: SSHClient
    private var pollTask: Task<Void, Never>?
    private var started = false

    init() {
        let storedHost = UserDefaults.standard.string(forKey: Keys.host) ?? "Autodarts.local"
        let storedUser = UserDefaults.standard.string(forKey: Keys.user) ?? "pi"
        self.host = storedHost
        self.user = storedUser
        self.client = SSHClient(config: SSHConfig(host: storedHost, user: storedUser))
    }

    private func rebuildClient() {
        client = SSHClient(config: SSHConfig(host: host, user: user))
    }

    // MARK: - Abgeleitete Werte

    var isConnected: Bool { connection == .connected }
    var isBusy: Bool { task != nil }

    var hasProblem: Bool { status?.throttled?.hasActiveProblem ?? false }

    var menuBarSymbol: String {
        switch connection {
        case .connected: return hasProblem ? "exclamationmark.triangle.fill" : "scope"
        case .connecting, .idle: return "scope"
        default: return "wifi.slash"
        }
    }

    var webURL: URL? {
        URL(string: "http://\(host):\(status?.webPort ?? 3180)")
    }

    // MARK: - Start / Polling

    func start() async {
        guard !started else { return }
        started = true
        await probe()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                await self?.pollOnce()
            }
        }
    }

    private func pollOnce() async {
        guard task == nil else { return }
        switch connection {
        case .connected:
            await refreshStatus()
        case .unreachable:
            await probe()
        default:
            break
        }
    }

    // MARK: - Verbindung

    /// Prüft Schlüssel-Login und Pi-Tools und ordnet den Verbindungszustand ein.
    func probe() async {
        guard Validation.isValidHost(host), Validation.isValidUser(user) else {
            connection = .unreachable("Ungültiger Host oder Benutzername")
            return
        }
        if connection != .connected { connection = .connecting }

        let test = await client.run("true", timeout: 15)
        switch SSHFailure.classify(test) {
        case .none:
            break
        case .authentication:
            connection = .needsKey
            return
        case .hostKeyChanged:
            connection = .hostKeyChanged
            return
        case .timeout:
            connection = .unreachable("Zeitüberschreitung – der Pi antwortet nicht")
            return
        case .unreachable(let message):
            connection = .unreachable(message)
            return
        case .commandFailed:
            connection = .unreachable(test.errorMessage)
            return
        }

        let version = await client.run(Ctl.versionProbe, timeout: 15)
        guard version.succeeded,
              let number = Int(version.text.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            connection = .needsTools(outdated: false)
            return
        }
        if number < Ctl.requiredVersion {
            connection = .needsTools(outdated: true)
            return
        }
        connection = .connected
        await refreshStatus()
    }

    /// Einmalige Einrichtung: eigenen Schlüssel erzeugen und mit dem Passwort auf dem Pi hinterlegen.
    func setupKey(password: String) async {
        task = "SSH-Zugang einrichten"
        defer { task = nil }
        do {
            let publicKey = try await SSHKeyManager.ensureKey()
            let result = await client.installPublicKey(password: password, publicKey: publicKey)
            if !result.succeeded {
                if result.stderr.contains("Permission denied") {
                    notice = Notice(text: "Anmeldung fehlgeschlagen: Passwort falsch oder Passwort-Anmeldung auf dem Pi deaktiviert.", isError: true)
                } else {
                    notice = Notice(text: result.errorMessage, isError: true)
                }
                return
            }
        } catch {
            notice = Notice(text: error.localizedDescription, isError: true)
            return
        }
        notice = Notice(text: "SSH-Zugang eingerichtet.", isError: false)
        task = nil
        await probe()
    }

    func forgetHostKeyAndReconnect() async {
        let result = await SSHKeyManager.forgetHostKey(host: host)
        if !result.succeeded {
            notice = Notice(text: result.errorMessage, isError: true)
        }
        await probe()
    }

    func installTools() async {
        await stream("Pi-Tools installieren", Ctl.bootstrapCommand())
        await probe()
    }

    // MARK: - Status

    func refreshStatus() async {
        let result = await client.run(Ctl.command("status"), timeout: 25)
        if result.succeeded {
            let parsed = PiStatus(parsing: result.text)
            if parsed.isValid {
                status = parsed
                lastUpdate = Date()
            }
            return
        }
        switch SSHFailure.classify(result) {
        case .unreachable(let message):
            connection = .unreachable(message)
        case .timeout:
            connection = .unreachable("Zeitüberschreitung – der Pi antwortet nicht")
        default:
            reportFailure(result)
        }
    }

    // MARK: - Aktionen

    @discardableResult
    private func perform(
        _ title: String,
        _ command: String,
        timeout: TimeInterval = 60,
        refresh: Bool = true
    ) async -> SSHResult {
        task = title
        let result = await client.run(command, timeout: timeout)
        task = nil
        if result.succeeded {
            let message = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let lastLine = message.split(whereSeparator: \.isNewline).last.map(String.init) ?? "Fertig."
            notice = Notice(text: lastLine.hasPrefix("ok: ") ? String(lastLine.dropFirst(4)) : lastLine, isError: false)
            if refresh { await refreshStatus() }
        } else {
            reportFailure(result)
        }
        return result
    }

    private func reportFailure(_ result: SSHResult) {
        var message = result.errorMessage
        if message.contains("a password is required") || message.contains("sudo:") && message.contains("password") {
            message = "sudo verlangt ein Passwort. Der Benutzer braucht passwortloses sudo (Standard unter Raspberry Pi OS)."
        } else if result.timedOut {
            message = "Zeitüberschreitung."
        } else if message.isEmpty {
            message = "Befehl fehlgeschlagen (Exit-Code \(result.status))."
        }
        notice = Notice(text: message, isError: true)
    }

    /// Lange Aufgabe mit Live-Ausgabe (Updates, Setup)
    private func stream(_ title: String, _ command: String, timeout: TimeInterval = 1800) async {
        output = ""
        showOutput = true
        task = title
        let result = await client.stream(command, timeout: timeout) { [weak self] chunk in
            Task { @MainActor in
                guard let self else { return }
                self.output += chunk
                if self.output.count > 200_000 {
                    self.output = String(self.output.suffix(150_000))
                }
            }
        }
        task = nil
        if result.succeeded {
            notice = Notice(text: "\(title): fertig.", isError: false)
        } else {
            output += "\n--- Abgebrochen (Exit-Code \(result.status)\(result.timedOut ? ", Zeitüberschreitung" : "")) ---\n"
            notice = Notice(text: "\(title): fehlgeschlagen.", isError: true)
        }
    }

    func restartApp() async {
        await perform("AutoDarts Desktop neu starten", Ctl.command("restart-app"), timeout: 40, refresh: false)
        try? await Task.sleep(for: .seconds(3))
        await refreshStatus()
    }

    func restartKiosk() async {
        await perform("Kiosk neu starten", Ctl.command("restart-kiosk"), refresh: false)
        try? await Task.sleep(for: .seconds(5))
        await refreshStatus()
    }

    func reboot() async {
        let result = await perform("Neustart", Ctl.command("reboot"), refresh: false)
        if result.succeeded { connection = .unreachable("Der Pi startet neu …") }
    }

    func shutdown() async {
        let result = await perform("Ausschalten", Ctl.command("shutdown"), refresh: false)
        if result.succeeded { connection = .unreachable("Der Pi wurde ausgeschaltet.") }
    }

    func openWebUI() {
        if let url = webURL { NSWorkspace.shared.open(url) }
    }

    func takeScreenshot() async {
        let result = await perform("Screenshot", Ctl.command("screenshot"), timeout: 30, refresh: false)
        guard result.succeeded else { return }
        let path = result.text.trimmingCharacters(in: .whitespacesAndNewlines).split(whereSeparator: \.isNewline).last.map(String.init) ?? ""
        guard path.hasPrefix("/tmp/"), !path.contains("'") else {
            notice = Notice(text: "Unerwarteter Screenshot-Pfad.", isError: true)
            return
        }
        task = "Screenshot laden"
        let file = await client.run("cat \(Validation.shellQuote(path))", timeout: 30)
        task = nil
        if file.succeeded, let image = NSImage(data: file.stdout) {
            screenshot = image
            notice = nil
        } else {
            notice = Notice(text: "Screenshot konnte nicht geladen werden.", isError: true)
        }
    }

    // MARK: - Display

    func applyDisplay(rotation: Rotation, scale: String, mirror: Bool, mode: String) async {
        guard Validation.isValidScale(scale) else {
            notice = Notice(text: "Ungültige Skalierung (Beispiel: 1.2x1.2).", isError: true)
            return
        }
        guard Validation.isValidMode(mode) else {
            notice = Notice(text: "Ungültige Auflösung (Beispiel: 800x480).", isError: true)
            return
        }
        await perform(
            "Display-Einstellungen anwenden",
            Ctl.command("display-set", rotation.rawValue, scale, mirror ? "1" : "0", mode),
            timeout: 40
        )
    }

    // MARK: - Bluetooth

    func scanBluetooth() async {
        let result = await perform("Bluetooth-Suche läuft (ca. 25 s) – Lautsprecher in den Pairing-Modus versetzen",
                                   Ctl.command("bt-list"), timeout: 90, refresh: false)
        if result.succeeded {
            btDevices = BluetoothDevice.parse(result.text)
            btScanned = true
            notice = Notice(text: btDevices.isEmpty ? "Keine Geräte gefunden." : "\(btDevices.count) Gerät(e) gefunden.", isError: false)
        }
    }

    func pair(_ device: BluetoothDevice) async {
        guard Validation.isValidMAC(device.mac) else { return }
        let result = await perform("Koppeln mit \(device.name) …", Ctl.command("bt-pair", device.mac), timeout: 120)
        if result.succeeded {
            notice = Notice(text: "Verbunden mit \(device.name).", isError: false)
        }
    }

    func bluetoothConnect() async {
        await perform("Lautsprecher verbinden", Ctl.command("bt-connect"), timeout: 45)
    }

    func bluetoothDisconnect() async {
        await perform("Lautsprecher trennen", Ctl.command("bt-disconnect"), timeout: 30)
    }

    func bluetoothForget() async {
        await perform("Lautsprecher entfernen", Ctl.command("bt-forget"), timeout: 30)
    }

    // MARK: - Updates / Logs

    func setChannel(_ channel: String) async {
        guard channel == "stable" || channel == "beta" else { return }
        await perform("Update-Kanal setzen", Ctl.command("channel", channel), timeout: 20)
    }

    func checkForUpdates() async {
        await stream("AutoDarts-Update", Ctl.command("update"), timeout: 900)
        await refreshStatus()
    }

    func selfUpdate() async {
        await stream("Setup aus GitHub aktualisieren", Ctl.command("self-update"))
        await probe()
    }

    func loadLog(_ kind: String) async {
        task = "Log laden"
        let result = await client.run(Ctl.command("logs", kind), timeout: 30)
        task = nil
        logText = result.succeeded ? result.text : result.errorMessage
    }
}
