#!/usr/bin/env bash
# Archiveert Garantiebewaarder en uploadt de build naar App Store Connect.
#
# Gebruik (zelf draaien; vereist een betaald Apple Developer-account en dat je in Xcode
# bent ingelogd met dat account: Xcode > Settings > Accounts):
#
#   TEAM_ID=ABCDE12345 Scripts/release.sh            # archiveren + uploaden
#   TEAM_ID=ABCDE12345 MODE=export Scripts/release.sh # alleen .ipa maken (build/export)
#   BUILD_NUMBER=2 TEAM_ID=... Scripts/release.sh     # nieuw buildnummer bij een volgende upload
#
# Met -allowProvisioningUpdates laat Xcode bij Apple de App ID's, de App Group en de iCloud-
# container aanmaken en de profielen ophalen. Dat wijzigt je developer-account.
set -euo pipefail

: "${TEAM_ID:?Zet TEAM_ID, bijvoorbeeld TEAM_ID=ABCDE12345 (te vinden op developer.apple.com > Membership)}"
MODE="${MODE:-upload}"
cd "$(dirname "$0")/.."

xcodegen generate
mkdir -p build
ARCHIVE="build/Garantiebewaarder.xcarchive"
rm -rf "$ARCHIVE" build/export

EXTRA=()
if [[ -n "${BUILD_NUMBER:-}" ]]; then EXTRA+=("CURRENT_PROJECT_VERSION=$BUILD_NUMBER"); fi

xcodebuild archive \
  -scheme Garantiebewaarder \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  ${EXTRA[@]+"${EXTRA[@]}"}

DESTINATION="upload"
[[ "$MODE" == "export" ]] && DESTINATION="export"

cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>destination</key><string>$DESTINATION</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
</dict></plist>
PLIST

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath build/export \
  -allowProvisioningUpdates

echo "Klaar (MODE=$MODE). In App Store Connect verschijnt de build na enkele minuten onder TestFlight/Build."
