#!/usr/bin/env python3
"""Static contract for P0-05 VPN manager and discovery side-channel closure."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "TLinkIOSTweak" / "VPNDetectionBypass.x").read_text(encoding="utf-8")
UI = (ROOT / "VPNDetectionDetailViewController.m").read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def function_body(text: str, name: str) -> str:
    match = re.search(rf"\b{name}\s*\([^;]*?\)\s*\{{", text, re.S)
    require(match is not None, f"missing function: {name}")
    start = match.end() - 1
    depth = 0
    for index in range(start, len(text)):
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                return text[start + 1:index]
    raise AssertionError(f"unterminated function: {name}")


vpn_block = SOURCE.split("static PXVPNRuntimeRule gPXVPNRuntimeRules[] = {", 1)[1].split("};", 1)[0]
vpn_rules = set(re.findall(r'\{ "([^"]+)", "([^"]+)",', vpn_block))
expected_vpn_rules = {
    ("NEVPNManager", "+sharedManager"),
    ("NEVPNManager", "+loadedManagers"),
    ("NEVPNManager", "connection"),
    ("NEVPNManager", "isEnabled"),
    ("NETunnelProviderManager", "+loadAllFromPreferencesWithCompletionHandler:"),
    ("NEVPNConnection", "status"),
}
require(vpn_rules == expected_vpn_rules, f"VPN runtime rule inventory drifted: {vpn_rules}")

discovery_block = SOURCE.split("static PXDiscoveryRuntimeRule gPXDiscoveryRuntimeRules[] = {", 1)[1].split("};", 1)[0]
discovery_rules = set(re.findall(r'\{ "([^"]+)", "([^"]+)",', discovery_block))
expected_discovery_rules = {
    ("MCNearbyServiceBrowser", "startBrowsingForPeers"),
    ("MCNearbyServiceBrowser", "syncStartBrowsingForPeers"),
    ("MCNearbyServiceBrowser", "syncStopBrowsingForPeers"),
    ("CBCentralManager", "scanForPeripheralsWithServices:options:"),
    ("NSNetServiceBrowser", "searchForBrowsableDomains"),
    ("NSNetServiceBrowser", "searchForRegistrationDomains"),
    ("NSNetServiceBrowser", "searchForServicesOfType:inDomain:"),
    ("NSNetServiceBrowser", "searchForAllDomains"),
}
require(discovery_rules == expected_discovery_rules,
        f"discovery runtime rule inventory drifted: {discovery_rules}")

for token in (
    'kPXVPNBypassSettingKey = @"vpnDetectionBypassEnabled"',
    'kPXDiscoverySuppressionSettingKey = @"discoverySuppressionEnabled"',
    "PXVPNBypassActive",
    "PXDiscoverySuppressionActive",
    "class_getImageName",
    "class_getInstanceMethod",
    "PXVPNRuleEncodingIsValid",
    "PXRuntimeMethodHasShape",
    "PXInstallVPNManagerRuntimeHooks();",
    "PXInstallDiscoveryRuntimeHooks();",
    "capability audit vpn-manager=%lu/6 discovery=%lu/8",
):
    require(token in SOURCE, f"P0-05 runtime contract is missing: {token}")
require("class_addMethod" not in SOURCE, "P0-05 must not synthesize unsupported runtime APIs")

object_getter = function_body(SOURCE, "PXHookVPNObjectGetter")
require(object_getter.index("rule->original") < object_getter.index("PXVPNBypassActive()"),
        "VPN object getters must call the original implementation first")
require('sel_registerName("loadedManagers")' in object_getter and "return @[];" in object_getter,
        "+loadedManagers must project an empty manager collection")
require("return original;" in object_getter,
        "sharedManager and connection must preserve framework-owned object identity")

bool_getter = function_body(SOURCE, "PXHookVPNBoolGetter")
status_getter = function_body(SOURCE, "PXHookVPNStatusGetter")
require(bool_getter.index("rule->original") < bool_getter.index("PXVPNBypassActive() ? NO"),
        "-isEnabled must be original-first and project false only when active")
require(status_getter.index("rule->original") < status_getter.index("PXVPNBypassActive() ? 1"),
        "-status must be original-first and project NEVPNStatusDisconnected only when active")

load_managers = function_body(SOURCE, "PXHookVPNLoadManagers")
for token in ("original(self, _cmd, completion)", "completion(@[], error)", "original(self, _cmd, projected)"):
    require(token in load_managers, f"tunnel manager completion semantics are incomplete: {token}")
require("dispatch_" not in load_managers,
        "the wrapper must preserve NetworkExtension's callback queue and cardinality")

for name in ("PXHookDiscoveryVoid0", "PXHookDiscoveryVoid2"):
    body = function_body(SOURCE, name)
    require("if (!PXDiscoverySuppressionActive())" in body and "rule->original" in body,
            f"{name} must forward normally while the independent capability is off")
    require("Suppressed discovery selector" in body,
            f"{name} must suppress and audit discovery only while explicitly enabled")

for token in (
    "%hook NWPath",
    "usesInterfaceType:",
    "%hook NWInterface",
    "PXVPNInterfaceNameIsSensitive",
    "return (PXVPNBypassActive() && original == 0) ? 1 : original;",
):
    require(token in SOURCE, f"VPN manager projection is inconsistent with network surfaces: {token}")

for token in (
    'PXReadSecurityBool(@"discoverySuppressionEnabled", NO)',
    'PXWriteSecurityBool(@"discoverySuppressionEnabled", enabled, &error)',
    "discoveryToggleChanged:",
    'CFSTR("com.hydra.tlinkios.settings.changed")',
):
    require(token in UI, f"discovery capability UI/default-off contract is missing: {token}")

print("P0-05 VPN/discovery static test: PASS")
print(f"vpn_rules={len(vpn_rules)} discovery_rules={len(discovery_rules)} default_off=yes")
