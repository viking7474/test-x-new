#!/bin/sh

echo "Setting up TLinkIOS app..."

# Rootful jailbreak - no prefix needed
JBPREFIX=""
echo "Detected rootful jailbreak"

# For backwards compatibility with MobileSubstrate
echo "Setting up MobileSubstrate directories (for compatibility)..."
mkdir -p /Library/MobileSubstrate/DynamicLibraries
chmod 755 /Library/MobileSubstrate
chmod 755 /Library/MobileSubstrate/DynamicLibraries

# Ensure the dylib has proper permissions
echo "Setting up tweak permissions..."
if [ -f "/Library/MobileSubstrate/DynamicLibraries/TLinkIOSTweak.dylib" ]; then
    chmod 644 /Library/MobileSubstrate/DynamicLibraries/TLinkIOSTweak.dylib
fi

if [ -f "/Library/MobileSubstrate/DynamicLibraries/TLinkIOSTweak.plist" ]; then
    chmod 644 /Library/MobileSubstrate/DynamicLibraries/TLinkIOSTweak.plist
fi

# Ensure app permissions are correct
if [ -d "/Applications/TLinkIOS.app" ]; then
    echo "Setting app permissions..."
    chmod 755 /Applications/TLinkIOS.app
    chmod 755 /Applications/TLinkIOS.app/TLinkIOS
    
    # Force app registration with SpringBoard
    echo "Registering app with SpringBoard..."
    if command -v uicache >/dev/null 2>&1; then
        uicache --path /Applications/TLinkIOS.app
    fi
else
    echo "App not found in expected locations"
fi

# Handle SpringBoard reload based on available tools
if [ -f "/usr/bin/sbreload" ]; then
    echo "Reloading SpringBoard using sbreload..."
    /usr/bin/sbreload
elif [ -f "/usr/bin/ldrestart" ]; then
    echo "Light restarting device..."
    /usr/bin/ldrestart
else
    echo "Restarting SpringBoard directly..."
    killall -9 SpringBoard
fi

echo "Setup complete!"