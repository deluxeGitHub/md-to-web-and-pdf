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

# -- Umgebungs-Suite ------------------------------------------------------

test_suite_environment() {
    echo -e "\n${BOLD}Suite: LaTeX-Umgebung${NC}"
    echo "  Prüft Fonts und LaTeX-Pakete, die für die PDF-Generierung nötig sind."
    echo ""

    # Benötigte System-Fonts (fontspec sucht via fontconfig)
    local fonts=("TeX Gyre Heros" "Latin Modern Sans")
    for font in "${fonts[@]}"; do
        local found
        found=$(fc-list 2>/dev/null | grep -i "$font" || true)
        if [[ -n "$found" ]]; then
            pass "Font: $font"
        else
            fail "Font nicht gefunden: $font  (fc-list kennt ihn nicht)"
        fi
    done

    # Benötigte LaTeX-Pakete (.sty via kpsewhich)
    local packages=(titlesec soul enumitem fancyhdr lastpage geometry hyperref fontspec)
    for pkg in "${packages[@]}"; do
        if kpsewhich "${pkg}.sty" &>/dev/null; then
            pass "LaTeX-Paket: ${pkg}.sty"
        else
            fail "LaTeX-Paket fehlt: ${pkg}.sty"
        fi
    done

    # Benötigte Tools
    local tools=(pandoc xelatex python3)
    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            pass "Tool: $tool  ($($tool --version 2>&1 | head -1))"
        else
            fail "Tool fehlt: $tool"
        fi
    done
}

# -- Fixture-Suite (LaTeX-Vergleich) ---------------------------------------

test_suite_fixtures() {
    echo -e "\n${BOLD}Suite: LaTeX-Fixtures (Regression)${NC}"
    echo "  Vergleicht frisch generiertes .tex gegen committete Referenz-Fixtures."
    echo ""

    local fixture_dir="test/fixtures/tex"
    local run_dir="temp/test-tex"
    mkdir -p "$run_dir"

    # Frische .tex-Dateien mit fixem Datum generieren (identisch zur Fixture-Erstellung)
    if ! bash scripts/generate_pdfs.sh "01.01.2000" test "$run_dir" tex &>/dev/null; then
        fail "LaTeX-Generierung für test/*.md fehlgeschlagen"
        rm -rf "$run_dir"
        return
    fi

    while IFS= read -r -d '' md; do
        local filename name tex fixture
        filename=$(basename -- "$md")
        name="${filename%.*}"
        tex="$run_dir/${name}.tex"
        fixture="${fixture_dir}/${name}.tex"

        if [[ ! -f "$tex" ]]; then
            fail "${name}: keine .tex-Datei erzeugt"
            continue
        fi

        if [[ ! -f "$fixture" ]]; then
            skip "${name}.tex  → kein Fixture (bash build.sh fixtures ausführen)"
            continue
        fi

        if diff -q "$fixture" "$tex" &>/dev/null; then
            pass "${name}.tex  → identisch mit Fixture"
        else
            fail "${name}.tex  → Abweichung vom Fixture"
            diff "$fixture" "$tex" | head -20 | sed 's/^/    /' >&2
        fi

    done < <(find test -maxdepth 1 -name "*.md" -print0)

    rm -rf "$run_dir"
}

# -- Section-Numbering-Suite -----------------------------------------------

test_suite_section_numbering() {
    echo -e "\n${BOLD}Suite: Abschnittsnummerierung${NC}"
    echo "  Prüft, dass section_prefix:\"§\" → §-Zeichen und numbered_sections → 1/1.1 erzeugt."
    echo ""

    local has_pdftotext=false
    command -v pdftotext &>/dev/null && has_pdftotext=true

    if [[ "$has_pdftotext" == false ]]; then
        skip "pdftotext nicht verfügbar (brew install poppler) – Suite übersprungen"
        return
    fi

    local run_dir="temp/test-numbering"
    mkdir -p "$run_dir"

    bash scripts/generate_pdfs.sh "$(date +%d.%m.%Y)" test "$run_dir" &>/dev/null

    while IFS= read -r -d '' md; do
        filename=$(basename -- "$md")
        name="${filename%.*}"
        pdf="$run_dir/${name}.pdf"

        [[ ! -f "$pdf" ]] && fail "${name}: PDF nicht generiert" && continue

        local text
        text=$(pdftotext "$pdf" - 2>/dev/null)

        # § als Abschnittsnummer steht am Zeilenanfang direkt vor einer Ziffer: "§1", "§2"
        local has_section_symbol
        has_section_symbol=$(echo "$text" | grep -cE '^§[0-9]' || true)

        local sn
        sn=$(python3 -c "
import sys
from pathlib import Path
text = Path('${md}').read_text(encoding='utf-8')
lines = text.splitlines()
if not lines or lines[0].strip() != '---': sys.exit()
try: end = lines.index('---', 1)
except ValueError: sys.exit()
for l in lines[1:end]:
    if l.lower().startswith('section_numbering:'):
        print(l.split(':',1)[1].strip().strip(chr(39)+chr(34)).lower())
        break
" 2>/dev/null || true)

        case "$sn" in
            paragraph)
                if [[ "$has_section_symbol" -gt 0 ]]; then
                    pass "${name}: §-Nummerierung vorhanden (${has_section_symbol} Abschnitte)"
                else
                    fail "${name}: section_numbering:paragraph gesetzt, aber kein §N im PDF"
                fi
                ;;
            arabic)
                local has_arabic
                has_arabic=$(echo "$text" | grep -cE '^[0-9]+(\.[0-9]+)? ' || true)
                if [[ "$has_arabic" -gt 0 && "$has_section_symbol" -eq 0 ]]; then
                    pass "${name}: arabische Nummerierung vorhanden, kein §"
                elif [[ "$has_section_symbol" -gt 0 ]]; then
                    fail "${name}: section_numbering:arabic gesetzt, aber §N im PDF gefunden"
                else
                    fail "${name}: section_numbering:arabic gesetzt, aber keine Nummerierung im PDF"
                fi
                ;;
            *)
                if [[ "$has_section_symbol" -gt 0 ]]; then
                    fail "${name}: section_numbering nicht gesetzt, aber §N im PDF gefunden"
                else
                    pass "${name}: keine Abschnittsnummerierung (korrekt)"
                fi
                ;;
        esac

    done < <(find test -maxdepth 1 -name "*.md" -print0)

    rm -rf "$run_dir"
}

