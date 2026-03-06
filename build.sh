#!/usr/bin/env bash
# =============================================================================
# build.sh – Kombiniertes Build-Script für macOS
#
# Erstellt die Jekyll-Website UND generiert PDFs aus den Markdown-Dokumenten.
#
# Verwendung:
#   bash build.sh              # Website bauen + PDFs generieren
#   bash build.sh pdf          # Nur PDFs generieren
#   bash build.sh web          # Nur Jekyll-Website bauen (einmalig, nach _site/)
#   bash build.sh serve        # Jekyll-Entwicklungsserver mit Live-Reload starten
#   bash build.sh install      # Nur Abhängigkeiten prüfen/installieren
#   bash build.sh clean        # Temporäre Dateien aufräumen
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

# -- Farben für Terminal-Ausgabe -------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}ℹ${NC}  $*"; }
success() { echo -e "${GREEN}✔${NC}  $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*"; }
error()   { echo -e "${RED}✖${NC}  $*" >&2; }

# -- Abhängigkeiten prüfen / installieren ----------------------------------
check_homebrew() {
    if ! command -v brew &>/dev/null; then
        warn "Homebrew nicht gefunden. Installiere Homebrew …"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Homebrew-Pfade für Apple Silicon und Intel
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        success "Homebrew installiert."
    fi
}

check_pandoc() {
    if ! command -v pandoc &>/dev/null; then
        info "Installiere pandoc …"
        brew install pandoc
        success "pandoc installiert."
    else
        success "pandoc gefunden: $(pandoc --version | head -1)"
    fi
}

check_latex() {
    if ! command -v xelatex &>/dev/null; then
        warn "XeLaTeX nicht gefunden."
        echo ""
        echo "  Für die PDF-Generierung wird eine TeX-Distribution benötigt."
        echo "  Empfehlung: MacTeX (vollständig) oder BasicTeX (minimal)."
        echo ""
        echo "  Option 1 – BasicTeX via Homebrew (ca. 100 MB):"
        echo "    brew install --cask basictex"
        echo "    Danach Terminal neu starten und ausführen:"
        echo "    sudo tlmgr update --self && sudo tlmgr install collection-fontsrecommended enumitem"
        echo ""
        echo "  Option 2 – MacTeX (vollständig, ca. 4 GB):"
        echo "    brew install --cask mactex"
        echo ""

        read -rp "Soll BasicTeX jetzt automatisch installiert werden? [j/N] " answer
        if [[ "$answer" =~ ^[jJyY]$ ]]; then
            brew install --cask basictex
            # TeX-Pfad für aktuelle Session setzen
            export PATH="/Library/TeX/texbin:$PATH"
            info "Aktualisiere TeX-Pakete …"
            sudo tlmgr update --self
            sudo tlmgr install collection-fontsrecommended enumitem xetex \
                collection-langgerman lm etoolbox geometry fancyhdr \
                lastpage titling tocloft parskip
            success "BasicTeX + benötigte Pakete installiert."
        else
            error "Bitte installiere eine TeX-Distribution manuell und starte das Script erneut."
            return 1
        fi
    else
        success "XeLaTeX gefunden: $(xelatex --version | head -1)"
    fi
}

setup_ruby_path() {
    # Homebrew-Ruby bevorzugen (macOS System-Ruby ist zu alt für Jekyll 4+)
    if command -v brew &>/dev/null; then
        RUBY_PREFIX="$(brew --prefix ruby 2>/dev/null || true)"
        if [[ -n "$RUBY_PREFIX" && -d "$RUBY_PREFIX/bin" ]]; then
            export PATH="$RUBY_PREFIX/bin:$PATH"
        fi
    fi

    GEM_USER_DIR="$(ruby -e 'print Gem.user_dir' 2>/dev/null || true)"
    if [[ -n "$GEM_USER_DIR" ]]; then
        export PATH="$GEM_USER_DIR/bin:$PATH"
    fi
}

check_ruby_and_jekyll() {
    # macOS liefert Ruby 2.6 mit – das ist zu alt für aktuelle Jekyll-Versionen.
    # Wir brauchen mindestens Ruby 3.1+.
    local need_install=false

    if ! command -v ruby &>/dev/null; then
        need_install=true
    else
        local ruby_major ruby_minor
        ruby_major=$(ruby -e 'print RUBY_VERSION.split(".")[0]')
        ruby_minor=$(ruby -e 'print RUBY_VERSION.split(".")[1]')
        if [[ "$ruby_major" -lt 3 ]] || { [[ "$ruby_major" -eq 3 ]] && [[ "$ruby_minor" -lt 1 ]]; }; then
            warn "Ruby $(ruby --version) ist zu alt (mind. 3.1 nötig)."
            need_install=true
        fi
    fi

    if [[ "$need_install" == true ]]; then
        info "Installiere aktuelle Ruby-Version via Homebrew …"
        brew install ruby
        # Homebrew-Ruby in den PATH einbinden (Apple Silicon + Intel)
        RUBY_PREFIX="$(brew --prefix ruby)"
        export PATH="$RUBY_PREFIX/bin:$PATH"
        success "Ruby installiert: $(ruby --version)"
        echo ""
        warn "Damit ruby dauerhaft gefunden wird, füge folgende Zeile"
        warn "in deine ~/.zshrc (oder ~/.bash_profile) ein:"
        echo ""
        echo "  export PATH=\"$RUBY_PREFIX/bin:\$PATH\""
        echo ""
    else
        success "Ruby gefunden: $(ruby --version)"
    fi

    setup_ruby_path

    # Jekyll installieren falls nötig
    if ! command -v jekyll &>/dev/null; then
        info "Installiere Jekyll + Bundler …"
        gem install --user-install jekyll bundler
        # PATH nach gem install aktualisieren
        setup_ruby_path
        success "Jekyll installiert."
    else
        success "Jekyll gefunden: $(jekyll --version)"
    fi

    # Benötigte Gems installieren
    local gems=("jekyll-toc" "jekyll-theme-minimal" "jekyll-relative-links")
    for g in "${gems[@]}"; do
        if ! gem list -i "$g" &>/dev/null; then
            info "Installiere Gem: $g …"
            gem install --user-install "$g"
        fi
    done
    success "Alle Jekyll-Gems vorhanden."
}

