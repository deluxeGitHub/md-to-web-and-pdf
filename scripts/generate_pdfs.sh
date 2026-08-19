#!/usr/bin/env bash
# =============================================================================
# scripts/generate_pdfs.sh – Kanonische PDF-Generierung
#
# Dieses Script ist die einzige Quelle der Wahrheit für PDF-Builds.
# Sowohl build.sh (lokal) als auch der GitHub Actions Workflow rufen es auf.
#
# Verwendung:
#   bash scripts/generate_pdfs.sh [DATUM_DE] [SOURCE_DIR] [OUTPUT_DIR] [FORMAT]
#
#   DATUM_DE    Optionales Datum im Format DD.MM.YYYY. Standard: heute.
#   SOURCE_DIR  Quell-Verzeichnis mit *.md-Dateien.  Standard: docs
#   OUTPUT_DIR  Ausgabe-Verzeichnis für PDFs.         Standard: assets/pdf
#   FORMAT      Ausgabeformat: pdf (Standard) oder tex
# =============================================================================
set -euo pipefail

# Immer relativ zum Repo-Root ausführen
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# -- Argumente ----------------------------------------------------------------
CURRENT_DATE_DE="${1:-$(date +%d.%m.%Y)}"
SOURCE_DIR="${2:-docs}"
OUTPUT_DIR="${3:-assets/pdf}"
FORMAT="${4:-pdf}"

# -- Defaults aus _config.yml lesen -------------------------------------------
# Liest defaults[].values.<key>, damit HTML und PDF dieselbe Quelle nutzen.
config_default() {
    python3 - "$1" <<'PY'
import sys
key = sys.argv[1]
try:
    import yaml
    cfg = yaml.safe_load(open("_config.yml", encoding="utf-8"))
    for d in cfg.get("defaults", []):
        val = d.get("values", {}).get(key, "")
        if val:
            print(str(val).strip().lower())
            sys.exit(0)
except Exception:
    in_defaults = in_values = False
    for line in open("_config.yml", encoding="utf-8"):
        s = line.rstrip()
        if s == "defaults:":
            in_defaults = True; continue
        if in_defaults and "values:" in s:
            in_values = True; continue
        if in_values and (key + ":") in s:
            _, _, v = s.partition(key + ":")
            val = v.strip().strip("'\"").lower()
            if val:
                print(val); sys.exit(0)
print("")
PY
}

DEFAULT_TEMPLATE="base"
DEFAULT_LANG="de"
if [[ -f "_config.yml" ]]; then
    # Kein "x && y=z": unter set -e wuerde die Kette den Lauf beenden,
    # sobald ein Default in _config.yml fehlt.
    _cfg=$(config_default template)
    if [[ -n "$_cfg" ]]; then DEFAULT_TEMPLATE="$_cfg"; fi
    _cfg=$(config_default lang)
    if [[ -n "$_cfg" ]]; then DEFAULT_LANG="$_cfg"; fi
fi

# -- Plattform-kompatibles sed ------------------------------------------------
if [[ "$(uname)" == "Darwin" ]]; then
    SED_I=(sed -i '')
else
    SED_I=(sed -i)
fi

# -- Trennzeichen für --resource-path -----------------------------------------
# Pandoc erwartet das Trennzeichen des Betriebssystems. Unter Git Bash/MSYS läuft
# eine Windows-Binary, die ';' braucht — mit ':' wird die ganze Liste als ein
# einziger Pfad gelesen und keine Bilddatei gefunden.
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) RESOURCE_SEP=";" ;;
    *)                    RESOURCE_SEP=":" ;;
esac

# -- Parallelisierung ---------------------------------------------------------
MAX_JOBS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
RESULT_DIR="temp/pdf_results_$$"
mkdir -p "$OUTPUT_DIR" temp "$RESULT_DIR"

# Aufräumen bei Exit (auch bei Fehler)
trap 'rm -rf "$RESULT_DIR"' EXIT

# -- Front Matter in einem Python-Aufruf lesen --------------------------------
read_frontmatter() {
    python3 - "$1" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
lines = text.splitlines()
fm = {}
if lines and lines[0].strip() == "---":
    try:
        end = lines.index("---", 1)
        for line in lines[1:end]:
            if ":" in line:
                k, _, v = line.partition(":")
                fm[k.strip().lower()] = v.strip().strip("'\"").lower()
    except ValueError:
        pass
print(fm.get("template", ""))
print(fm.get("section_numbering", ""))
print(fm.get("lang", ""))
PY
}

