TARGET ?= iphone:clang:16.5:12.0
ARCHS ?= arm64 arm64e

# RootHide uses a randomized jbroot and the iphoneos-arm64e package lane. The
# official RootHide Theos fork supplies this package scheme and linker rewriting.
ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
TARGET := iphone:clang:16.5:15.0
ARCHS := arm64
DEB_ARCH := iphoneos-arm64e
endif
LOGOS_DEFAULT_GENERATOR = internal
INSTALL_TARGET_PROCESSES = SpringBoard TLinkIOS
DEBUG=1
FINALPACKAGE=0

# Phase 4: Research code is opt-in and forbidden in final/release packages.
INTERNAL_SECURITY_RESEARCH ?= 0
ifeq ($(INTERNAL_SECURITY_RESEARCH),1)
ifneq ($(filter 1 YES yes true TRUE,$(FINALPACKAGE)),)
$(error INTERNAL_SECURITY_RESEARCH must be 0 when FINALPACKAGE is enabled)
endif
endif

# Note: This project now includes a Notification Service Extension for rich push notifications
# The extension needs to be manually added in Xcode after installing this package
# See /NotificationServiceExtension/README.md for integration instructions

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = TLinkIOS
TOOL_NAME = WeaponXDaemon backup_helper



# App files
TLinkIOS_FILES = $(wildcard *.m) $(wildcard common/*.m) KeychainHelper/PXKeychainHelperResult.m
TLinkIOS_RESOURCE_DIRS = Assets.xcassets
TLinkIOS_RESOURCE_FILES = Info.plist Icon.png LaunchScreen.storyboard
TLinkIOS_PRIVATE_FRAMEWORKS = FrontBoardServices SpringBoardServices BackBoardServices StoreKitUI MobileCoreServices
# TLinkIOS_LDFLAGS = -I./common
TLinkIOS_FRAMEWORKS = Foundation MobileCoreServices CoreServices StoreKit IOKit CoreLocation
# UIKit, Security and CoreLocationUI are weak-linked for iOS 12+ compatibility
# UIButtonConfiguration and SecTrustCopyCertificateChain are iOS 15+ only
TLinkIOS_LDFLAGS = -weak_framework UIKit -weak_framework CoreLocationUI -weak_framework Security -lsqlite3 -lz
TLinkIOS_CODESIGN_FLAGS = -Sent.plist
TLinkIOS_CFLAGS = -fobjc-arc -D SUPPORT_IPAD=1 -D ENABLE_STATE_RESTORATION=1 -I./common

# Daemon files
# common/PXInjectionFilter.m is the shared IOS-08 injection-filter source of truth
# (pure Foundation) reused by the mount daemon to validate filter plists.
WeaponXDaemon_FILES = WeaponXMountDaemon/WeaponXDaemon.m common/PXInjectionFilter.m
WeaponXDaemon_CFLAGS = -fobjc-arc -I./common
WeaponXDaemon_FRAMEWORKS = Foundation IOKit
WeaponXDaemon_INSTALL_PATH = /Library/WeaponX
WeaponXDaemon_CODESIGN_FLAGS = -Sdaemon_ent.plist
WeaponXDaemon_LDFLAGS = -framework IOKit

# Keychain Helper Tool - CLI for backup/restore/wipe keychain items
backup_helper_FILES = KeychainHelper/backup_helper.m KeychainHelper/KeychainBackupHelper.m KeychainHelper/PXKeychainHelperResult.m KeychainHelper/PXKeychainItemIdentity.m
backup_helper_CFLAGS = -fobjc-arc -Wno-error=unused-variable
backup_helper_FRAMEWORKS = Foundation Security
backup_helper_INSTALL_PATH = /Library/WeaponX
backup_helper_CODESIGN_FLAGS = -Skeychain_base_ent.plist

# Ensure app is installed to the correct location with proper permissions
TLinkIOS_INSTALL_PATH = /Applications
TLinkIOS_APPLICATION_MODE = 0755

# Make sure both tweak and application are built
all::
	@echo "Building tweak, application, and daemon..."

# Tweak Configuration (Moved from TLinkIOSTweak/Makefile)
TWEAK_NAME = TLinkIOSTweak WeaponXKeychainBridge

# Files - Adjusted paths for root compilation
# Production safety (BUILD-01/P0): AAA_* files are test-only +load/constructor
# artifacts that run on EVERY injected process (writing marker files to disk).
# They must never ship in any build, so filter them out of the wildcard. This
# stops a stray AAA_* file from silently regressing production.
# Retired URL-monitoring code is excluded from broad injection builds.
TLinkIOSTweak_FILES = $(filter-out TLinkIOSTweak/UberURLHooks.x,$(wildcard TLinkIOSTweak/*.x)) $(filter-out TLinkIOSTweak/AAA_%,$(wildcard TLinkIOSTweak/*.m)) $(wildcard common/*.m)

# CFlags - Adjusted include paths
TLinkIOSTweak_CFLAGS = -fobjc-arc -Wno-error=unused-variable -Wno-error=unused-function -I./common -I./include -D USES_LIBUNDIRECT=1 -D SUPPORT_IPAD=1 -D ENABLE_STATE_RESTORATION=1

ifeq ($(INTERNAL_SECURITY_RESEARCH),1)
# Explicit allowlist only: never use a research/*.m wildcard.
TLinkIOSTweak_FILES += research/PXLockdownResearchSafety.m
TLinkIOSTweak_FILES += research/PXLockdownSoftwareModelProvider.m
TLinkIOSTweak_FILES += research/PXLockdownDeviceIdentityProvider.m
TLinkIOSTweak_FILES += research/PXLockdownSoCCellularProvider.m
TLinkIOSTweak_FILES += research/PXLockdownObservability.m
TLinkIOSTweak_CFLAGS += -DINTERNAL_SECURITY_RESEARCH=1 -I./research
else
TLinkIOSTweak_CFLAGS += -DINTERNAL_SECURITY_RESEARCH=0
endif

# Frameworks and Libraries
TLinkIOSTweak_FRAMEWORKS = UIKit Foundation AdSupport UserNotifications IOKit Security CoreLocation CoreMotion CoreFoundation Network CoreTelephony SystemConfiguration WebKit SafariServices
TLinkIOSTweak_PRIVATE_FRAMEWORKS = MobileCoreServices AppSupport SpringBoardServices
TLinkIOSTweak_LIBRARIES = MobileGestalt

# Linker Flags
# -lobjc: force link libobjc
# -Wl,-ObjC: load all ObjC classes/categories
# -Wl,-no_fixup_chains: DISABLE chained fixups (Xcode 15+ default) which break iOS 12/13 compatibility
# -Wl,-undefined,dynamic_lookup: standard for tweaks
TLinkIOSTweak_LDFLAGS = -lobjc -Wl,-ObjC -Wl,-no_fixup_chains -Wl,-undefined,dynamic_lookup

# Keychain Bridge Tweak (minimal, in-app keychain export/import)
WeaponXKeychainBridge_FILES = WeaponXKeychainBridge/Tweak.m
WeaponXKeychainBridge_CFLAGS = -fobjc-arc -Wno-error=unused-variable -Wno-error=unused-function
WeaponXKeychainBridge_FRAMEWORKS = Foundation Security CoreFoundation
WeaponXKeychainBridge_LDFLAGS = -lobjc -Wl,-ObjC -Wl,-no_fixup_chains -Wl,-undefined,dynamic_lookup

# Include makefiles
include $(THEOS_MAKE_PATH)/application.mk
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/tool.mk

# Custom rule to ensure our scripts are included in the package
internal-stage::
	@echo "Adding custom scripts to package..."
	@mkdir -p $(THEOS_STAGING_DIR)/DEBIAN
	@cp -a DEBIAN/postinst $(THEOS_STAGING_DIR)/DEBIAN/
	@cp -a DEBIAN/preinst $(THEOS_STAGING_DIR)/DEBIAN/
	@cp -a DEBIAN/prerm $(THEOS_STAGING_DIR)/DEBIAN/
	@chmod 755 $(THEOS_STAGING_DIR)/DEBIAN/postinst
	@chmod 755 $(THEOS_STAGING_DIR)/DEBIAN/preinst
	@chmod 755 $(THEOS_STAGING_DIR)/DEBIAN/prerm
	@echo "Adding setup script to package..."
	@mkdir -p $(THEOS_STAGING_DIR)/usr/bin
	@cp -a setup_app.sh $(THEOS_STAGING_DIR)/usr/bin/tlinkios-setup
	@chmod 755 $(THEOS_STAGING_DIR)/usr/bin/tlinkios-setup
	@echo "Creating MobileSubstrate directories for compatibility..."
	@mkdir -p $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/
	@if [ "$(THEOS_PACKAGE_SCHEME)" = "roothide" ]; then \
		echo "RootHide: preserving Theos-staged tweak binaries and filters"; \
		test -f $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/TLinkIOSTweak.dylib; \
		test -f $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/TLinkIOSTweak.plist; \
		test -f $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/WeaponXKeychainBridge.dylib; \
		test -f $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/WeaponXKeychainBridge.plist; \
	else \
		cp -a $(THEOS_OBJ_DIR)/TLinkIOSTweak.* $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/; \
		cp -a $(THEOS_OBJ_DIR)/WeaponXKeychainBridge.* $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/; \
	fi
	@echo "Ensuring LaunchScreen.storyboard is properly compiled..."
	@if [ -f "LaunchScreen.storyboard" ]; then \
		mkdir -p $(THEOS_STAGING_DIR)/Applications/TLinkIOS.app/; \
		ibtool --compile $(THEOS_STAGING_DIR)/Applications/TLinkIOS.app/LaunchScreen.storyboardc LaunchScreen.storyboard || true; \
		cp -a LaunchScreen.storyboard $(THEOS_STAGING_DIR)/Applications/TLinkIOS.app/; \
	fi
	@echo "Adding LaunchDaemon for persistent operation..."
	@mkdir -p $(THEOS_STAGING_DIR)/Library/LaunchDaemons
	@mkdir -p $(THEOS_STAGING_DIR)/Library/WeaponX/Guardian
	@if [ "$(THEOS_PACKAGE_SCHEME)" != "roothide" ]; then mkdir -p $(THEOS_STAGING_DIR)/var/mobile/Library/Preferences; fi
	@cp -a com.hydra.weaponx.guardian.plist $(THEOS_STAGING_DIR)/Library/LaunchDaemons/
	@chmod 644 $(THEOS_STAGING_DIR)/Library/LaunchDaemons/com.hydra.weaponx.guardian.plist
	@chmod 755 $(THEOS_STAGING_DIR)/Library/WeaponX
	@chmod 755 $(THEOS_STAGING_DIR)/Library/WeaponX/Guardian
	@touch $(THEOS_STAGING_DIR)/Library/WeaponX/Guardian/daemon.log
	@touch $(THEOS_STAGING_DIR)/Library/WeaponX/Guardian/guardian-stdout.log
	@touch $(THEOS_STAGING_DIR)/Library/WeaponX/Guardian/guardian-stderr.log
	@chmod 664 $(THEOS_STAGING_DIR)/Library/WeaponX/Guardian/*.log
	@echo "Installing WeaponXDaemon..."
	@if [ "$(THEOS_PACKAGE_SCHEME)" = "roothide" ]; then \
		echo "RootHide: preserving Theos-staged WeaponXDaemon"; \
		test -x $(THEOS_STAGING_DIR)/Library/WeaponX/WeaponXDaemon; \
	else \
		cp -a $(THEOS_OBJ_DIR)/WeaponXDaemon $(THEOS_STAGING_DIR)/Library/WeaponX/; \
	fi
	@chmod 755 $(THEOS_STAGING_DIR)/Library/WeaponX/WeaponXDaemon
	@echo "Installing backup_helper tool..."
	@if [ "$(THEOS_PACKAGE_SCHEME)" = "roothide" ]; then \
		echo "RootHide: preserving Theos-staged backup_helper"; \
		test -x $(THEOS_STAGING_DIR)/Library/WeaponX/backup_helper; \
	else \
		cp -a $(THEOS_OBJ_DIR)/backup_helper $(THEOS_STAGING_DIR)/Library/WeaponX/; \
	fi
	@chmod 755 $(THEOS_STAGING_DIR)/Library/WeaponX/backup_helper
	@echo "Installing keychain backup script..."
	@cp -a scripts/keychain_backup.sh $(THEOS_STAGING_DIR)/Library/WeaponX/
	@chmod 755 $(THEOS_STAGING_DIR)/Library/WeaponX/keychain_backup.sh
	@echo "Adding debug tools..."
	@mkdir -p $(THEOS_STAGING_DIR)/usr/bin
	@cp -a weaponx-debug.sh $(THEOS_STAGING_DIR)/usr/bin/weaponx-debug
	@chmod 755 $(THEOS_STAGING_DIR)/usr/bin/weaponx-debug
	@echo "Installing carrier database..."
	@mkdir -p $(THEOS_STAGING_DIR)/Library/WeaponX/Data
	@if [ "$(THEOS_PACKAGE_SCHEME)" != "roothide" ]; then mkdir -p $(THEOS_STAGING_DIR)/var/mobile/Library/WeaponX/Data; fi
	@if [ -f "data/carrier_db.json" ]; then \
		cp -a data/carrier_db.json $(THEOS_STAGING_DIR)/Library/WeaponX/Data/; \
		chmod 644 $(THEOS_STAGING_DIR)/Library/WeaponX/Data/carrier_db.json; \
		if [ "$(THEOS_PACKAGE_SCHEME)" != "roothide" ]; then cp -a data/carrier_db.json $(THEOS_STAGING_DIR)/var/mobile/Library/WeaponX/Data/; chmod 644 $(THEOS_STAGING_DIR)/var/mobile/Library/WeaponX/Data/carrier_db.json; fi; \
	fi
	@echo "Installing versioned iOS database..."
	@for f in ios_build_db.json iphone_model_db.json; do \
		if [ -f "data/$$f" ]; then \
			cp -a "data/$$f" $(THEOS_STAGING_DIR)/Library/WeaponX/Data/; \
			chmod 644 "$(THEOS_STAGING_DIR)/Library/WeaponX/Data/$$f"; \
			if [ "$(THEOS_PACKAGE_SCHEME)" != "roothide" ]; then cp -a "data/$$f" $(THEOS_STAGING_DIR)/var/mobile/Library/WeaponX/Data/; chmod 644 "$(THEOS_STAGING_DIR)/var/mobile/Library/WeaponX/Data/$$f"; fi; \
		fi; \
	done

export CFLAGS = -fobjc-arc -Wno-error

TLinkIOSCLI_FILES = TLinkIOSCLIbinary.m DeviceNameManager.m IdentifierManager.m IDFAManager.m IDFVManager.m WiFiManager.m SerialNumberManager.m TLinkIOSLogging.m ProfileManager.m IOSVersionInfo.m
TLinkIOSCLI_CFLAGS = -fobjc-arc -Wno-error=unused-variable -Wno-error=unused-function -I$(THEOS_VENDOR_INCLUDE_PATH)
TLinkIOSCLI_FRAMEWORKS = UIKit Foundation AdSupport UserNotifications IOKit Security
TLinkIOSCLI_PRIVATE_FRAMEWORKS = MobileCoreServices AppSupport
TLinkIOSCLI_LDFLAGS = -L$(THEOS_VENDOR_LIBRARY_PATH)

after-package::
	@echo "🔍 Checking package contents..."
	@mkdir -p $(THEOS_STAGING_DIR)/../debug
	@PACKAGE_FILE="$$(ls -t ./packages/com.hydra.tlinkios_*.deb | head -1)" && \
	if [ -f "$$PACKAGE_FILE" ]; then \
		echo "Extracting $$PACKAGE_FILE"; \
		(cd $(THEOS_STAGING_DIR)/../debug && ar -x "../../$$PACKAGE_FILE" && tar -xf data.tar.*); \
	else \
		echo "❌ Package file not found!"; \
		exit 1; \
	fi
	@echo "✅ Checking WeaponXDaemon executable..."
	@ls -la $(THEOS_STAGING_DIR)/../debug/Library/WeaponX/WeaponXDaemon || echo "❌ WeaponXDaemon not found!"
	@echo "✅ Checking LaunchDaemon plist..."
	@ls -la $(THEOS_STAGING_DIR)/../debug/Library/LaunchDaemons/com.hydra.weaponx.guardian.plist || echo "❌ LaunchDaemon plist not found!"
	@echo "✅ Checking Guardian directory and log files..."
	@ls -la $(THEOS_STAGING_DIR)/../debug/Library/WeaponX/Guardian/ || echo "❌ Guardian directory not found!"
	@echo "Package check completed!"

.PHONY: release-hardening release-package release-package-roothide package-roothide

# Theos exports invocation/schema state after its makefiles are included. Any
# project-level wrapper that starts a new top-level make must remove that state;
# otherwise the child skips `all`/`before-stage` and tries to stage stale
# `.theos/obj/debug` products into a staging directory that was never created.
THEOS_FRESH_MAKE = /usr/bin/env -u _THEOS_TOP_INVOCATION_DONE \
	-u THEOS_SCHEMA -u _THEOS_CLEANED_SCHEMA_SET $(MAKE)

release-hardening:
	python3 scripts/release_hardening.py regression --iterations 2 --report release-hardening-report.json

release-package:
	$(THEOS_FRESH_MAKE) clean FINALPACKAGE=1 DEBUG=0 INTERNAL_SECURITY_RESEARCH=0
	$(THEOS_FRESH_MAKE) package FINALPACKAGE=1 DEBUG=0 INTERNAL_SECURITY_RESEARCH=0

# Requires the official RootHide Theos fork:
# https://github.com/roothide/theos
package-roothide:
	$(THEOS_FRESH_MAKE) clean THEOS_PACKAGE_SCHEME=roothide ARCHS=arm64 \
		TARGET=iphone:clang:16.5:15.0 DEB_ARCH=iphoneos-arm64e DEBUG=1 FINALPACKAGE=0
	$(THEOS_FRESH_MAKE) package THEOS_PACKAGE_SCHEME=roothide ARCHS=arm64 \
		TARGET=iphone:clang:16.5:15.0 DEB_ARCH=iphoneos-arm64e \
		_THEOS_DEB_PACKAGE_CONTROL_PATH=$(CURDIR)/control.roothide

release-package-roothide:
	$(THEOS_FRESH_MAKE) clean THEOS_PACKAGE_SCHEME=roothide ARCHS=arm64 \
		TARGET=iphone:clang:16.5:15.0 DEB_ARCH=iphoneos-arm64e \
		FINALPACKAGE=1 DEBUG=0 INTERNAL_SECURITY_RESEARCH=0
	$(THEOS_FRESH_MAKE) package THEOS_PACKAGE_SCHEME=roothide ARCHS=arm64 \
		TARGET=iphone:clang:16.5:15.0 DEB_ARCH=iphoneos-arm64e \
		_THEOS_DEB_PACKAGE_CONTROL_PATH=$(CURDIR)/control.roothide \
		FINALPACKAGE=1 DEBUG=0 INTERNAL_SECURITY_RESEARCH=0

# SUBPROJECTS += TLinkIOSTweak
# include $(THEOS_MAKE_PATH)/aggregate.mk
