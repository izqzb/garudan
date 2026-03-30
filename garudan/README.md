# Garudan

Open-source mobile control panel for self-hosted servers. Built with Flutter.

**Best-in-class SSH terminal · Docker management · File browser · System monitoring**

## Download

Get the latest APK from the [Releases](../../releases) tab.

Minimum: Android 8.0+ (API 26)

## Features

- **Terminal** — Multi-tab SSH with auto-reconnect, 7 color themes, Ctrl key toolbar, pinch-to-zoom, command snippets
- **Docker** — Container list, start/stop/restart/logs, live stats
- **Files** — Full file browser with upload/download/edit/rename/delete
- **Dashboard** — CPU, RAM, disk, per-core usage, uptime — auto-refreshed
- **Processes** — Top processes by CPU/MEM, kill support
- **Profiles** — Unlimited server profiles, Tailscale fallback URL

## Backend Setup

Garudan requires `garudan-server` running on your server:

```bash
pip3 install garudan-server
garudan-server setup
garudan-server start
```

Then add the server URL in the app.

## Build from Source

```bash
git clone https://github.com/your-username/garudan
cd garudan
flutter pub get
flutter build apk --release
```

## Contributing

PRs welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
