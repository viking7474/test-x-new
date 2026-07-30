# Phase 10 — Release hardening

Phase 10 turns the existing policy tests into a repeatable release gate.

## Gates

1. **Regression matrix** — repeats Phase 2–9 contracts against a 12-case iPhone/iPad and iOS 12–17 fixture matrix. Every subprocess has a timeout; any crash, non-zero exit or timeout fails the gate.
2. **Performance budget** — records each suite duration, total duration and slowest test. CI rejects a single suite over 120 seconds or a complete iteration over 300 seconds.
3. **Release package audit** — extracts the final `.deb` and rejects Research providers, Research settings, test constructors, fixture identifiers and internal-research build markers in file names or payload bytes.
4. **Privacy audit** — verifies redacted Lockdown diagnostics, absence of logging from Research providers, external-only backup keys, and release compilation with debug/research disabled.
5. **Release checklist** — `docs/Phase-10-release-checklist.md` records machine and device sign-off requirements. CI writes `release-hardening-report.json` for the exact commit and artifact.

## Commands

```sh
python3 scripts/release_hardening.py source
python3 scripts/release_hardening.py regression --iterations 2 --report release-hardening-report.json
python3 scripts/release_hardening.py package --artifact packages/<release>.deb --report package-hardening-report.json
```

For an actual release, build only with:

```sh
make package FINALPACKAGE=1 DEBUG=0 INTERNAL_SECURITY_RESEARCH=0
```

The package audit is intentionally performed after packaging; checking only Makefile expansion is not accepted as proof that Research code is absent.
