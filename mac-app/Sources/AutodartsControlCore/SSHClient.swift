import Foundation

public struct SSHConfig: Equatable, Sendable {
    public var host: String
    public var user: String
    public var identityPath: String

    public init(host: String, user: String, identityPath: String = SSHKeyManager.defaultIdentityPath) {
        self.host = host
        self.user = user
        self.identityPath = identityPath
    }

    public var target: String { "\(user)@\(host)" }
}

public struct SSHResult: Sendable {
    public let status: Int32
    public let stdout: Data
    public let stderr: String
    public let timedOut: Bool

    public init(status: Int32, stdout: Data, stderr: String, timedOut: Bool = false) {
        self.status = status
        self.stdout = stdout
        self.stderr = stderr
        self.timedOut = timedOut
    }

    public var text: String { String(decoding: stdout, as: UTF8.self) }
    public var succeeded: Bool { status == 0 && !timedOut }

    /// Beste verfuegbare Fehlermeldung (stderr, sonst stdout)
    public var errorMessage: String {
        let err = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !err.isEmpty { return err }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum SSHFailure: Equatable, Sendable {
    case none
    case authentication
    case hostKeyChanged
    case unreachable(String)
    case timeout
    case commandFailed(Int32)

    public static func classify(_ result: SSHResult) -> SSHFailure {
        if result.timedOut { return .timeout }
        if result.status == 0 { return .none }
        let err = result.stderr
        if err.contains("REMOTE HOST IDENTIFICATION HAS CHANGED") || err.contains("Host key verification failed") {
            return .hostKeyChanged
        }
        if err.contains("Permission denied") { return .authentication }
        if result.status == 255 {
            let line = err.split(whereSeparator: \.isNewline).last.map(String.init) ?? "Keine Verbindung"
            return .unreachable(line)
        }
        return .commandFailed(result.status)
    }
}

private final class LockedBuffer: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()

    func append(_ chunk: Data) {
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    var value: Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}

private final class Flag: @unchecked Sendable {
    private var set = false
    private let lock = NSLock()

    func raise() {
        lock.lock()
        set = true
        lock.unlock()
    }

    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return set
    }
}

/// Startet ein lokales Programm, sammelt stdout/stderr und liefert optional Live-Ausgabe.
func runProcess(
    executable: String,
    arguments: [String],
    environment: [String: String]? = nil,
    timeout: TimeInterval?,
    onOutput: (@Sendable (String) -> Void)? = nil
) async -> SSHResult {
    await withCheckedContinuation { continuation in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let environment {
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        }

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        process.standardInput = FileHandle.nullDevice

        let outBuffer = LockedBuffer()
        let errBuffer = LockedBuffer()
        let timedOut = Flag()

        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            outBuffer.append(chunk)
            onOutput?(String(decoding: chunk, as: UTF8.self))
        }
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            errBuffer.append(chunk)
            onOutput?(String(decoding: chunk, as: UTF8.self))
        }

        process.terminationHandler = { finished in
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            let restOut = outPipe.fileHandleForReading.readDataToEndOfFile()
            let restErr = errPipe.fileHandleForReading.readDataToEndOfFile()
            if !restOut.isEmpty {
                outBuffer.append(restOut)
                onOutput?(String(decoding: restOut, as: UTF8.self))
            }
            if !restErr.isEmpty {
                errBuffer.append(restErr)
                onOutput?(String(decoding: restErr, as: UTF8.self))
            }
            continuation.resume(returning: SSHResult(
                status: finished.terminationStatus,
                stdout: outBuffer.value,
                stderr: String(decoding: errBuffer.value, as: UTF8.self),
                timedOut: timedOut.isSet
            ))
        }

        do {
            try process.run()
        } catch {
            continuation.resume(returning: SSHResult(status: -1, stdout: Data(), stderr: error.localizedDescription))
            return
        }

        if let timeout {
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if process.isRunning {
                    timedOut.raise()
                    process.terminate()
                }
            }
        }
    }
}

public final class SSHClient: @unchecked Sendable {
    public let config: SSHConfig
    private let sshPath: String

    public init(config: SSHConfig, sshPath: String = "/usr/bin/ssh") {
        self.config = config
        self.sshPath = sshPath
    }

    /// Argumente fuer Schluessel-Login (BatchMode, wiederverwendete Verbindung)
    public func arguments(command: String) -> [String] {
        [
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=8",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "ServerAliveInterval=15",
            "-o", "ServerAliveCountMax=3",
            "-o", "IdentitiesOnly=yes",
            "-o", "ControlMaster=auto",
            "-o", "ControlPath=/tmp/autodarts-control-%C",
            "-o", "ControlPersist=120",
            "-i", config.identityPath,
            config.target,
            command,
        ]
    }

    /// Fuehrt einen Befehl auf dem Pi aus (mit Zeitlimit)
    public func run(_ command: String, timeout: TimeInterval = 30) async -> SSHResult {
        guard Validation.isValidHost(config.host), Validation.isValidUser(config.user) else {
            return SSHResult(status: -1, stdout: Data(), stderr: "Ungültiger Host oder Benutzername")
        }
        return await runProcess(executable: sshPath, arguments: arguments(command: command), timeout: timeout)
    }

