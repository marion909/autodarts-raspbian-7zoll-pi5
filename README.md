# Raspberry Pi 5 + Touchdisplay + AutoDarts (Autostart)

Produktionsnahes Setup für Raspberry Pi OS Desktop mit automatischem Kiosk-Start für AutoDarts.

## Installation (ein Befehl)

Zielsystem: **Raspberry Pi OS (64-bit) mit Desktop, Debian 13 "Trixie"** auf dem Raspberry Pi 5, Internet erforderlich.
Das Setup schaltet die Session per `raspi-config` auf X11 um (Trixie startet standardmäßig mit Wayland/labwc).

Auf dem Pi:

```bash
curl -fsSL https://raw.githubusercontent.com/marion909/autodarts-raspbian-7zoll-pi5/main/install.sh | sudo bash
```

Danach neu starten:

```bash
sudo reboot
```

Am Ende zeigt das Setup die Adressen der AutoDarts-Weboberfläche an (IP des Pi mit Port `3180`, z. B. `http://192.168.1.50:3180`),
über die nach dem Neustart Kamera, Board und Konto eingerichtet werden.

Das Skript fragt während der Installation nach der Screen-Rotation. Ohne Rückfrage:

```bash
curl -fsSL https://raw.githubusercontent.com/marion909/autodarts-raspbian-7zoll-pi5/main/install.sh | sudo ROTATION_OPTION=2 bash
```

| `ROTATION_OPTION` | Rotation |
| ----------------- | -------- |
| `1` (Standard)    | keine    |
| `2`               | 90°      |
| `3`               | -90°     |
| `4`               | 180°     |

Weitere optionale Variablen (nach `sudo` angeben):

| Variable         | Standard                                  | Bedeutung                                   |
| ---------------- | ----------------------------------------- | ------------------------------------------- |
| `AUTODARTS_REF`  | `main`                                    | Tag oder Branch des Repos (z. B. fester Stand) |
| `AUTODARTS_REPO` | `marion909/autodarts-raspbian-7zoll-pi5`  | anderes Repository (eigener Fork)           |
| `TARGET_USER`    | der `sudo`-Aufrufer                       | Desktop-Benutzer, für den eingerichtet wird |
| `DSI_MODE`       | `800x480`                                 | Auflösung des DSI-Displays                  |
| `DSI_SCALE`      | `1.2x1.2`                                 | xrandr-Skalierung des DSI-Displays          |
| `MIRROR_HDMI`    | `1`                                       | `0` = HDMI nicht auf DSI spiegeln           |
| `AUTODARTS_CHANNEL` | `stable`                               | `stable` oder `beta` für AutoDarts Desktop  |

> Hinweis: Ein Skript per `curl | sudo bash` auszuführen heißt, dem Repository zu vertrauen.
> Wer vorher lesen möchte, lädt [install.sh](install.sh) zuerst herunter, oder klont das Repo und startet
> `sudo ./setup-autodarts-pi5.sh` (siehe unten).

### Installation aus einem Clone

```bash
git clone https://github.com/marion909/autodarts-raspbian-7zoll-pi5.git
cd autodarts-raspbian-7zoll-pi5
sudo ./setup-autodarts-pi5.sh
sudo reboot
```

## Features

- installiert **AutoDarts Desktop** (Linux ARM64, AppImage nach `/opt/autodarts`) und prüft bei jedem Boot auf Updates (`systemd`)
- installiert **Chromium** und startet `https://play.autodarts.com/` im Fullscreen
- startet Chromium nach einem Absturz automatisch neu (mit Bremse gegen Crash-Schleifen)
- zeigt ohne Netzwerk eine lokale Warteseite, die selbstständig erneut versucht
- installiert automatisch die Chrome-Erweiterung **Tools for Autodarts** per Policy
- unterdrückt typische Chromium-Dialoge wie **Restore pages / First run / Default browser check**
- setzt beim Login Screen-Rotation, DSI-Auflösung/Skalierung und spiegelt DSI auf HDMI (falls angeschlossen)
- aktiviert Auto-Login (Desktop) und erzwingt X11-Session
- setzt optional Boot-Splash und Desktop-Wallpaper aus `assets/`

## SD-Karte vorbereiten

1. Raspberry Pi Imager öffnen
2. OS wählen: **Raspberry Pi OS (64-bit) mit Desktop**
3. Zahnrad (Erweiterte Optionen):
   - Hostname setzen
   - Benutzer anlegen (z. B. `pi`)
   - WLAN vorkonfigurieren (empfohlen)
   - SSH aktivieren (optional)
4. Flashen und Pi starten

## Ergebnis nach dem Neustart

- Desktop-Login erfolgt automatisch
- AutoDarts Desktop startet
- Chromium startet im Vollbild mit `https://play.autodarts.com/`
- DSI-Skalierung und Rotation werden vor dem Browserstart gesetzt
- HDMI wird (bei Verbindung) auf DSI gespiegelt
- GNOME-Keyring-Prompt ist deaktiviert

