# Raspberry Pi 5 + Touchdisplay + AutoDarts (Autostart)

Dieses Setup installiert auf Raspberry Pi OS mit Desktop:

- Autodarts Desktop (Linux ARM64)
- Chromium im Vollbildmodus (Start-Fullscreen)
- automatischen Start von `https://play.autodarts.io/` direkt nach dem Einschalten
- Bootscreen und Desktop-Hintergrund aus dem `assets`-Ordner
- installiert automatisch die Chrome-Erweiterung "Tools for Autodarts"
- startet die Bildschirmtastatur (Onboard) im Fullscreen als Dock unten
- Onboard wird im Fullscreen zuverlässig above/always-on-top gehalten
- Fullscreen-Kompatibilität verbessert (`--enable-virtual-keyboard` + Onboard always-on-top)
- Setup erzwingt X11-Session für bessere Tastatur-Funktion im Fullscreen
- Accessibility-Stack (AT-SPI) wird aktiviert, damit Auto-Show im Fullscreen zuverlässiger funktioniert
- prüft bei jedem Pi-Start auf AutoDarts-Updates und installiert sie automatisch

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

Dateien auf den Pi kopieren und dann:

```bash
chmod +x setup-autodarts-pi5.sh
sudo ./setup-autodarts-pi5.sh
sudo reboot
```

Während des Setups kannst du die Screen-Rotation wählen:

- `1` = `keine Rotation`
- `2` = `90°`
- `3` = `-90°`
- `4` = `180°`

Optional ohne Rückfrage (z. B. bei automatischem Setup):

```bash
sudo ROTATION_OPTION=2 ./setup-autodarts-pi5.sh
```

## AutoDarts manuell starten

Im Projekt liegt ein Startskript, das `DISPLAY`/`XAUTHORITY` korrekt setzt:

```bash
chmod +x start-autodarts.sh
./start-autodarts.sh
```

## Ergebnis

Nach dem Neustart:

- meldet sich der Pi im Desktop automatisch an
- startet Chromium im Vordergrund im Vollbildmodus
- öffnet direkt `https://play.autodarts.io/`
- Autodarts Desktop ist bereits installiert
- AutoDarts Desktop startet vor dem Browser
- GNOME-Keyring-Prompt ist deaktiviert (kein "Unlock keyring" beim Boot)
- eigener Bootscreen wird gesetzt (`assets/boot-splash.png`)
- eigener Desktop-Hintergrund wird gesetzt (`assets/wallpaper.jpg`)

## Assets

Das Skript nutzt automatisch diese Dateien:

- `assets/boot-splash.png`
- `assets/wallpaper.jpg`

Der Desktop-Hintergrund wird beim Login automatisch gesetzt (Autostart-Job).

## AutoDarts Konfiguration

Die AutoDarts-Konfigurationsseite erreichst du im Netzwerk über die IP des Raspberry Pi auf Port `3180`:

```text
http://<RASPBERRY_PI_IP>:3180
```

## Chrome-Plugin

Die Erweiterung **Tools for Autodarts** wird per Chromium-Policy automatisch installiert:

- https://chromewebstore.google.com/detail/tools-for-autodarts/oolfddhehmbpdnlmoljmllcdggmkgihh

Nach `sudo ./setup-autodarts-pi5.sh` ggf. einmal neu starten bzw. Chromium neu starten.

## Optional: URL anpassen

Die URL liegt in:

- `/usr/local/bin/autodarts-kiosk.sh`

Der Browser-Zoom ist auf 95% gesetzt über:

- `--force-device-scale-factor=0.95`

## Hinweise

- Aktueller Stand: Die On-Screen-Tastatur funktioniert im Fullscreen-Modus noch nicht zuverlässig.
- Die gewählte Rotation wird beim Login automatisch angewendet.
- Für On-Screen-Keyboard im Fullscreen wird Chromium mit X11 + VirtualKeyboard gestartet; die Tastatur wird als Dock unten angezeigt.
- Warnungen wie `mousetweaks ... not found` sind unkritisch; entscheidend ist, dass `onboard` läuft und Accessibility aktiv ist.
- AutoDarts-Update-Check läuft bei jedem Boot über `systemd` (`autodarts-update-check.service`).
- Log-Datei für Updates: `/var/log/autodarts-update.log`
- Wenn die Bildschirmtastatur fehlt, Setup erneut ausführen und neu starten:

```bash
sudo ./setup-autodarts-pi5.sh
sudo reboot
```
- Für Fullscreen wird Onboard verzögert gestartet und über dconf mit `force-to-top` konfiguriert.
- Wenn die Seite nicht lädt, zuerst Netzwerk prüfen.
- Wenn der Hintergrund noch Standard ist, Setup erneut ausführen und neu starten:

```bash
sudo ./setup-autodarts-pi5.sh
sudo reboot
```
- Wenn die Installation vorher mit `Package 'chromium-browser' has no installation candidate` abgebrochen ist, das aktualisierte Skript erneut ausführen:

```bash
sudo ./setup-autodarts-pi5.sh
```