# -- Verarbeitung einer einzelnen Datei (läuft im Hintergrund) ---------------
process_file() {
    local file="$1"
    local filename name out_file header_file template_name template_dir
    local section_numbering number_sections extra_flags doc_lang
    filename=$(basename -- "$file")
    name="${filename%.*}"
    out_file="${OUTPUT_DIR}/${name}.${FORMAT}"
    header_file="temp/${name}_header.tex"
    number_sections=""

    # Mtime-Check: Ausgabe neuer als Quelle → überspringen (nur bei pdf)
    if [[ "$FORMAT" == "pdf" && -f "$out_file" && "$out_file" -nt "$file" ]]; then
        echo "  -- $filename  (unverändert)"
        echo "skip" > "$RESULT_DIR/${name}.result"
        return 0
    fi

    echo "  -> $filename"

    # Front Matter: template + section_numbering + lang in einem Python-Aufruf
    local fm_out
    fm_out=$(read_frontmatter "$file")
    template_name=$(echo "$fm_out" | sed -n '1p')
    section_numbering=$(echo "$fm_out" | sed -n '2p')
    doc_lang=$(echo "$fm_out" | sed -n '3p')

    # Sprache: Front Matter schlaegt _config.yml, sonst DEFAULT_LANG.
    # Ohne lang laedt Pandoc kein babel - englische Trennregeln, "Figure"
    # statt "Abbildung".
    [[ -z "$doc_lang" ]] && doc_lang="$DEFAULT_LANG"

    # Template-Fallback: erst _config.yml-Default, dann "base"
    [[ -z "$template_name" ]] && template_name="$DEFAULT_TEMPLATE"
    if [[ -d "templates/$template_name" ]]; then
        template_dir="templates/$template_name"
    else
        template_name="base"
        template_dir="templates/base"
    fi

    # LaTeX-Header erstellen: erst der gemeinsame Teil, dann die Nummerierung
    cat > "$header_file" <<'EOF'
\usepackage{enumitem}
% Bilder bleiben an ihrer Textstelle. Ohne das gilt der LaTeX-Default 'tbp',
% der Bilder aus Listen heraus auf spätere Seiten schiebt.
\usepackage{float}
\floatplacement{figure}{H}
% Keine Wortreste unter drei Zeichen am Zeilenende oder -anfang. babel setzt für
% Deutsch 2/2, was Trennungen wie "ei-nem" erlaubt. Die Zuweisung muss
% verzögert erfolgen, weil babel die Werte bei der Sprachwahl sonst wieder
% überschreibt. Den Befehl hier nicht wörtlich nennen — die Fixture-Prüfung
% in scripts/test_pdfs.sh sucht danach, um die Präambel abzuschneiden.
\AtBeginDocument{\lefthyphenmin=3 \righthyphenmin=3}
EOF

    case "$section_numbering" in
        paragraph)
            number_sections="--number-sections"
            cat >> "$header_file" <<'EOF'
