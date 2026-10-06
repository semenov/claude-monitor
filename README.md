# claude-monitor

An iOS app and widget that show how much of your Claude subscription limits you've used:
the current session and the weekly limits, with countdowns to their reset.

- `backend/`: Go server that runs `claude -p /usage` on your Mac, parses it and serves `GET /api/usage`
  (60 s cache, `?refresh=1` forces a fetch). Meant to run under [homebase](https://github.com/semenov/homebase).
- `ios/`: SwiftUI app (XcodeGen).
- `ios/Widget/`: WidgetKit extension (home screen small/medium, lock screen circular/rectangular/inline).
  Fetches on its own every ~15 min; shares settings and the last response with the app via an App Group.
- `ios/Shared/`: model, API client and theme, shared by the app and the widget.
- `tools/make_icon.py`: renders the app icon.

## Backend

```sh
homebase add claude-monitor -dir "$PWD/backend" -- 'go build -o claude-monitor . && exec ./claude-monitor'
homebase start claude-monitor --wait
homebase share claude-monitor --private   # https://claude-monitor.<your-domain>, needs X-Homebase-Token
```

The token is in the `share_link` from `homebase ls claude-monitor --json`.

## iOS app

```sh
cd ios
cp Local.xcconfig.example Local.xcconfig               # your Team ID
cp Shared/Secrets.swift.example Shared/Secrets.swift   # server URL and token
xcodegen generate
xcodebuild -scheme ClaudeMonitor -configuration Release -destination 'id=<device-udid>' \
  -derivedDataPath build/device -allowProvisioningUpdates build
xcrun devicectl device install app --device <device-udid> "build/device/Build/Products/Release-iphoneos/Claude Usage.app"
```

`xcrun devicectl list devices` shows the UDID. The server URL and token can also be changed in the app's Settings.
