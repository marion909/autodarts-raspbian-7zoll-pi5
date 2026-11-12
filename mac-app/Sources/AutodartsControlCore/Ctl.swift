import Foundation

/// Befehle fuer `autodarts-ctl` auf dem Pi.
public enum Ctl {
    public static let path = "/usr/local/bin/autodarts-ctl"
    /// Mindestversion der Pi-Tools, die diese App versteht
    public static let requiredVersion = 1

    public static func command(_ args: String...) -> String {
        command(args)
    }

    public static func command(_ args: [String]) -> String {
        ([path] + args.map(Validation.shellQuote)).joined(separator: " ")
    }

    public static var versionProbe: String {
        "test -x \(path) && \(path) version"
    }

    /// Installiert/aktualisiert die Pi-Tools durch erneutes Ausfuehren des Setups
    /// (bestehende Einstellungen bleiben erhalten, Bluetooth wird uebersprungen).
    public static func bootstrapCommand(repo: String = "marion909/autodarts-raspbian-7zoll-pi5", ref: String = "main") -> String {
        let url = "https://raw.githubusercontent.com/\(repo)/\(ref)/install.sh"
        return """
        set -o pipefail; \
        ROTATION_OPTION=1; DSI_MODE=800x480; DSI_SCALE=1.2x1.2; MIRROR_HDMI=1; AUTODARTS_CHANNEL=stable; \
        for f in /etc/default/autodarts-display /etc/default/autodarts-update; do [ -r "$f" ] && . "$f"; done; \
        curl -fsSL \(Validation.shellQuote(url)) | sudo -n env TARGET_USER="$(id -un)" \
        AUTODARTS_REPO=\(Validation.shellQuote(repo)) AUTODARTS_REF=\(Validation.shellQuote(ref)) \
        ROTATION_OPTION="$ROTATION_OPTION" DSI_MODE="$DSI_MODE" DSI_SCALE="$DSI_SCALE" \
        MIRROR_HDMI="$MIRROR_HDMI" AUTODARTS_CHANNEL="$AUTODARTS_CHANNEL" BT_SPEAKER=no bash
        """
    }

    /// Haengt den oeffentlichen Schluessel an ~/.ssh/authorized_keys an (ohne Duplikate)
    public static func authorizeKeyCommand(publicKey: String) -> String {
        let key = Validation.shellQuote(publicKey)
        return "umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; grep -qxF \(key) ~/.ssh/authorized_keys || echo \(key) >> ~/.ssh/authorized_keys"
    }
}
