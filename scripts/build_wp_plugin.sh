#!/usr/bin/env bash
# =============================================================================
# scripts/build_wp_plugin.sh – WordPress-Plugin als ZIP packen (SPEC-007)
#
# Erzeugt temp/md-docs-embed-<version>.zip aus wordpress/md-docs-embed/.
# Die Version wird aus dem Plugin-Header gelesen.
#
# Verwendung:
#   bash scripts/build_wp_plugin.sh
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${BLUE}ℹ${NC}  $*"; }
success() { echo -e "${GREEN}✔${NC}  $*"; }
error()   { echo -e "${RED}✘${NC}  $*" >&2; }

PLUGIN_DIR="wordpress/md-docs-embed"
PLUGIN_SLUG="md-docs-embed"
MAIN_FILE="${PLUGIN_DIR}/${PLUGIN_SLUG}.php"

[[ -f "$MAIN_FILE" ]] || { error "Plugin nicht gefunden: $MAIN_FILE"; exit 1; }

VERSION="$(grep -m1 '^ \* Version:' "$MAIN_FILE" | sed -E 's/.*Version:[[:space:]]*//')"
[[ -n "$VERSION" ]] || { error "Version im Plugin-Header nicht gefunden."; exit 1; }

command -v zip >/dev/null 2>&1 || { error "'zip' ist nicht installiert."; exit 1; }

# PHP-Syntaxpruefung, falls PHP vorhanden ist.
if command -v php >/dev/null 2>&1; then
    info "PHP-Syntaxprüfung …"
    while IFS= read -r -d '' file; do
        php -l "$file" >/dev/null || { error "Syntaxfehler in $file"; exit 1; }
    done < <(find "$PLUGIN_DIR" -name '*.php' -print0)
    success "PHP-Dateien fehlerfrei"
else
    info "PHP nicht gefunden – Syntaxprüfung übersprungen."
fi

mkdir -p temp
STAGE="temp/_wp_plugin_build"
TARGET="temp/${PLUGIN_SLUG}-${VERSION}.zip"

rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -r "$PLUGIN_DIR" "$STAGE/$PLUGIN_SLUG"

# Nichts einpacken, was nur zur Entwicklung gehoert.
find "$STAGE" \( -name '.DS_Store' -o -name '*.map' -o -name 'node_modules' \) -exec rm -rf {} + 2>/dev/null || true

rm -f "$TARGET"
( cd "$STAGE" && zip -rq "../$(basename "$TARGET")" "$PLUGIN_SLUG" )
rm -rf "$STAGE"

success "Plugin gepackt: ${TARGET}  ($(du -h "$TARGET" | cut -f1))"
echo ""
echo "  Installation: WordPress → Plugins → Installieren → Plugin hochladen"
echo ""
