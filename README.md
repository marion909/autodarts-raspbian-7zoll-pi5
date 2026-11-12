<p align="center">
  <img src="assets/brand/readme-banner.png" alt="Autodarts auf dem Raspberry Pi" width="100%">
</p>

<h1 align="center">Autodarts Pi Kiosk</h1>

<p align="center">
  <b>Raspberry Pi 5 + 7"-Touchdisplay = fertiges Autodarts-Board.</b><br>
  Ein Befehl installiert alles. Nach dem Neustart startet das Spiel von allein.
</p>

<p align="center">
  <img alt="Raspberry Pi 5" src="https://img.shields.io/badge/Raspberry%20Pi-5-C51A4A?logo=raspberrypi&logoColor=white">
  <img alt="Raspberry Pi OS Trixie" src="https://img.shields.io/badge/Pi%20OS-Trixie-A81D33?logo=debian&logoColor=white">
  <img alt="Mac-App" src="https://img.shields.io/badge/Mac--App-SwiftUI-0A84FF?logo=apple&logoColor=white">
  <img alt="Lizenz MIT" src="https://img.shields.io/badge/Lizenz-MIT-2EA44F">
</p>

---

## ⚡ Installation

Auf dem Pi (Raspberry Pi OS 64-bit mit Desktop, Internet nötig):

```bash
curl -fsSL https://raw.githubusercontent.com/marion909/autodarts-raspbian-7zoll-pi5/main/install.sh | sudo bash
```

Dann `sudo reboot`. Am Ende des Setups siehst du die Adresse, unter der du Kamera, Board und Konto einrichtest, z. B.
`http://192.168.1.50:3180`.

> 💡 **Vorbereitung:** Im Raspberry Pi Imager Hostname, Benutzer, WLAN und SSH setzen, auf SD-Karte flashen, Pi starten.

## ✨ Was du bekommst

| | |
| --- | --- |
| 🎯 **Autodarts Desktop** | aktuelle ARM64-Version, prüft bei jedem Boot automatisch auf Updates (stable oder beta) |
| 🖥️ **Kiosk-Modus** | `play.autodarts.com` im Vollbild, startet nach Abstürzen neu, Warteseite ohne Netzwerk |
| 🔄 **Display** | Rotation, Skalierung und HDMI-Spiegelung für Touchdisplay und TV |
| 🔊 **Bluetooth-Lautsprecher** | suchen, auswählen, koppeln. Verbindet sich bei jedem Start automatisch |
| 🧩 **Tools for Autodarts** | Chromium-Erweiterung wird automatisch installiert |
| 🎨 **Autodarts-Look** | Bootscreen und Wallpaper im aktuellen Autodarts-Design |

## 🍎 Mac-App „Autodarts Control“

Verwalte deinen Pi per Klick, ohne Terminal: Status mit **Stromversorgung und Temperatur**, Neustart, Screenshot,
Display-Einstellungen, Bluetooth, Updates und Logs. Dazu ein Symbol in der Menüleiste.

```bash
cd mac-app && ./build.sh      # baut nach ~/Applications (Xcode oder xcode-select --install nötig)
```

Beim ersten Start gibst du einmalig das Pi-Passwort ein. Die App richtet damit einen eigenen SSH-Schlüssel ein und speichert
das Passwort nicht.

## ⚙️ Häufige Optionen

Einfach vor `bash` angeben, z. B. `… | sudo ROTATION_OPTION=2 BT_SPEAKER=no bash`:

| Option | Werte | Bedeutung |
| --- | --- | --- |
| `ROTATION_OPTION` | `1` keine · `2` 90° · `3` -90° · `4` 180° | Bildschirm-Rotation (sonst Rückfrage) |
| `BT_SPEAKER` | `yes` · `no` · MAC-Adresse | Bluetooth-Lautsprecher einrichten |
| `AUTODARTS_CHANNEL` | `stable` · `beta` | Update-Kanal von Autodarts Desktop |
| `ENABLE_SSH` | `1` | SSH aktivieren (für die Mac-App) |

## 📚 Mehr

- **[Handbuch](docs/handbuch.md):** alle Optionen, Pfade, Display, Bluetooth, Mac-App und Fehlerbehebung
- **Terminal-Verwaltung auf dem Pi:** `autodarts-ctl help`
- **Lieber erst lesen?** [install.sh](install.sh) ansehen oder Repo klonen und `sudo ./setup-autodarts-pi5.sh` starten

<sub>Das Autodarts-Logo gehört Autodarts bzw. Winmau. Dieses Projekt ist nicht offiziell mit Autodarts verbunden. Lizenz: [MIT](LICENSE).</sub>
