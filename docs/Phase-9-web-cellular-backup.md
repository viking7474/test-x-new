# Phase 9 — Web, Cellular and Backup

## WEB-01 / WEB-02

- `PXUserAgentNormalizer` is the single version/build-token normalizer for all existing WKWebView, custom-UA, request-header and Safari UA call sites.
- Normalization is idempotent and can independently control the `Mobile/<build>` token.
- Managed request headers are canonicalized without discarding unrelated application headers: `Accept-Language`, `Sec-CH-UA-Platform`, and `Sec-CH-UA-Mobile`.
- WebKit/Safari helper processes require explicit Safari-stack scope. Security, trust and account helpers fail closed.
- Sensitive-host exemptions remain active. No TLS, trust or certificate-validation hook is introduced.

## CELL-01

- Model records express physical SIM, eSIM, dual-SIM and CDMA capabilities.
- Telephony identifiers require an explicit cellular model capability and are rejected for Wi-Fi-only models.
- IMEI/IMEI2/MEID/ICCID/IMSI/Baseband values are canonicalized or rejected.
- IMEI2 requires both a primary IMEI and dual-SIM capability; MEID requires CDMA; cellular models require a baseband version.
- The unified dependency validator invokes this policy even when model resolution fails, preventing identifiers from escaping through a missing-schema path.

## BACKUP-01

- `PXBackupAuthenticatedEnvelope` provides an encrypt-then-MAC binary envelope using AES-256-CBC and HMAC-SHA256.
- A random IV is generated with `SecRandomCopyBytes`; the authentication tag covers algorithm, external key identifier, IV, ciphertext and provenance-associated data.
- Authentication is checked in constant time before any decryption.
- The caller supplies a 64-byte external key (32-byte encryption key plus 32-byte MAC key). Raw key material is never serialized in the envelope or provenance.
- `PXBackupProvenance` binds source bundle, profile ID, profile generation, selected scope, algorithm and external key identifier. Restore matching fails closed on any mismatch.

## Profile-switch contract

For profile A at generation N followed by profile B at generation N+1:

1. Web and cellular reads are sourced from the newest immutable identity snapshot.
2. Backup provenance is generated for B/N+1 and used as authenticated associated data.
3. Restore under A/N, another bundle, another generation or another selected scope is rejected.

## Validation

Run:

```sh
python3 scripts/test_phase9_web_cellular_backup_static.py
```

The repository's Phase 2–8 static suites and backup/restore hardening audit remain regression gates.