# -- HTML-Suite -----------------------------------------------------------

test_suite_html() {
    echo -e "\n${BOLD}Suite: HTML-Ausgabe (_site/)${NC}"
    echo "  Prüft generierte HTML-Seiten auf Existenz, Titel und Struktur."
    echo ""

    if [[ ! -d "_site" ]]; then
        skip "HTML  → _site/ nicht vorhanden (bash build.sh web ausführen)"
        return
    fi

    while IFS= read -r -d '' md; do
        filename=$(basename -- "$md")
        name="${filename%.*}"

        # Jekyll spiegelt die Quellstruktur: docs/subdir/file.md → _site/docs/subdir/file.html
        # Wir suchen rekursiv in _site/ nach dem passenden Dateinamen.
        local html_file
        html_file=$(find "_site" -name "${name}.html" -o -path "*/${name}/index.html" 2>/dev/null | head -1)

        if [[ -z "$html_file" ]]; then
            fail "${name}.md  → keine HTML-Ausgabe in _site/ gefunden"
            continue
        fi

        # T1: title-Tag vorhanden
        if grep -q "<title>" "$html_file" 2>/dev/null; then
            pass "${name}.html  → title-Tag vorhanden  ($html_file)"
        else
            fail "${name}.html  → kein title-Tag  ($html_file)"
        fi

        # T2: CSS-Link vorhanden
        if grep -q "\.css" "$html_file" 2>/dev/null; then
            pass "${name}.html  → CSS-Link vorhanden"
        else
            fail "${name}.html  → kein CSS-Link"
        fi

        # T3: Mindestens eine Überschrift
        if grep -q "<h[1-3]" "$html_file" 2>/dev/null; then
            pass "${name}.html  → Überschriften vorhanden"
        else
            fail "${name}.html  → keine Überschriften gefunden"
        fi

        # T4: section_numbering → korrekte body-Klasse
        # section_numbering:paragraph → body muss "section-prefix" enthalten
        # section_numbering:arabic    → body darf "section-prefix" NICHT enthalten
        local sn_html
        sn_html=$(python3 -c "
import sys
from pathlib import Path
text = Path('${md}').read_text(encoding='utf-8')
lines = text.splitlines()
if not lines or lines[0].strip() != '---': sys.exit()
try: end = lines.index('---', 1)
except ValueError: sys.exit()
for l in lines[1:end]:
    if l.lower().startswith('section_numbering:'):
        print(l.split(':',1)[1].strip().strip(chr(39)+chr(34)).lower())
        break
" 2>/dev/null || true)
        local body_class
        body_class=$(grep -o '<body[^>]*>' "$html_file" 2>/dev/null | head -1)
        case "$sn_html" in
            paragraph)
                if echo "$body_class" | grep -q "section-prefix"; then
                    pass "${name}.html  → body hat Klasse 'section-prefix' (paragraph)"
                else
                    fail "${name}.html  → section_numbering:paragraph, aber body fehlt Klasse 'section-prefix'"
                fi
                ;;
            arabic)
                if echo "$body_class" | grep -q "section-prefix"; then
                    fail "${name}.html  → section_numbering:arabic, aber body hat Klasse 'section-prefix'"
                else
                    pass "${name}.html  → body hat kein 'section-prefix' (arabic, korrekt)"
                fi
                ;;
        esac

    done < <(find docs -name "*.md" -print0)
}

# -- Zusammenfassung ------------------------------------------------------

run_all() {
    echo -e "\n${BOLD}========================================${NC}"
    echo -e "${BOLD}  PDF Test Suite${NC}"
    echo -e "${BOLD}========================================${NC}"

    test_suite_environment
    test_suite_pdfs
    test_suite_templates
    test_suite_frontmatter
    test_suite_fixtures
    test_suite_section_numbering
    test_suite_html

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
