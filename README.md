# Raspberry Pi 5 + Touchdisplay + AutoDarts (Autostart)

Produktionsnahes Setup für Raspberry Pi OS Desktop mit automatischem Kiosk-Start für AutoDarts.

## Features (aktueller Stand)

- installiert **AutoDarts Desktop** (Linux ARM64)
- installiert **Chromium** und startet `https://play.autodarts.io/` im Fullscreen
- installiert automatisch die Chrome-Erweiterung **Tools for Autodarts** per Policy
- unterdrückt typische Chromium-Dialoge wie **Restore pages / First run / Default browser check**
- setzt beim Login die gewünschte **Screen-Rotation**
- setzt beim Login zusätzlich für DSI: `xrandr --output DSI-2 --mode 800x480 --scale 1.2x1.2 --primary`
- spiegelt DSI automatisch auf HDMI (wenn beide Displays verbunden sind)
- aktiviert Auto-Login (Desktop) und erzwingt X11-Session
- setzt optional Boot-Splash und Desktop-Wallpaper aus `assets/`
- prüft bei jedem Boot auf AutoDarts-Updates (`systemd` Service)

## 1) SD-Karte vorbereiten

1. Raspberry Pi Imager öffnen
2. OS wählen: **Raspberry Pi OS (64-bit) mit Desktop**
3. Zahnrad (Erweiterte Optionen):
   - Hostname setzen
   - Benutzer anlegen (z. B. `pi`)
   - WLAN vorkonfigurieren (empfohlen)
   - SSH aktivieren (optional)
4. Flashen und Pi starten

## 2) Setup ausführen

```bash
chmod +x setup-autodarts-pi5.sh
sudo ./setup-autodarts-pi5.sh
sudo reboot
```

Während des Setups kannst du die Rotation wählen:

- `1` = keine Rotation
- `2` = `90°`
- `3` = `-90°`
- `4` = `180°`

Optional ohne Rückfrage:

```bash
sudo ROTATION_OPTION=2 ./setup-autodarts-pi5.sh
```

## Ergebnis nach dem Neustart

- Desktop-Login erfolgt automatisch
- AutoDarts Desktop startet
- Chromium startet im Vollbild mit `https://play.autodarts.io/`
- Restore/First-Run-Dialoge sind weitgehend unterdrückt
- DSI-Skalierung und Rotation werden beim Login gesetzt
- HDMI wird (bei Verbindung) auf DSI gespiegelt
- GNOME-Keyring-Prompt ist deaktiviert

## Display-Verhalten

- DSI-Fix im Setup: `DSI-2` auf `800x480` mit `scale 1.2x1.2`
- Mirror-Skript erkennt Ausgänge dynamisch (`DSI-*` und `HDMI-*`) und nutzt `--same-as`
- Hinweis: bei stark abweichenden Seitenverhältnissen (DSI vs TV) können Ränder/Skalierungseffekte auftreten

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

## Wichtige Pfade

- Kiosk-Skript: `/usr/local/bin/autodarts-kiosk.sh`
- Rotations-Skript: `/usr/local/bin/autodarts-rotate-display.sh`
- Mirror-Skript: `/usr/local/bin/autodarts-mirror-display.sh`
- Update-Log: `/var/log/autodarts-update.log`
- Update-Service: `autodarts-update-check.service`

Aktueller Chromium Skalierungsfaktor im Kiosk:

- `--force-device-scale-factor=0.85`

## Assets

Optional genutzte Dateien:

- `assets/boot-splash.png`
- `assets/wallpaper.jpg`

## Troubleshooting

- Falls Seite nicht lädt: Netzwerkverbindung prüfen
- Falls Displays falsch sind: Setup erneut ausführen und neu starten

```bash
sudo ./setup-autodarts-pi5.sh
sudo reboot
```
