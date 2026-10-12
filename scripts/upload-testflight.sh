#!/usr/bin/env zsh
# Baut die App (Release) und lädt sie zu App Store Connect / TestFlight hoch.
#
# Voraussetzungen (einmalig):
#   1. Bezahlter Apple Developer Account; Team-ID steht unter developer.apple.com/account → Membership details
#   2. Xcode → Settings → Accounts: mit derselben Apple-ID angemeldet
#   3. App Store Connect → Meine Apps → + : App mit Bundle-ID com.challengrapp.challengr angelegt
#
# Aufruf:   ./scripts/upload-testflight.sh <TEAM_ID>
# Die Build-Nummer wird automatisch aus Datum/Uhrzeit gesetzt (jeder Upload braucht eine neue).
set -euo pipefail

TEAM_ID="${1:-${TEAM_ID:-}}"
if [[ -z "$TEAM_ID" ]]; then
  echo "Aufruf: ./scripts/upload-testflight.sh <TEAM_ID>   (10 Zeichen, z. B. AB12CD34EF)"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT_DIR/Swift/Challengr/Challengr.xcodeproj"
BUILD_NUMBER="$(date +%y%m%d%H%M)"
WORK="$(mktemp -d)"
ARCHIVE="$WORK/Challengr.xcarchive"

cat > "$WORK/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST

echo "→ Archiv bauen (Version 1.0, Build $BUILD_NUMBER, Team $TEAM_ID)"
xcodebuild archive \
  -project "$PROJECT" -scheme Challengr -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  | grep -E "error:|ARCHIVE (SUCCEEDED|FAILED)" || true
[[ -d "$ARCHIVE" ]] || { echo "❌ Archiv fehlgeschlagen – Details: Xcode → Product → Archive"; exit 1; }

echo "→ Hochladen zu App Store Connect"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$WORK/ExportOptions.plist" \
  -exportPath "$WORK/export" \
  -allowProvisioningUpdates

echo "✅ Hochgeladen (Build $BUILD_NUMBER). In App Store Connect → TestFlight erscheint er nach der Verarbeitung (meist 5–30 Min)."
echo "   Archiv: $ARCHIVE (zum Öffnen in Xcode: open \"$ARCHIVE\")"
