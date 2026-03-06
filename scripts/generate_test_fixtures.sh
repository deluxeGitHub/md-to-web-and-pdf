#!/usr/bin/env bash
# =============================================================================
# scripts/generate_test_fixtures.sh – Goldene Referenz-LaTeX-Dateien erzeugen
#
# Generiert .tex-Dateien aus test/*.md und speichert sie als versionierte
# Fixtures in test/fixtures/tex/. Der Test-Suite kann dann frisch generierte
# .tex-Dateien zeichengenau dagegen vergleichen, um Regressionen zu erkennen.
#
# Ein festes Datum (01.01.2000) wird verwendet, damit der Vergleich stabil
# bleibt und nicht beim nächsten Tag fehlschlägt.
#
# Verwendung:
#   bash scripts/generate_test_fixtures.sh
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}ℹ${NC}  $*"; }
success() { echo -e "${GREEN}✔${NC}  $*"; }

FIXTURE_DATE="01.01.2000"
FIXTURE_DIR="test/fixtures/tex"
mkdir -p "$FIXTURE_DIR"

info "Generiere LaTeX-Fixtures aus test/*.md (Datum: ${FIXTURE_DATE}) …"
echo ""

bash scripts/generate_pdfs.sh "$FIXTURE_DATE" test "$FIXTURE_DIR" tex

echo ""
success "Fixtures gespeichert in ${FIXTURE_DIR}/"
echo ""
echo "  Dateien:"
ls -lh "$FIXTURE_DIR" | tail -n +2 | awk '{print "    " $0}'
echo ""
echo "  Bitte die Fixtures prüfen und committen:"
echo "    git add test/fixtures/tex/"
echo "    git commit -m \"Update LaTeX test fixtures\""
echo ""
