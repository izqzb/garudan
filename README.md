# Garudan

Open-source mobile control panel for self-hosted servers. Built with Flutter.

**SSH Terminal · Docker · Files · System Monitoring · Gotify Notifications**

## Download

Get the latest APK from the [Releases](../../releases) tab.

Minimum: Android 8.0+ (API 26)

## Features

- **SSH Terminal** — Multi-tab, persistent connections, auto-reconnect, 7 color themes, Ctrl toolbar, pinch-to-zoom, syntax-highlighted snippets
- **Docker** — Container list, start/stop/restart/logs, live stats, long-press quick actions
- **Files** — File browser with upload from phone, new folder, text editor with syntax highlighting, rename/delete
- **Dashboard** — Real-time CPU/RAM/disk line graphs + temperature sensors
- **Processes** — Top processes by CPU/MEM, kill support
- **Notifications** — Gotify push + in-app notification list
- **SSH Key Manager** — Generate ED25519 keys, store encrypted, copy public key
- **System Alerts** — CPU/RAM/disk threshold alerts delivered as Android notifications
- **Dark & Light theme** — AMOLED black or soft gray
- **Server Color Profiles** — Color-code each server for easy identification

## Backend Setup

```bash
pip3 install garudan-server
garudan-server setup
garudan-server start
```

See [garudan-server](https://github.com/ajayaimannan/garudan-server) for full docs.

## Connect from Anywhere

**Cloudflare Tunnel (recommended):**
Add your server to an existing tunnel config pointing to `http://localhost:8400`.

**Tailscale:**
Install on both server and phone — use `http://100.x.x.x:8400` as API URL.

**Local Network:**
Find IP with `ip addr | grep 192.168` — use `http://192.168.x.x:8400` on home WiFi.

## Build from Source

```bash
git clone https://github.com/ajayaimannan/garudan
cd garudan
flutter pub get
flutter build apk --release
```

## License

MIT
