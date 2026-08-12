# 2 Baked

Flutter PWA dab timer with:
- Glass Dab Rig and C-Horse Luca Pro Plus presets
- Custom heat/cool timers
- Red heating phase / blue cooling phase
- TTS start + facts + completion lines
- Local dab counter and favorites
- Screen wake lock while timer is active
- App icon + splash screen
- GitHub Pages deployment workflow

## Run locally
```bash
flutter pub get
flutter run -d chrome
```

## Build for GitHub Pages manually
Replace `YOUR_REPO_NAME`:
```bash
flutter build web --release --base-href "/YOUR_REPO_NAME/"
```

## Deploy automatically
1. Push the project to a GitHub repo with `main` as the branch.
2. In GitHub: Settings -> Pages -> Source -> GitHub Actions.
3. Push again or run the workflow manually.
4. Open the Pages URL on iPhone Safari.
5. Share -> Add to Home Screen.

## Wake lock
The app requests a screen wake lock while a timer is running and releases it when done/reset.
