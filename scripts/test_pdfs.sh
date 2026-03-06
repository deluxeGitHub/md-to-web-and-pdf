#!/usr/bin/env bash
# =============================================================================
# scripts/test_pdfs.sh – Testframework für PDF-Generierung
#
# Prüft, ob alle Markdown-Dokumente ein gültiges PDF erzeugen.
# Läuft lokal (nach build.sh pdf) und in GitHub Actions (nach dem Build-Step).
#
# Exit-Code 0 = alle Tests bestanden
# Exit-Code 1 = mindestens ein Test fehlgeschlagen
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# -- Farben ---------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0
declare -a FAILURES=()

pass() { echo -e "  ${GREEN}PASS${NC}  $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}FAIL${NC}  $1"; FAIL=$((FAIL + 1)); FAILURES+=("$1"); }
skip() { echo -e "  ${YELLOW}SKIP${NC}  $1"; SKIP=$((SKIP + 1)); }

# -- Hilfsfunktionen ------------------------------------------------------

# Gibt die ersten Bytes einer Datei zurück (portabel)
pdf_magic() { head -c 4 "$1" 2>/dev/null || true; }

# Liefert die Dateigröße in Bytes
file_size() {
    if [[ "$(uname)" == "Darwin" ]]; then
        stat -f%z "$1" 2>/dev/null || echo 0
    else
        stat -c%s "$1" 2>/dev/null || echo 0
    fi
}

# -- Test-Suites ----------------------------------------------------------

test_suite_pdfs() {
    echo -e "\n${BOLD}Suite: PDF-Ausgabe${NC}"
    echo "  Prüfe alle docs/**/*.md → assets/pdf/<name>.pdf"
    echo ""

    local total=0

    while IFS= read -r -d '' file; do
        filename=$(basename -- "$file")
        name="${filename%.*}"
        pdf="assets/pdf/${name}.pdf"
        total=$((total + 1))

        # T1: PDF existiert
        if [[ ! -f "$pdf" ]]; then
            fail "PDF existiert nicht: ${name}.pdf  (Quelle: $file)"
            continue
        fi

        # T2: PDF hat validen Header (%PDF)
        magic=$(pdf_magic "$pdf")
        if [[ "$magic" != "%PDF" ]]; then
            fail "Kein gültiger PDF-Header: ${name}.pdf  (erwartet '%PDF', erhalten '${magic}')"
            continue
        fi

        # T3: PDF-Größe > 5 KB (sehr kleine PDFs deuten auf Fehler hin)
        size=$(file_size "$pdf")
        if [[ "$size" -lt 5120 ]]; then
            fail "PDF zu klein (${size} Bytes < 5120): ${name}.pdf"
            continue
        fi

        pass "${name}.pdf  (${size} Bytes)"

    done < <(find docs -name "*.md" -print0)

    echo ""
    echo "  ${total} Dokument(e) geprüft."
}

test_suite_templates() {
    echo -e "\n${BOLD}Suite: Template-Fallback${NC}"
    echo "  Prüft, dass kein Dokument das nicht-existente 'default'-Template verwendet."
    echo ""

    while IFS= read -r -d '' file; do
        filename=$(basename -- "$file")
        name="${filename%.*}"

        # Lese template: aus Front Matter
        template=$(python3 - "$file" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
lines = text.splitlines()
if not lines or lines[0].strip() != "---":
    print("(kein Front Matter)")
    sys.exit(0)
try:
    fm_end = lines.index("---", 1)
except ValueError:
    print("(kein Front Matter)")
    sys.exit(0)
for line in lines[1:fm_end]:
    if line.lower().startswith("template:"):
        value = line.split(":", 1)[1].strip().strip("'\"").lower()
        print(value)
        sys.exit(0)
print("(nicht gesetzt)")
PY
        )

        known=("base" "btfv" "dtfb" "(nicht gesetzt)" "(kein Front Matter)")
        found=false
        for k in "${known[@]}"; do
            [[ "$template" == "$k" ]] && found=true && break
        done

        if [[ "$found" == true ]]; then
            pass "${name}.md  → template: ${template}"
        else
            fail "${name}.md  → unbekanntes template: '${template}'"
        fi

    done < <(find docs -name "*.md" -print0)
}

test_suite_frontmatter() {
    echo -e "\n${BOLD}Suite: Front Matter Vollständigkeit${NC}"
    echo "  Prüft Pflichtfelder: title, layout."
    echo ""

    while IFS= read -r -d '' file; do
        filename=$(basename -- "$file")
        name="${filename%.*}"

        result=$(python3 - "$file" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
lines = text.splitlines()
if not lines or lines[0].strip() != "---":
    print("MISSING_FM")
    sys.exit(0)
try:
    fm_end = lines.index("---", 1)
except ValueError:
    print("MISSING_FM")
    sys.exit(0)
fm = {}
for line in lines[1:fm_end]:
    if ":" in line:
        k, _, v = line.partition(":")
        fm[k.strip().lower()] = v.strip()

missing = [f for f in ("title", "layout") if f not in fm]
if missing:
    print("MISSING:" + ",".join(missing))
else:
    print("OK")
PY
        )

        if [[ "$result" == "OK" ]]; then
            pass "${name}.md"
        elif [[ "$result" == "MISSING_FM" ]]; then
            skip "${name}.md  → kein Front Matter"
        else
            fail "${name}.md  → ${result}"
        fi

    done < <(find docs -name "*.md" -print0)
}

# -- Zusammenfassung ------------------------------------------------------

run_all() {
    echo -e "\n${BOLD}========================================${NC}"
    echo -e "${BOLD}  PDF Test Suite${NC}"
    echo -e "${BOLD}========================================${NC}"

    test_suite_pdfs
    test_suite_templates
    test_suite_frontmatter

    echo -e "\n${BOLD}========================================${NC}"
    echo -e "  Ergebnis: ${GREEN}${PASS} bestanden${NC}  |  ${RED}${FAIL} fehlgeschlagen${NC}  |  ${YELLOW}${SKIP} übersprungen${NC}"
    echo -e "${BOLD}========================================${NC}"

    if [[ ${#FAILURES[@]} -gt 0 ]]; then
        echo -e "\n${RED}Fehlgeschlagene Tests:${NC}"
        for f in "${FAILURES[@]}"; do
            echo -e "  ${RED}✖${NC}  $f"
        done
        echo ""
        exit 1
    fi

    echo -e "\n${GREEN}Alle Tests bestanden.${NC}\n"
}

run_all
