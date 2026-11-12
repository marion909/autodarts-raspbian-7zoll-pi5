import Foundation

public enum Validation {
    /// Hostname oder IPv4: beginnt mit Buchstabe/Ziffer (kein "-" -> keine Option-Injection)
    public static func isValidHost(_ host: String) -> Bool {
        host.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]{0,252}$"#, options: .regularExpression) != nil
    }

    public static func isValidUser(_ user: String) -> Bool {
        user.range(of: #"^[a-z_][a-z0-9_-]{0,31}$"#, options: .regularExpression) != nil
    }

    public static func isValidMAC(_ mac: String) -> Bool {
        mac.range(of: #"^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$"#, options: .regularExpression) != nil
    }

    public static func isValidScale(_ scale: String) -> Bool {
        scale.range(of: #"^[0-9]+(\.[0-9]+)?x[0-9]+(\.[0-9]+)?$"#, options: .regularExpression) != nil
    }

    public static func isValidMode(_ mode: String) -> Bool {
        mode.range(of: #"^[0-9]+x[0-9]+$"#, options: .regularExpression) != nil
    }

    public static func isValidPublicKey(_ key: String) -> Bool {
        key.range(of: #"^ssh-(ed25519|rsa) [A-Za-z0-9+/=]+( [A-Za-z0-9@._-]+)?$"#, options: .regularExpression) != nil
    }

    /// Einfache Quotes fuer die Remote-Shell
    public static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
