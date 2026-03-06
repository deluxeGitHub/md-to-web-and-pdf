#!/usr/bin/env bash
# =============================================================================
# scripts/generate_test_fixtures.sh – Goldene Referenz-PDFs erzeugen
#
# Dieses Script generiert PDFs aus den test/*.md Dateien und speichert sie
# als Fixture-Referenz in test/fixtures/pdf/.
# Zusätzlich wird die Seitenzahl jeder PDF als *.pages-Datei gespeichert,
# damit test_pdfs.sh einen Regressionstest durchführen kann.
#
# Verwendung:
#   bash scripts/generate_test_fixtures.sh
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${BLUE}ℹ${NC}  $*"; }
success() { echo -e "${GREEN}✔${NC}  $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*"; }

FIXTURE_DIR="test/fixtures/pdf"
mkdir -p "$FIXTURE_DIR"

info "Generiere Test-Fixtures aus test/*.md …"
echo ""

# PDFs generieren (gleiche Pipeline wie Produktion)
bash scripts/generate_pdfs.sh "$(date +%d.%m.%Y)" test "$FIXTURE_DIR"

echo ""
info "Speichere Seitenzahlen als Referenz …"
echo ""

# Seitenzahl pro PDF ermitteln und als .pages-Datei speichern
has_pdfinfo=false
command -v pdfinfo &>/dev/null && has_pdfinfo=true

if [[ "$has_pdfinfo" == false ]]; then
    warn "pdfinfo nicht gefunden – Seitenzahl-Fixtures werden übersprungen."
    warn "Installiere poppler: brew install poppler"
    echo ""
else
    while IFS= read -r -d '' pdf; do
        name="$(basename "${pdf%.pdf}")"
        pages=$(pdfinfo "$pdf" 2>/dev/null | awk '/^Pages:/{print $2}')
        if [[ -n "$pages" ]]; then
            echo "$pages" > "${FIXTURE_DIR}/${name}.pages"
            success "${name}.pdf  →  ${pages} Seite(n)"
        fi
    done < <(find "$FIXTURE_DIR" -name "*.pdf" -print0)
fi

echo ""
success "Fixtures gespeichert in ${FIXTURE_DIR}/"
echo ""
echo "  Dateien:"
ls -lh "$FIXTURE_DIR" | tail -n +2 | awk '{print "    " $0}'
echo ""
