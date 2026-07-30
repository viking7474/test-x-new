#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def text(path):
    return (ROOT / path).read_text(encoding="utf-8")

def require(condition, message):
    if not condition:
        raise AssertionError(message)

ua = text("common/PXUserAgentNormalizer.m")
hooks = text("ProjectXTweak/IOSVersionHooks.x")
cell = text("common/PXCellularIdentitySchema.m")
deps = text("common/PXIdentityDependencyValidator.m")
envelope = text("common/PXBackupAuthenticatedEnvelope.m")
provenance = text("common/PXBackupProvenance.m")

# WEB-01/02
require("PXNormalizeUserAgent" in ua and "Version/" in ua and "Mobile/" in ua,
        "central UA normalizer missing")
require("PXNormalizeUserAgent(*userAgentString" in hooks,
        "legacy UA surfaces do not delegate to central normalizer")
require("PXCanonicalWebIdentityHeaders" in hooks and "managedIdentityHeaders" in hooks,
        "managed web identity headers are not synchronized")
require("PXWebKitHelperProcessIsInScope" in hooks and "PXScopeOptionAllowSafariAuthStack" in hooks,
        "WebKit helper scope is not fail closed")
for forbidden in ("securityd", "trustd", "accountsd", "authkit", "akd"):
    require(forbidden in ua, f"missing helper exclusion: {forbidden}")
require("certificate" not in ua.lower() and "tls" not in ua.lower(),
        "web identity module must not weaken TLS or certificate validation")

# CELL-01
for key in ("physicalSIM", "eSIM", "dualSIM", "cdma", "IMEI2", "ICCID", "IMSI", "BasebandVersion"):
    require(key in cell, f"missing cellular schema contract: {key}")
require("explicit-cellular-capability-required" in cell,
        "cellular capability must be explicit when identifiers exist")
require("cellular-identifiers-on-noncellular-model" in cell,
        "Wi-Fi-only model rejection missing")
require("PXValidateCellularIdentitySchema(deviceIDs, model)" in deps,
        "dependency validator does not enforce cellular schema")

# BACKUP-01 primitives
for token in ("kCCAlgorithmAES", "kCCHmacAlgSHA256", "SecRandomCopyBytes", "PXConstantTimeEqual"):
    require(token in envelope, f"authenticated envelope missing: {token}")
require("externalKey.length != 64" in envelope,
        "envelope must require separate encryption and MAC keys")
require("authenticationTag" in envelope and envelope.index("PXConstantTimeEqual") < envelope.index("kCCDecrypt"),
        "authentication must be verified before decryption")
require("keyMaterialStored\"] = @NO" not in provenance,
        "unexpected mutable key-material flag")
for token in ("profileGeneration", "sourceBundleID", "selectedScope", "keyIdentifier", "keyMaterialStored"):
    require(token in provenance, f"backup provenance missing: {token}")
require("PXBackupProvenanceMatchesRestoreContext" in provenance,
        "restore provenance binding missing")

print("Phase-9 web/cellular/backup contracts: PASS")