\renewcommand{\thesection}{\S\arabic{section}}
\renewcommand{\thesubsection}{\S\arabic{section}.\arabic{subsection}}
\renewcommand{\thesubsubsection}{\S\arabic{section}.\arabic{subsection}.\arabic{subsubsection}}
\makeatletter
\renewcommand{\@seccntformat}[1]{\ifcsname the#1\endcsname\csname the#1\endcsname\hspace{0.4em}\fi}
\renewcommand{\numberline}[1]{#1\hspace{0.6em}}
\makeatother
EOF
            ;;
        arabic)
            number_sections="--number-sections"
            ;;
    esac

    if [[ -f "$template_dir/pdf-header.tex" ]]; then
        cat "$template_dir/pdf-header.tex" >> "$header_file"
    fi

    # Temp-Kopie vorverarbeiten
    cp "$file" "temp/${name}_temp.md"

    # Datum-Platzhalter ersetzen
    "${SED_I[@]}" "s/{{ site.time | date: \"%d-%m-%Y\" }}/$CURRENT_DATE_DE/g" "temp/${name}_temp.md"
    "${SED_I[@]}" "s/{{ site.time | date: '%d-%m-%Y' }}/$CURRENT_DATE_DE/g"  "temp/${name}_temp.md"
    "${SED_I[@]}" "s/{{ site.time | date: \"%d.%m.%Y\" }}/$CURRENT_DATE_DE/g" "temp/${name}_temp.md"
    "${SED_I[@]}" "s/{{ site.time | date: '%d.%m.%Y' }}/$CURRENT_DATE_DE/g"  "temp/${name}_temp.md"
    "${SED_I[@]}" "s/^date: {{.*}}/date: $CURRENT_DATE_DE/"                    "temp/${name}_temp.md"

    # title2 → subtitle
    "${SED_I[@]}" "s/^title2:/subtitle:/" "temp/${name}_temp.md"

    # TOC-Syntax für LaTeX
    awk '
      { sub(/\r$/, ""); }
      $0 == "* TOC" || $0 == "TOC {:toc}" || $0 == "* TOC {:toc}" {
        print "\\clearpage\\renewcommand{\\contentsname}{Inhaltsverzeichnis}";
        print "\\tableofcontents";
        print "\\clearpage";
        skip = 1; next;
      }
      skip && $0 == "{:toc}" { skip = 0; next; }
      { print; }
    ' "temp/${name}_temp.md" > "temp/${name}_temp.md.tmp" \
      && mv "temp/${name}_temp.md.tmp" "temp/${name}_temp.md"

    # HTML-only-Blöcke entfernen
    "${SED_I[@]}" '/<div class="html-only"/,/^<\/div>$/d' "temp/${name}_temp.md"

    # Alphabetische HTML-Listen → LaTeX enumerate
    "${SED_I[@]}" '
    s|<ol type="a">|\\begin{enumerate}[label=\\alph*.]|g;
    s|</ol>|\\end{enumerate}|g;
    s|<li>|\\item |g;
    s|</li>||g;
    ' "temp/${name}_temp.md"

    # Markdown → PDF oder LaTeX
    # shellcheck disable=SC2086
    extra_flags=""
    [[ "$FORMAT" == "pdf" ]] && extra_flags="--pdf-engine=xelatex -V geometry:margin=1in"
    if pandoc "temp/${name}_temp.md" \
        -o "$out_file" \
        $number_sections \
        --toc-depth=2 \
        $extra_flags \
        --include-in-header="$header_file" \
        -V lang="$doc_lang" \
        --resource-path=".${RESOURCE_SEP}$(dirname "$file")${RESOURCE_SEP}./docs${RESOURCE_SEP}./${SOURCE_DIR}${RESOURCE_SEP}./templates${RESOURCE_SEP}./templates/$template_name"; then
        echo "     OK  $out_file"
        echo "ok" > "$RESULT_DIR/${name}.result"
    else
        echo "     ERR ${name}.${FORMAT}" >&2
        echo "err" > "$RESULT_DIR/${name}.result"
    fi
}

export -f process_file read_frontmatter
export FORMAT OUTPUT_DIR CURRENT_DATE_DE SOURCE_DIR RESULT_DIR DEFAULT_TEMPLATE DEFAULT_LANG RESOURCE_SEP
export SED_I

# -- Alle Markdown-Dateien parallel verarbeiten -------------------------------
declare -a BGPIDS
BGPIDS=()

limit_jobs() {
    local running=() pid
    if (( ${#BGPIDS[@]} > 0 )); then
        for pid in "${BGPIDS[@]}"; do
            kill -0 "$pid" 2>/dev/null && running+=("$pid")
        done
        BGPIDS=("${running[@]+"${running[@]}"}")
    fi
    while (( ${#BGPIDS[@]} >= MAX_JOBS )); do
        sleep 0.1
        running=()
        for pid in "${BGPIDS[@]}"; do
            kill -0 "$pid" 2>/dev/null && running+=("$pid")
        done
        BGPIDS=("${running[@]+"${running[@]}"}")
    done
}

while IFS= read -r -d '' file; do
    limit_jobs
    process_file "$file" &
    BGPIDS+=($!)
done < <(find "$SOURCE_DIR" -name "*.md" -print0)

# Auf alle Hintergrund-Jobs warten
for pid in "${BGPIDS[@]+"${BGPIDS[@]}"}"; do
    wait "$pid" || true
done

# -- Ergebnisse auswerten -----------------------------------------------------
count=0; errors=0; skipped=0
for f in "$RESULT_DIR"/*.result; do
    [[ -f "$f" ]] || continue
    result=$(cat "$f")
    case "$result" in
        ok)   count=$((count + 1))   ;;
        err)  errors=$((errors + 1)) ;;
        skip) skipped=$((skipped + 1)) ;;
    esac
done

echo ""
echo "${count} Datei(en) generiert, ${skipped} übersprungen, ${errors} Fehler"
[[ $errors -eq 0 ]]