    /// Wie `run`, liefert die Ausgabe laufend (fuer lange Aufgaben wie Updates)
    public func stream(
        _ command: String,
        timeout: TimeInterval = 1800,
        onOutput: @escaping @Sendable (String) -> Void
    ) async -> SSHResult {
        guard Validation.isValidHost(config.host), Validation.isValidUser(config.user) else {
            return SSHResult(status: -1, stdout: Data(), stderr: "Ungültiger Host oder Benutzername")
        }
        return await runProcess(executable: sshPath, arguments: arguments(command: command), timeout: timeout, onOutput: onOutput)
    }

    /// Richtet den Schluessel-Login ein: einmalige Passwortanmeldung, das Passwort wird nicht gespeichert.
    public func installPublicKey(password: String, publicKey: String) async -> SSHResult {
        guard Validation.isValidHost(config.host), Validation.isValidUser(config.user) else {
            return SSHResult(status: -1, stdout: Data(), stderr: "Ungültiger Host oder Benutzername")
        }
        guard Validation.isValidPublicKey(publicKey) else {
            return SSHResult(status: -1, stdout: Data(), stderr: "Ungültiger öffentlicher Schlüssel")
        }

        // Askpass-Hilfsskript: gibt das Passwort aus der Umgebung aus (liegt nie im Klartext auf der Platte)
        let scriptURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("autodarts-askpass-\(UUID().uuidString).sh")
        let script = "#!/bin/sh\nprintf '%s\\n' \"$AUTODARTS_PW\"\n"
        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        } catch {
            return SSHResult(status: -1, stdout: Data(), stderr: "Hilfsskript konnte nicht angelegt werden: \(error.localizedDescription)")
        }
        defer { try? FileManager.default.removeItem(at: scriptURL) }

        let arguments = [
            "-o", "PreferredAuthentications=password,keyboard-interactive",
            "-o", "PubkeyAuthentication=no",
            "-o", "NumberOfPasswordPrompts=1",
            "-o", "ConnectTimeout=8",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "ControlMaster=no",
            "-o", "ControlPath=none",
            config.target,
            Ctl.authorizeKeyCommand(publicKey: publicKey),
        ]
        let environment = [
            "SSH_ASKPASS": scriptURL.path,
            "SSH_ASKPASS_REQUIRE": "force",
            "AUTODARTS_PW": password,
            "DISPLAY": ProcessInfo.processInfo.environment["DISPLAY"] ?? ":0",
        ]
        return await runProcess(executable: sshPath, arguments: arguments, environment: environment, timeout: 30)
    }

    /// Beendet eine eventuell bestehende, wiederverwendete Verbindung
    public func closeMasterConnection() async {
        var args = ["-o", "ControlPath=/tmp/autodarts-control-%C", "-O", "exit", "-i", config.identityPath, config.target]
        if !Validation.isValidHost(config.host) || !Validation.isValidUser(config.user) { args = [] }
        guard !args.isEmpty else { return }
        _ = await runProcess(executable: sshPath, arguments: args, timeout: 5)
    }
}

public enum SSHKeyManager {
    public static var defaultIdentityPath: String {
        NSHomeDirectory() + "/.ssh/autodarts_control_ed25519"
    }

    /// Legt bei Bedarf ein eigenes Schluesselpaar fuer die App an und liefert den oeffentlichen Schluessel.
    public static func ensureKey(at path: String = defaultIdentityPath) async throws -> String {
        let fm = FileManager.default
        let sshDir = (path as NSString).deletingLastPathComponent
        if !fm.fileExists(atPath: sshDir) {
            try fm.createDirectory(atPath: sshDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }

        if !fm.fileExists(atPath: path) {
            let result = await runProcess(
                executable: "/usr/bin/ssh-keygen",
                arguments: ["-t", "ed25519", "-N", "", "-C", "autodarts-control", "-f", path],
                timeout: 20
            )
            guard result.succeeded else {
                throw KeyError.generationFailed(result.errorMessage)
            }
        }

        // Fehlt nur die .pub-Datei, aus dem privaten Schluessel ableiten
        if !fm.fileExists(atPath: path + ".pub") {
            let result = await runProcess(executable: "/usr/bin/ssh-keygen", arguments: ["-y", "-f", path], timeout: 10)
            guard result.succeeded else { throw KeyError.generationFailed(result.errorMessage) }
            try (result.text.trimmingCharacters(in: .whitespacesAndNewlines) + " autodarts-control\n")
                .write(toFile: path + ".pub", atomically: true, encoding: .utf8)
        }

        let key = try String(contentsOfFile: path + ".pub", encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard Validation.isValidPublicKey(key) else { throw KeyError.invalidKey }
        return key
    }

    /// Entfernt einen veralteten Eintrag aus known_hosts (z. B. nach neu aufgesetztem Pi)
    public static func forgetHostKey(host: String) async -> SSHResult {
        guard Validation.isValidHost(host) else {
            return SSHResult(status: -1, stdout: Data(), stderr: "Ungültiger Host")
        }
        return await runProcess(executable: "/usr/bin/ssh-keygen", arguments: ["-R", host], timeout: 10)
    }

    public enum KeyError: LocalizedError {
        case generationFailed(String)
        case invalidKey

        public var errorDescription: String? {
            switch self {
            case .generationFailed(let message): return "Schlüssel konnte nicht erzeugt werden: \(message)"
            case .invalidKey: return "Der öffentliche Schlüssel hat ein unerwartetes Format."
            }
        }
    }
}
