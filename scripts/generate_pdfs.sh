#!/usr/bin/env bash
# =============================================================================
# scripts/generate_pdfs.sh – Kanonische PDF-Generierung
#
# Dieses Script ist die einzige Quelle der Wahrheit für PDF-Builds.
# Sowohl build.sh (lokal) als auch der GitHub Actions Workflow rufen es auf.
#
# Verwendung:
#   bash scripts/generate_pdfs.sh [DATUM_DE] [SOURCE_DIR] [OUTPUT_DIR]
#
#   DATUM_DE    Optionales Datum im Format DD.MM.YYYY. Standard: heute.
#   SOURCE_DIR  Quell-Verzeichnis mit *.md-Dateien.  Standard: docs
#   OUTPUT_DIR  Ausgabe-Verzeichnis für PDFs.         Standard: assets/pdf
# =============================================================================
set -euo pipefail

# Immer relativ zum Repo-Root ausführen
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# -- Argumente ----------------------------------------------------------------
CURRENT_DATE_DE="${1:-$(date +%d.%m.%Y)}"
SOURCE_DIR="${2:-docs}"
OUTPUT_DIR="${3:-assets/pdf}"

# -- Plattform-kompatibles sed ------------------------------------------------
if [[ "$(uname)" == "Darwin" ]]; then
    SED_I=(sed -i '')
else
    SED_I=(sed -i)
fi

# -- Ausgabe-Verzeichnisse ----------------------------------------------------
mkdir -p "$OUTPUT_DIR" temp

count=0
errors=0

# -- Alle Markdown-Dateien im Source-Verzeichnis (rekursiv) ------------------
while IFS= read -r -d '' file; do
    filename=$(basename -- "$file")
    name="${filename%.*}"
    cp "$file" "temp/${name}_temp.md"
    header_file="temp/${name}_header.tex"
    number_sections=""
    template_name=""
    template_dir=""

    echo "  -> $filename"

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

    # Fallback auf "base" (nicht "default" – das Verzeichnis existiert nicht)
    [[ -z "$template_name" ]] && template_name="base"
    if [[ -d "templates/$template_name" ]]; then
        template_dir="templates/$template_name"
    else
        template_name="base"
        template_dir="templates/base"
    fi

    # LaTeX-Header erstellen
    # section_numbering: paragraph → §1, §2 … (z.B. BTFV-Satzung)
    # section_numbering: arabic   → 1, 1.1 … (z.B. DTFB-Ausschreibungen)
    # (nicht gesetzt)             → keine Nummerierung
    section_numbering=$(python3 - "$file" <<'PY'
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text(encoding="utf-8")
lines = text.splitlines()
if not lines or lines[0].strip() != "---":
    sys.exit(0)
try:
    fm_end = lines.index("---", 1)
except ValueError:
    sys.exit(0)
for line in lines[1:fm_end]:
    if line.lower().startswith("section_numbering:"):
        print(line.split(":", 1)[1].strip().strip("'\"").lower())
        break
PY
    )

    case "$section_numbering" in
        paragraph)
            number_sections="--number-sections"
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

    # Datum-Platzhalter ersetzen (alle bekannten Formate)
    "${SED_I[@]}" "s/{{ site.time | date: \"%d-%m-%Y\" }}/$CURRENT_DATE_DE/g" "temp/${name}_temp.md"
    "${SED_I[@]}" "s/{{ site.time | date: '%d-%m-%Y' }}/$CURRENT_DATE_DE/g"  "temp/${name}_temp.md"
    "${SED_I[@]}" "s/{{ site.time | date: \"%d.%m.%Y\" }}/$CURRENT_DATE_DE/g" "temp/${name}_temp.md"
    "${SED_I[@]}" "s/{{ site.time | date: '%d.%m.%Y' }}/$CURRENT_DATE_DE/g"  "temp/${name}_temp.md"
    "${SED_I[@]}" "s/^date: .*/date: $CURRENT_DATE_DE/"                       "temp/${name}_temp.md"

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

    # Markdown → PDF
    # shellcheck disable=SC2086
    if pandoc "temp/${name}_temp.md" \
        -o "${OUTPUT_DIR}/${name}.pdf" \
        $number_sections \
        --toc-depth=2 \
        --pdf-engine=xelatex \
        -V geometry:margin=1in \
        --include-in-header="$header_file" \
        --resource-path=".:./docs:./${SOURCE_DIR}:./templates:./templates/$template_name"; then
        echo "     OK  ${OUTPUT_DIR}/${name}.pdf"
        count=$((count + 1))
    else
        echo "     ERR ${name}.pdf" >&2
        errors=$((errors + 1))
    fi

done < <(find "$SOURCE_DIR" -name "*.md" -print0)

echo ""
echo "${count} PDF(s) generiert, ${errors} Fehler"
[[ $errors -eq 0 ]]
