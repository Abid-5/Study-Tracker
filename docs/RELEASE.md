# Release Checklist

Use this checklist before publishing a DMG.

## Local Validation

```bash
swift build
./script/build_and_run.sh --verify
./script/build_dmg.sh
codesign --verify --deep --strict "dist/release/Study Tracker.app"
hdiutil verify "dist/Study Tracker-0.1.dmg"
```

## Artifacts

- Release app: `dist/release/Study Tracker.app`
- DMG: `dist/Study Tracker-0.1.dmg`

## Public Distribution

For public distribution outside local testing:

1. Sign the `.app` with a Developer ID Application certificate.
2. Build the DMG from the signed app.
3. Notarize the DMG with Apple.
4. Staple the notarization ticket.
5. Re-run Gatekeeper validation on a clean Mac.
