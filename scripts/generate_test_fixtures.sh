#!/usr/bin/env bash
# =============================================================================
# scripts/generate_test_fixtures.sh – Goldene Referenz-Fixtures erzeugen
#
# Generiert aus test/*.md:
#   - test/fixtures/tex/*.tex  → versioniert, für Regressionsvergleich
#   - test/fixtures/tex/*.pdf  → gitignored, zur manuellen Inspektion
#   - test/fixtures/html/*.html → versioniert, normalisiert (ohne Datum)
#
# Festes Datum (01.01.2000) für stabile, reproduzierbare Diffs.
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

FIXTURE_DATE="01.01.2000"
TEX_DIR="test/fixtures/tex"
HTML_DIR="test/fixtures/html"
mkdir -p "$TEX_DIR" "$HTML_DIR"

# -- 1. LaTeX-Fixtures --------------------------------------------------------
info "Generiere LaTeX-Fixtures (Datum: ${FIXTURE_DATE}) …"
echo ""
bash scripts/generate_pdfs.sh "$FIXTURE_DATE" test "$TEX_DIR" tex
echo ""

# -- 2. PDF neben .tex (gitignored, für manuelle Inspektion) ------------------
info "Generiere PDFs zur Inspektion …"
echo ""
bash scripts/generate_pdfs.sh "$FIXTURE_DATE" test "$TEX_DIR" pdf
echo ""

# -- 3. HTML-Fixtures via Jekyll ----------------------------------------------
info "Generiere HTML-Fixtures via Jekyll …"
echo ""

# Ruby/Jekyll PATH aufbauen (macOS Homebrew)
if command -v brew &>/dev/null; then
    RUBY_PREFIX="$(brew --prefix ruby 2>/dev/null || true)"
    [[ -n "$RUBY_PREFIX" && -d "$RUBY_PREFIX/bin" ]] && export PATH="$RUBY_PREFIX/bin:$PATH"
fi
GEM_USER_DIR="$(ruby -e 'print Gem.user_dir' 2>/dev/null || true)"
[[ -n "$GEM_USER_DIR" ]] && export PATH="$GEM_USER_DIR/bin:$PATH"

if ! command -v jekyll &>/dev/null; then
    warn "jekyll nicht gefunden – HTML-Fixtures werden übersprungen."
else
    # In ein temporaeres Verzeichnis bauen, nicht nach _site: ein Fixture-Lauf
    # darf die lokale Vorschau nicht ueberschreiben.
    BUILD_DIR="temp/fixtures-html"
    rm -rf "$BUILD_DIR"

    # test/ steht in _config.yml unter exclude; ohne die Ueberschreibung entsteht
    # kein test/-Verzeichnis in der Ausgabe und es gaebe nichts zu sichern.
    JEKYLL_CFG="_config.yml,test/_config.test.yml"
    jekyll build --config "$JEKYLL_CFG" --destination "$BUILD_DIR" --source . --baseurl "" --quiet 2>/dev/null ||
        jekyll build --config "$JEKYLL_CFG" --destination "$BUILD_DIR" --source . --baseurl ""

    while IFS= read -r -d '' md; do
        name="$(basename "${md%.md}")"
        src="${BUILD_DIR}/test/${name}.html"
        dst="${HTML_DIR}/${name}.html"

        if [[ ! -f "$src" ]]; then
            warn "HTML nicht gefunden: $src"
            continue
        fi

        # Dieselbe Normalisierung wie im Vergleich (scripts/test_pdfs.sh) -
        # eine gemeinsame Quelle, kein zweiter Satz sed-Aufrufe.
        bash scripts/normalize_html.sh "$src" > "$dst"
        success "HTML: ${name}.html"
    done < <(find test -maxdepth 1 -name "*.md" -print0)

    rm -rf "$BUILD_DIR"
fi

echo ""
success "Fixtures gespeichert:"
echo "    tex/  $(ls "$TEX_DIR"/*.tex 2>/dev/null | wc -l | tr -d ' ') .tex-Dateien (versioniert)"
echo "    tex/  $(ls "$TEX_DIR"/*.pdf 2>/dev/null | wc -l | tr -d ' ') .pdf-Dateien (gitignored)"
echo "    html/ $(ls "$HTML_DIR"/*.html 2>/dev/null | wc -l | tr -d ' ') .html-Dateien (versioniert)"
echo ""
echo "  Bitte Fixtures prüfen und committen:"
echo "    git add test/fixtures/"
echo "    git commit -m \"Update test fixtures\""
echo ""
