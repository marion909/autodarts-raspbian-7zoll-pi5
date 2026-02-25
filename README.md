# Raspberry Pi 5 + Touchdisplay + AutoDarts (Autostart)

Dieses Setup installiert auf Raspberry Pi OS mit Desktop:

- Autodarts Desktop (Linux ARM64)
- Chromium im Kiosk-Modus
- automatischen Start von `https://play.autodarts.io/` direkt nach dem Einschalten

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

## AutoDarts manuell starten

Im Projekt liegt ein Startskript, das `DISPLAY`/`XAUTHORITY` korrekt setzt:

```bash
chmod +x start-autodarts.sh
./start-autodarts.sh
```

## Ergebnis

Nach dem Neustart:

- meldet sich der Pi im Desktop automatisch an
- startet Chromium im Vordergrund als Vollbild-Kiosk
- öffnet direkt `https://play.autodarts.io/`
- Autodarts Desktop ist bereits installiert
- AutoDarts Desktop startet vor dem Browser
- GNOME-Keyring-Prompt ist deaktiviert (kein "Unlock keyring" beim Boot)

## Optional: URL anpassen

Die URL liegt in:

- `/usr/local/bin/autodarts-kiosk.sh`

Der Browser-Zoom ist auf 95% gesetzt über:

- `--force-device-scale-factor=0.95`

## Hinweise

- Für Touchdisplay ggf. Rotation in `sudo raspi-config` unter Display-Optionen setzen.
- Wenn die Seite nicht lädt, zuerst Netzwerk prüfen.
- Wenn die Installation vorher mit `Package 'chromium-browser' has no installation candidate` abgebrochen ist, das aktualisierte Skript erneut ausführen:

```bash
sudo ./setup-autodarts-pi5.sh
```
