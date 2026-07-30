# Phase 10 release checklist

## Machine-verifiable sign-off

- [x] Phase 2–9 static regression suites are included in the release gate.
- [x] Multi-model/iOS matrix covers iPhone, iPad, cellular, Wi-Fi-only and iOS 12–17.
- [x] Repeated subprocess runs fail on crash, timeout or non-zero exit.
- [x] Per-suite and total performance budgets are enforced.
- [x] Final `.deb` is scanned after extraction for Research/test content.
- [x] Release build forces `FINALPACKAGE=1 DEBUG=0 INTERNAL_SECURITY_RESEARCH=0`.
- [x] Redaction, external-key and privacy contracts are audited.
- [x] Hardening report is attached to the CI artifact.

## Device/release-owner sign-off

These items must be completed for each candidate artifact; source-only CI cannot sign them on behalf of a release owner.

- [ ] Install/upgrade/uninstall smoke test on the oldest supported iOS device.
- [ ] Profile switch soak test on at least one iPhone and one iPad.
- [ ] Quick/Full/Deep Clear Data timing captured and compared with baseline.
- [ ] Backup/restore tamper and rollback test completed on a disposable profile.
- [ ] Crash logs reviewed; no new crash signature remains open.
- [ ] Privacy review confirms diagnostics contain no raw identifier, path, key material or profile content.
- [ ] Release owner: ____________________
- [ ] Commit: ___________________________
- [ ] Artifact SHA-256: _________________
- [ ] Signed at (UTC): __________________

A release is **not signed** while any device/release-owner item is blank.