check_python() {
    if ! command -v python3 &>/dev/null; then
        info "Installiere Python 3 …"
        brew install python@3
        success "Python 3 installiert."
    else
        success "Python 3 gefunden: $(python3 --version)"
    fi
}

install_deps() {
    info "Prüfe Abhängigkeiten …"
    echo ""
    check_homebrew
    check_python
    check_pandoc
    check_latex
    check_ruby_and_jekyll
    echo ""
    success "Alle Abhängigkeiten sind vorhanden."
}

# -- PDF-Generierung -------------------------------------------------------
generate_pdfs() {
    info "Generiere PDFs …"
    mkdir -p assets/pdf
    mkdir -p temp

    # macOS-kompatibles sed
    SED_I=(sed -i '')

    CURRENT_DATE=$(date +%Y-%m-%d)
    CURRENT_DATE_DE=$(date +%d.%m.%Y)

    local count=0

    while IFS= read -r -d '' file; do
        filename=$(basename -- "$file")
        name="${filename%.*}"
        cp "$file" "temp/${name}_temp.md"
        header_file="temp/${name}_header.tex"
        number_sections="--number-sections"
        template_name=""
        template_dir=""

        info "  Verarbeite: $filename"

        # Template-Name aus Front Matter lesen
        template_name=$(python3 - "$file" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
lines = text.splitlines()
if not lines or lines[0].strip() != "---":
    sys.exit(0)
try:
    fm_end = lines.index("---", 1)
except ValueError:
    sys.exit(0)
for line in lines[1:fm_end]:
    if line.lower().startswith("template:"):
        value = line.split(":", 1)[1].strip().strip("'\"")
        print(value.lower())
        break
PY
        )

        if [[ -z "$template_name" ]]; then
            template_name="default"
        fi

        if [[ -d "templates/$template_name" ]]; then
            template_dir="templates/$template_name"
        else
            template_name="default"
        fi

        # LaTeX-Header erstellen
        if grep -q '^section_prefix:' "$file"; then
            cat > "$header_file" <<'EOF'
\usepackage{enumitem}
\renewcommand{\thesection}{\S\arabic{section}}
\renewcommand{\thesubsection}{\arabic{section}.\arabic{subsection}}
\renewcommand{\thesubsubsection}{\arabic{section}.\arabic{subsection}.\arabic{subsubsection}}
\makeatletter
\renewcommand{\@seccntformat}[1]{\ifcsname the#1\endcsname\csname the#1\endcsname\hspace{0.4em}\fi}
\renewcommand{\numberline}[1]{#1\hspace{0.6em}}
\makeatother
EOF
        else
            echo "\\usepackage{enumitem}" > "$header_file"
        fi

        if [[ -n "$template_dir" ]] && [[ -f "$template_dir/pdf-header.tex" ]]; then
            cat "$template_dir/pdf-header.tex" >> "$header_file"
        fi

        # Datum-Platzhalter ersetzen
        "${SED_I[@]}" "s/{{ site.time | date: \"%d-%m-%Y\" }}/$CURRENT_DATE_DE/g" "temp/${name}_temp.md"
        "${SED_I[@]}" "s/{{ site.time | date: '%d-%m-%Y' }}/$CURRENT_DATE_DE/g" "temp/${name}_temp.md"
        "${SED_I[@]}" "s/{{ site.time | date: \"%d.%m.%Y\" }}/$CURRENT_DATE_DE/g" "temp/${name}_temp.md"
        "${SED_I[@]}" "s/{{ site.time | date: '%d.%m.%Y' }}/$CURRENT_DATE_DE/g" "temp/${name}_temp.md"
        "${SED_I[@]}" "s/date: {{ site.time | date: \"%d-%m-%Y\" }}/date: $CURRENT_DATE_DE/g" "temp/${name}_temp.md"
        "${SED_I[@]}" "s/date: {{ site.time | date: '%d-%m-%Y' }}/date: $CURRENT_DATE_DE/g" "temp/${name}_temp.md"
        "${SED_I[@]}" "s/date: {{ site.time | date: \"%d.%m.%Y\" }}/date: $CURRENT_DATE_DE/g" "temp/${name}_temp.md"
        "${SED_I[@]}" "s/date: {{ site.time | date: '%d.%m.%Y' }}/date: $CURRENT_DATE_DE/g" "temp/${name}_temp.md"
        "${SED_I[@]}" "s/^date: .*/date: $CURRENT_DATE_DE/" "temp/${name}_temp.md"

        # title2 → subtitle (wie im GitHub Workflow)
        "${SED_I[@]}" "s/^title2:/subtitle:/" "temp/${name}_temp.md"

        # TOC-Syntax für LaTeX ersetzen
        awk '
          { sub(/\r$/, ""); }
          $0 == "* TOC" || $0 == "TOC {:toc}" || $0 == "* TOC {:toc}" {
            print "\\clearpage\\renewcommand{\\contentsname}{Inhaltsverzeichnis}";
            print "\\tableofcontents";
            print "\\clearpage";
            skip = 1;
            next;
          }
          skip && $0 == "{:toc}" { skip = 0; next; }
          { print; }
        ' "temp/${name}_temp.md" > "temp/${name}_temp.md.tmp" && mv "temp/${name}_temp.md.tmp" "temp/${name}_temp.md"

        # HTML-only-Blöcke entfernen
        "${SED_I[@]}" '/<div class="html-only"/,/^<\/div>$/d' "temp/${name}_temp.md"

        # Alphabetische HTML-Listen → LaTeX
        "${SED_I[@]}" '
        s|<ol type="a">|\\begin{enumerate}[label=\\alph*.]|g;
        s|</ol>|\\end{enumerate}|g;
        s|<li>|\\item |g;
        s|</li>||g;
        ' "temp/${name}_temp.md"

        # Markdown → PDF konvertieren
        if pandoc "temp/${name}_temp.md" -o "assets/pdf/${name}.pdf" \
            $number_sections \
            --toc-depth=2 \
            --pdf-engine=xelatex \
            -V geometry:margin=1in \
            --include-in-header="$header_file" \
            --resource-path=".:./docs:./templates:./templates/$template_name"; then
            success "  → assets/pdf/${name}.pdf"
        else
            error "  → Fehler bei ${name}.pdf"
        fi

        count=$((count + 1))
    done < <(find docs -name "*.md" -print0)

    echo ""
    success "$count PDF(s) generiert in assets/pdf/"
}

# -- Jekyll-Website --------------------------------------------------------
build_web() {
    info "Baue Jekyll-Website …"
    setup_ruby_path
    jekyll build --destination "_site" --source .
    success "Website gebaut nach _site/"
}

serve_web() {
    info "Starte Jekyll-Entwicklungsserver …"
    echo "  Öffne http://localhost:4000/ im Browser"
    echo "  Beenden mit Ctrl+C"
    echo ""
    setup_ruby_path
    jekyll serve --livereload --baseurl "" --destination ".jekyll/_site" --source .
}

# -- Aufräumen -------------------------------------------------------------
clean() {
    info "Räume temporäre Dateien auf …"
    rm -rf temp/
    rm -rf .jekyll/
    rm -rf _site/
    success "Aufgeräumt."
}

# -- Hilfe -----------------------------------------------------------------
show_help() {
    cat <<'HELP'

  build.sh – Website & PDF Build-Tool für macOS

  Verwendung:
    bash build.sh              Alles bauen (PDFs + Website)
    bash build.sh pdf          Nur PDFs generieren
    bash build.sh web          Nur Jekyll-Website bauen (nach _site/)
    bash build.sh serve        Jekyll-Entwicklungsserver starten (Live-Reload)
    bash build.sh install      Nur Abhängigkeiten prüfen/installieren
    bash build.sh clean        Temporäre Dateien aufräumen
    bash build.sh help         Diese Hilfe anzeigen

  Voraussetzungen (werden bei Bedarf automatisch installiert):
    • Homebrew          (Paketmanager)
    • Python 3          (Front-Matter-Parsing)
    • Pandoc            (Markdown-Konvertierung)
    • XeLaTeX           (PDF-Rendering – via BasicTeX oder MacTeX)
    • Ruby + Jekyll     (Website-Generierung)
    • Jekyll-Gems       (jekyll-toc, jekyll-theme-minimal, jekyll-relative-links)

HELP
}

# -- Hauptlogik ------------------------------------------------------------
main() {
    local cmd="${1:-all}"

    case "$cmd" in
        pdf)
            install_deps
            echo ""
            generate_pdfs
            ;;
        web)
            install_deps
            echo ""
            build_web
            ;;
        serve)
            install_deps
            echo ""
            serve_web
            ;;
        install)
            install_deps
            ;;
        clean)
            clean
            ;;
        help|--help|-h)
            show_help
            ;;
        all)
            install_deps
            echo ""
            generate_pdfs
            echo ""
            build_web
            echo ""
            success "Alles fertig! PDFs in assets/pdf/, Website in _site/"
            ;;
        *)
            error "Unbekannter Befehl: $cmd"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
