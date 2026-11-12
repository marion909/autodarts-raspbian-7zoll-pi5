import Foundation

/// Ausgabe von `autodarts-ctl status` (key=value-Zeilen).
public struct PiStatus: Equatable, Sendable {
    public let values: [String: String]

    public init(values: [String: String]) {
        self.values = values
    }

    public init(parsing text: String) {
        var dict: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[line.startIndex ..< eq])
            guard !key.isEmpty, key.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else { continue }
            dict[key] = String(line[line.index(after: eq)...])
        }
        self.values = dict
    }

    public func string(_ key: String) -> String {
        values[key] ?? ""
    }

    public var isValid: Bool { values["ctl_version"] != nil }

    public var hostname: String { string("hostname") }
    public var ips: [String] { string("ips").split(separator: ",").map(String.init) }
    public var os: String { string("os") }
    public var model: String { string("model") }
    public var kernel: String { string("kernel") }
    public var uptimeSeconds: Int? { Int(string("uptime_seconds")) }
    public var temperatureC: Double? { Double(string("temp_c")) }
    public var throttled: Throttled? { Throttled(hex: string("throttled")) }
    public var load: Double? { Double(string("load")) }
    public var memUsedMB: Int? { Int(string("mem_used_mb")) }
    public var memTotalMB: Int? { Int(string("mem_total_mb")) }
    public var diskUsed: String { string("disk_used") }
    public var session: String { string("session") }

    public var autodartsVersion: String { string("autodarts_version") }
    public var autodartsRunning: Bool { string("autodarts_running") == "1" }
    public var kioskRunning: Bool { string("kiosk_running") == "1" }
    public var channel: String { string("channel").isEmpty ? "stable" : string("channel") }
    public var webPort: Int { Int(string("web_port")) ?? 3180 }

    public var rotation: Rotation { Rotation(rawValue: string("rotation")) ?? .normal }
    public var dsiMode: String { string("dsi_mode").isEmpty ? "800x480" : string("dsi_mode") }
    public var dsiScale: String { string("dsi_scale").isEmpty ? "1.2x1.2" : string("dsi_scale") }
    public var mirror: Bool { string("mirror") == "1" }

    public var btMAC: String { string("bt_mac") }
    public var btName: String { string("bt_name") }
    public var btConnected: Bool { string("bt_connected") == "1" }
    public var hasBluetoothSpeaker: Bool { !btMAC.isEmpty }

    public var sshActive: Bool { string("ssh_active") == "active" }
}

/// Bits von `vcgencmd get_throttled` (Strom und Temperatur).
public struct Throttled: Equatable, Sendable {
    public let raw: UInt32

    public init(raw: UInt32) {
        self.raw = raw
    }

    public init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("0x") || text.hasPrefix("0X") { text.removeFirst(2) }
        guard !text.isEmpty, let value = UInt32(text, radix: 16) else { return nil }
        self.raw = value
    }

    public var underVoltageNow: Bool { raw & 0x1 != 0 }
    public var frequencyCappedNow: Bool { raw & 0x2 != 0 }
    public var throttledNow: Bool { raw & 0x4 != 0 }
    public var softTempLimitNow: Bool { raw & 0x8 != 0 }
    public var underVoltageOccurred: Bool { raw & 0x10000 != 0 }
    public var frequencyCappedOccurred: Bool { raw & 0x20000 != 0 }
    public var throttledOccurred: Bool { raw & 0x40000 != 0 }
    public var softTempLimitOccurred: Bool { raw & 0x80000 != 0 }

    public var isClean: Bool { raw == 0 }
    /// Aktuell aktives Problem (nicht nur "seit dem Start aufgetreten")
    public var hasActiveProblem: Bool { raw & 0xF != 0 }

    public var descriptions: [String] {
        var list: [String] = []
        if underVoltageNow { list.append("Unterspannung (jetzt)") }
        if frequencyCappedNow { list.append("Taktfrequenz begrenzt (jetzt)") }
        if throttledNow { list.append("Gedrosselt (jetzt)") }
        if softTempLimitNow { list.append("Temperaturlimit aktiv (jetzt)") }
        if underVoltageOccurred { list.append("Unterspannung seit dem Start aufgetreten") }
        if frequencyCappedOccurred { list.append("Taktfrequenz seit dem Start begrenzt") }
        if throttledOccurred { list.append("Seit dem Start gedrosselt") }
        if softTempLimitOccurred { list.append("Temperaturlimit seit dem Start erreicht") }
        return list
    }
}

public enum Rotation: String, CaseIterable, Identifiable, Sendable {
    case normal, right, left, inverted

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .normal: return "Keine Rotation"
        case .right: return "90°"
        case .left: return "-90°"
        case .inverted: return "180°"
        }
    }
}

public struct BluetoothDevice: Identifiable, Equatable, Sendable {
    public let mac: String
    public let name: String
    public let isAudio: Bool
    public var id: String { mac }

    public init(mac: String, name: String, isAudio: Bool) {
        self.mac = mac
        self.name = name
        self.isAudio = isAudio
    }

    /// Parst die Ausgabe von `autodarts-ctl bt-list` (MAC<TAB>Name<TAB>Audio 0|1)
    public static func parse(_ text: String) -> [BluetoothDevice] {
        text.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 3, Validation.isValidMAC(parts[0]) else { return nil }
            return BluetoothDevice(mac: parts[0], name: parts[1], isAudio: parts[2] == "1")
        }
    }
}
