#!/usr/bin/env bash
# =============================================================================
# build.sh – Kombiniertes Build-Script für macOS
#
# Erstellt die Jekyll-Website UND generiert PDFs aus den Markdown-Dokumenten.
# Die eigentliche PDF-Logik liegt in scripts/generate_pdfs.sh – dasselbe
# Script, das auch der GitHub Actions Workflow aufruft.
#
# Verwendung:
#   bash build.sh              # Interaktives Menü
#   bash build.sh pdf          # Nur PDFs generieren
#   bash build.sh web          # Nur Jekyll-Website bauen (einmalig, nach _site/)
#   bash build.sh serve        # Jekyll-Entwicklungsserver mit Live-Reload starten
#   bash build.sh test         # PDF-Tests ausführen
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

# -- PDF-Generierung (via gemeinsames Script) ------------------------------
generate_pdfs() {
    info "Generiere PDFs …"
    echo ""
    bash scripts/generate_pdfs.sh
    echo ""
    success "PDFs generiert in assets/pdf/"
}

# -- Tests -----------------------------------------------------------------
run_tests() {
    info "Starte Tests …"
    echo ""
    bash scripts/test_pdfs.sh
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
    bash build.sh              Interaktives Menü
    bash build.sh pdf          Nur PDFs generieren
    bash build.sh web          Nur Jekyll-Website bauen (nach _site/)
    bash build.sh serve        Jekyll-Entwicklungsserver starten (Live-Reload)
    bash build.sh test         PDF-Tests ausführen
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

  Die PDF-Logik liegt in scripts/generate_pdfs.sh und wird identisch
  vom GitHub Actions Workflow verwendet.

HELP
}

# -- Interaktives Menü -----------------------------------------------------
show_menu() {
    echo ""
    echo -e "  ${BLUE}╔══════════════════════════════════════╗${NC}"
    echo -e "  ${BLUE}║${NC}   md-to-web-and-pdf  Build-Tool      ${BLUE}║${NC}"
    echo -e "  ${BLUE}╚══════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC}  Alles bauen          (PDFs + Website)"
    echo -e "  ${GREEN}2)${NC}  Nur PDFs generieren"
    echo -e "  ${GREEN}3)${NC}  Nur Website bauen    (→ _site/)"
    echo -e "  ${GREEN}4)${NC}  Webserver starten    (Live-Reload)"
    echo -e "  ${GREEN}5)${NC}  Tests ausführen"
    echo -e "  ${GREEN}6)${NC}  Abhängigkeiten prüfen / installieren"
    echo -e "  ${GREEN}7)${NC}  Temporäre Dateien aufräumen"
    echo -e "  ${GREEN}q)${NC}  Beenden"
    echo ""
    printf "  Auswahl: "
    read -r choice
    echo ""
    case "$choice" in
        1) install_deps; echo ""; generate_pdfs; echo ""; build_web; echo ""; success "Alles fertig! PDFs in assets/pdf/, Website in _site/" ;;
        2) install_deps; echo ""; generate_pdfs ;;
        3) install_deps; echo ""; build_web ;;
        4) install_deps; echo ""; serve_web ;;
        5) run_tests ;;
        6) install_deps ;;
        7) clean ;;
        q|Q) echo "  Tschüss!"; exit 0 ;;
        *) error "Ungültige Auswahl: $choice"; show_menu ;;
    esac
}

# -- Hauptlogik ------------------------------------------------------------
main() {
    if [[ $# -eq 0 ]]; then
        show_menu
        return
    fi

    local cmd="$1"
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
        test)
            run_tests
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
