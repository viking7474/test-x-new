# IOS-03 — Versioned iOS database

## Runtime contract

`schemaVersion` versions the manifest/parser contract. `databaseVersion` versions the model/build data generation and must increase monotonically (numeric dotted or date-based values are recommended). The two concepts are intentionally independent.

The active manifest is:

`/var/mobile/Library/WeaponX/Data/ios_database_manifest.json`

Both JSON payload paths are relative to the manifest directory. Each payload remains schema v1 and may optionally repeat the same `databaseVersion`. The manifest requires an ISO-8601 `generatedAt`, reader compatibility, and the lowercase SHA-256 of each payload.

## Publication rules

- Parse and verify both payloads before publication.
- Reject unsupported manifest/payload schemas and readers.
- Reject absolute paths, traversal, malformed hashes, or checksum mismatches.
- Reject duplicate/invalid models, unknown device references, dangling build references, and malformed build metadata.
- Reject a payload-level `databaseVersion` that differs from the manifest.
- Reject process-local database downgrades, including versioned-to-legacy fallback.
- Publish both roots as one immutable generation.
- `reload:` retains the exact last-known-good generation if the candidate fails.
- `databaseVersion` and `databaseMetadata` expose diagnostics to callers.

## Legacy compatibility

If no manifest exists and no versioned generation has previously been accepted in the process, the two old top-level files still load as `legacy-v1`:

- `ios_build_db.json`
- `iphone_model_db.json`

A present but invalid manifest fails closed and never silently falls back to those files.

## Deployment sequence

1. Write both payloads into a new version directory.
2. Compute SHA-256 for the final bytes and fill the manifest.
3. Validate that both JSON files use `schemaVersion: 1` and, when present, the same `databaseVersion` as the manifest.
4. Atomically replace `ios_database_manifest.json` last.
5. Call `reload:`. If verification fails, the process continues using last-known-good.

`data/ios_database_manifest.example.json` is a template only; replace its zero hashes before deployment.
