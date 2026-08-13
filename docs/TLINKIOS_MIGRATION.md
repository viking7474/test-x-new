# TLinkIOS rename and upgrade notes

Version 3.0.0 renames the ProjectX application and tweak while preserving the
existing WeaponX daemon and helper subsystem.

## Identity mapping

| Legacy | Current |
| --- | --- |
| `ProjectX.app/ProjectX` | `TLinkIOS.app/TLinkIOS` |
| `ProjectXTweak.dylib` | `TLinkIOSTweak.dylib` |
| `com.hydra.projectx` | `com.hydra.tlinkios` |
| `/var/mobile/Library/ProjectX` | `/var/mobile/Library/TLinkIOS` |
| `projectx://` | `tlinkios://` |

The Debian package declares `Conflicts`, `Replaces`, and `Provides` for the
legacy package ID so both tweak generations cannot remain installed together.

## Compatibility retained in 3.0.0

- The installer copies legacy preferences and application data when the new
  location is absent. It deliberately keeps the old copy for downgrade safety.
- Both old and new keychain access groups and application groups are present in
  the signing entitlements.
- `projectx://` remains registered as a URL alias.
- The injection filter recognizes the legacy application bundle and placeholder
  IDs so migrated scope files remain valid.
- Backup manifest schema `com.hydra.projectx.backup-manifest` is intentionally
  stable. It is a persisted data-format identifier, not a display name.

## Release validation

Validate both a clean install and an upgrade from 2.5.1. Confirm that the app,
tweak, WeaponX daemon, preferences, profiles, keychain access, backup restore,
URL aliases, and uninstall flow all work before removing any compatibility ID in
a later major release.