## Display-Verhalten

Das Skript `autodarts-display.sh` läuft synchron vor dem Chromium-Start (keine Race Conditions mehr) und
liest `/etc/default/autodarts-display`:

```bash
ROTATION_XRANDR=normal   # normal | right | left | inverted
DSI_MODE=800x480
DSI_SCALE=1.2x1.2
MIRROR_HDMI=1
```

- Der DSI-Ausgang (`DSI-*`) und der HDMI-Ausgang (`HDMI-*`) werden dynamisch erkannt
- Gespiegelt wird per `xrandr --same-as`
- Bei stark abweichenden Seitenverhältnissen (DSI vs TV) können Ränder/Skalierungseffekte auftreten
- Werte lassen sich in der Datei direkt ändern (wirksam nach dem nächsten Login) oder durch erneutes Setup

## AutoDarts manuell starten

Im Projekt liegt ein Startskript, das `DISPLAY` und `XAUTHORITY` korrekt setzt:

```bash
chmod +x start-autodarts.sh
./start-autodarts.sh
```

## AutoDarts Konfiguration

AutoDarts-Konfigurationsseite im LAN:

```text
http://<RASPBERRY_PI_IP>:3180
```

## Chrome-Plugin (automatisch)

- https://chromewebstore.google.com/detail/tools-for-autodarts/oolfddhehmbpdnlmoljmllcdggmkgihh

## Updates

- AutoDarts Desktop gibt es für Linux ARM64 ab Version 2.0 nur noch als **AppImage** (kein `.deb` mehr). Das Setup lädt es
  von `releases.autodarts.com` nach `/opt/autodarts/autodarts-desktop.AppImage`, der Starter `/usr/local/bin/autodarts-desktop`
  startet es (ohne FUSE automatisch per "entpacken und ausführen")
- Der Service `autodarts-update-check.service` fragt bei jedem Boot die neueste Version des Kanals ab, lädt sie bei Bedarf
  herunter, prüft Dateigröße und ELF-Header und ersetzt das AppImage atomar
- Kanal: `stable` (Standard) oder `beta`, gesetzt beim Setup mit `AUTODARTS_CHANNEL=beta` bzw. in `/etc/default/autodarts-update`
- Log: `/var/log/autodarts-update.log`, manuell ausführen: `sudo /usr/local/bin/autodarts-update-check.sh`
- Das Setup selbst lässt sich jederzeit erneut ausführen (idempotent), um Skripte auf den neuesten Stand zu bringen

## Wichtige Pfade

| Pfad                                          | Inhalt                                       |
| --------------------------------------------- | -------------------------------------------- |
| `/usr/local/bin/autodarts-kiosk.sh`           | Kiosk-Start (Display, AutoDarts, Chromium)   |
| `/usr/local/bin/autodarts-display.sh`         | Rotation, Skalierung, HDMI-Spiegelung        |
| `/usr/local/bin/autodarts-update-check.sh`    | Installation/Update des AppImages            |
| `/usr/local/bin/autodarts-desktop`            | Starter für das AppImage                     |
| `/opt/autodarts/`                             | AppImage und installierte Version            |
| `/etc/default/autodarts-update`               | Update-Kanal (`stable`/`beta`)               |
| `/etc/default/autodarts-display`              | Display-Konfiguration                        |
| `/usr/local/share/autodarts/`                 | Wallpaper und Offline-Seite                  |
| `/var/log/autodarts-update.log`               | Update-Log                                   |

Chromium-Skalierungsfaktor im Kiosk: `--force-device-scale-factor=0.85` (in `files/bin/autodarts-kiosk.sh`).

## Repository-Struktur

```text
install.sh                  # Single-line Installer (lädt das Repo und startet das Setup)
setup-autodarts-pi5.sh      # eigentliches Setup
start-autodarts.sh          # AutoDarts manuell starten
files/bin/                  # Skripte, die nach /usr/local/bin installiert werden
files/autostart/            # Desktop-Autostart-Einträge
files/systemd/              # systemd-Service für den Update-Check
files/share/                # Offline-Warteseite
assets/                     # boot-splash.png, wallpaper.jpg
```

## Troubleshooting

- Seite lädt nicht: Netzwerk prüfen. Bis zur Verbindung zeigt der Kiosk eine Warteseite und versucht es alle 5 Sekunden erneut
- Displays falsch: `/etc/default/autodarts-display` prüfen oder Setup erneut ausführen und neu starten
- Eine alte `.deb`-Version von AutoDarts Desktop (1.x) vorher entfernen: `sudo apt remove autodarts-desktop`
- Update-Probleme: `cat /var/log/autodarts-update.log` und `systemctl status autodarts-update-check.service`
- Alte pcmanfm-Desktop-Konfiguration wird beim Setup einmalig als `desktop-items-0.conf.autodarts-bak` gesichert

## Lizenz

[MIT](LICENSE)
