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

# -- Plattform-kompatibles sed ------------------------------------------------
if [[ "$(uname)" == "Darwin" ]]; then
    SED_I=(sed -i '')
else
    SED_I=(sed -i)
fi

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
PY
}

# -- Verarbeitung einer einzelnen Datei (läuft im Hintergrund) ---------------
process_file() {
    local file="$1"
    local filename name out_file header_file template_name template_dir
    local section_numbering number_sections extra_flags
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

    # Front Matter: template + section_numbering in einem Python-Aufruf
    local fm_out
    fm_out=$(read_frontmatter "$file")
    template_name=$(echo "$fm_out" | sed -n '1p')
    section_numbering=$(echo "$fm_out" | sed -n '2p')

    # Template-Fallback
    [[ -z "$template_name" ]] && template_name="base"
    if [[ -d "templates/$template_name" ]]; then
        template_dir="templates/$template_name"
    else
        template_name="base"
        template_dir="templates/base"
    fi

    # LaTeX-Header erstellen
    case "$section_numbering" in
        paragraph)
            number_sections="--number-sections"
            cat > "$header_file" <<'EOF'
\usepackage{enumitem}
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
            echo "\\usepackage{enumitem}" > "$header_file"
            ;;
        *)
            echo "\\usepackage{enumitem}" > "$header_file"
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
        --resource-path=".:$(dirname "$file"):./docs:./${SOURCE_DIR}:./templates:./templates/$template_name"; then
        echo "     OK  $out_file"
        echo "ok" > "$RESULT_DIR/${name}.result"
    else
        echo "     ERR ${name}.${FORMAT}" >&2
        echo "err" > "$RESULT_DIR/${name}.result"
    fi
}

export -f process_file read_frontmatter
export FORMAT OUTPUT_DIR CURRENT_DATE_DE SOURCE_DIR RESULT_DIR
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
