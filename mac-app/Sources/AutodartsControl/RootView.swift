import AppKit
import AutodartsControlCore
import SwiftUI

struct RootView: View {
    @EnvironmentObject var pi: PiController

    var body: some View {
        Group {
            if pi.isConnected {
                MainView()
            } else {
                ConnectionView()
            }
        }
        .frame(minWidth: 760, minHeight: 520)
        .safeAreaInset(edge: .top, spacing: 0) {
            if let notice = pi.notice {
                NoticeBanner(notice: notice) { pi.notice = nil }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let task = pi.task, !pi.showOutput {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(task).font(.callout)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.bar)
            }
        }
        .sheet(isPresented: $pi.showOutput) {
            OutputSheet()
                .environmentObject(pi)
        }
        .sheet(isPresented: Binding(get: { pi.screenshot != nil }, set: { if !$0 { pi.screenshot = nil } })) {
            ScreenshotSheet()
                .environmentObject(pi)
        }
        .task { await pi.start() }
    }
}

struct NoticeBanner: View {
    let notice: Notice
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: notice.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(notice.isError ? .red : .green)
            Text(notice.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: dismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(notice.isError ? Color.red.opacity(0.12) : Color.green.opacity(0.12))
    }
}

struct OutputSheet: View {
    @EnvironmentObject var pi: PiController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(pi.task ?? "Ausgabe").font(.headline)
                if pi.task != nil { ProgressView().controlSize(.small) }
                Spacer()
            }
            ScrollViewReader { proxy in
                ScrollView {
                    Text(pi.output.isEmpty ? "Warte auf Ausgabe …" : pi.output)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onChange(of: pi.output) { _, _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            HStack {
                Button("Ausgabe kopieren") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(pi.output, forType: .string)
                }
                Spacer()
                Button("Schließen") { pi.showOutput = false }
                    .keyboardShortcut(.defaultAction)
                    .disabled(pi.task != nil)
            }
        }
        .padding(16)
        .frame(minWidth: 640, minHeight: 420)
        .interactiveDismissDisabled(pi.task != nil)
    }
}

struct ScreenshotSheet: View {
    @EnvironmentObject var pi: PiController

    var body: some View {
        VStack(spacing: 12) {
            if let image = pi.screenshot {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 900, maxHeight: 560)
            }
            HStack {
                Button("Kopieren") {
                    if let image = pi.screenshot {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.writeObjects([image])
                    }
                }
                Button("Sichern …") { saveScreenshot() }
                Spacer()
                Button("Schließen") { pi.screenshot = nil }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(minWidth: 600, minHeight: 400)
    }

    private func saveScreenshot() {
        guard let image = pi.screenshot,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "autodarts-pi-screenshot.png"
        panel.allowedContentTypes = [.png]
        if panel.runModal() == .OK, let url = panel.url {
            try? png.write(to: url)
        }
    }
}

// MARK: - Verbindung / Einrichtung

struct ConnectionView: View {
    @EnvironmentObject var pi: PiController
    @State private var password = ""

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "scope")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("Autodarts Control").font(.largeTitle.bold())
            Text("Verwaltung deines Autodarts-Raspberry-Pi")
                .foregroundStyle(.secondary)

            HStack {
                TextField("Hostname oder IP", text: $pi.host)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                TextField("Benutzer", text: $pi.user)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
            }

            stateContent
                .frame(maxWidth: 460)

            Spacer(minLength: 0)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var stateContent: some View {
        switch pi.connection {
        case .idle, .connecting:
            VStack(spacing: 8) {
                ProgressView()
                Text("Verbinde mit \(pi.user)@\(pi.host) …").foregroundStyle(.secondary)
            }

        case .needsKey:
            VStack(spacing: 12) {
                Text("Einmalige Einrichtung")
                    .font(.headline)
                Text("Gib das Passwort des Pi-Benutzers ein. Es wird nur verwendet, um einen eigenen SSH-Schlüssel auf dem Pi zu hinterlegen, und nirgends gespeichert.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                SecureField("Passwort von \(pi.user)@\(pi.host)", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(submitPassword)
                Button("SSH-Zugang einrichten", action: submitPassword)
                    .buttonStyle(.borderedProminent)
                    .disabled(password.isEmpty || pi.isBusy)
                if pi.isBusy { ProgressView().controlSize(.small) }
            }

        case .hostKeyChanged:
            VStack(spacing: 12) {
                Label("Der SSH-Schlüssel des Pi hat sich geändert", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.headline)
                Text("Das passiert nach einer Neuinstallation des Pi. Wenn du das nicht erwartest, verbinde dich nicht (mögliches Abhören im Netzwerk).")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Alten Schlüssel entfernen und neu verbinden") {
                    Task { await pi.forgetHostKeyAndReconnect() }
                }
            }

        case .unreachable(let message):
            VStack(spacing: 12) {
                Label("Pi nicht erreichbar", systemImage: "wifi.slash")
                    .font(.headline)
                Text(message)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Text("Ist der Pi eingeschaltet und im selben Netzwerk? SSH aktivieren (auf dem Pi): sudo raspi-config nonint do_ssh 0")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Button("Erneut versuchen") { Task { await pi.probe() } }
                    .buttonStyle(.borderedProminent)
            }

        case .needsTools(let outdated):
            VStack(spacing: 12) {
                Label(outdated ? "Pi-Tools sind veraltet" : "Pi-Tools fehlen", systemImage: "wrench.and.screwdriver")
                    .font(.headline)
                Text("Die App braucht den Befehl autodarts-ctl auf dem Pi. Er wird durch das Setup aus GitHub installiert; bestehende Einstellungen bleiben erhalten. Das dauert einige Minuten.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button(outdated ? "Pi-Tools aktualisieren" : "Pi-Tools installieren") {
                    Task { await pi.installTools() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(pi.isBusy)
            }

        case .connected:
            EmptyView()
        }
    }

    private func submitPassword() {
        let value = password
        password = ""
        guard !value.isEmpty else { return }
        Task { await pi.setupKey(password: value) }
    }
}
