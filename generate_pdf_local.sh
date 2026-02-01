#!/bin/bash

# Create the assets/pdf directory if it doesn't exist
mkdir -p assets/pdf
mkdir -p temp

# Get the current date
CURRENT_DATE=$(date +%Y-%m-%d)
CURRENT_DATE_DE=$(date +%d.%m.%Y)

# Loop through all Markdown files in the docs directory
for file in docs/*.md; do
    filename=$(basename -- "$file")
    name="${filename%.*}" # Extract file name without extension
    cp "$file" "temp/${name}_temp.md"
    header_file="temp/${name}_header.tex"
    number_sections=""
    template_name=""
    template_dir=""

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

    if [ -z "$template_name" ]; then
        template_name="default"
    fi

    if [ -d "templates/$template_name" ]; then
        template_dir="templates/$template_name"
    else
        template_name="default"
    fi

    # Enable section prefixing for documents that request it
    if grep -q '^section_prefix:' "$file"; then
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
    else
        echo "\\usepackage{enumitem}" > "$header_file"
    fi

    if [ -n "$template_dir" ] && [ -f "$template_dir/pdf-header.tex" ]; then
        cat "$template_dir/pdf-header.tex" >> "$header_file"
    fi
    
    # Replace date placeholder in Markdown content (all templates)
    sed -i "s/{{ site.time | date: \"%d-%m-%Y\" }}/$CURRENT_DATE_DE/g" "temp/${name}_temp.md"
    sed -i "s/{{ site.time | date: '%d-%m-%Y' }}/$CURRENT_DATE_DE/g" "temp/${name}_temp.md"
    sed -i "s/{{ site.time | date: \"%d.%m.%Y\" }}/$CURRENT_DATE_DE/g" "temp/${name}_temp.md"
    sed -i "s/{{ site.time | date: '%d.%m.%Y' }}/$CURRENT_DATE_DE/g" "temp/${name}_temp.md"
    sed -i "s/{{ site.time | date: ‘%d.%m.%Y’ }}/$CURRENT_DATE_DE/g" "temp/${name}_temp.md"
    sed -i "s/date: {{ site.time | date: \"%d-%m-%Y\" }}/date: $CURRENT_DATE_DE/g" "temp/${name}_temp.md"
    sed -i "s/date: {{ site.time | date: '%d-%m-%Y' }}/date: $CURRENT_DATE_DE/g" "temp/${name}_temp.md"
    sed -i "s/date: {{ site.time | date: \"%d.%m.%Y\" }}/date: $CURRENT_DATE_DE/g" "temp/${name}_temp.md"
    sed -i "s/date: {{ site.time | date: '%d.%m.%Y' }}/date: $CURRENT_DATE_DE/g" "temp/${name}_temp.md"
    sed -i "s/^date: .*/date: $CURRENT_DATE_DE/" "temp/${name}_temp.md"

    # Replace TOC syntax for LaTeX
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
    
    # Remove HTML-only blocks for PDF generation
    sed -i '/<div class="html-only"/,/^<\/div>$/d' "temp/${name}_temp.md"

    # Convert HTML ordered lists (type="a") to LaTeX enumerate with alphabetic labels
    sed -i '
    s|<ol type="a">|\\begin{enumerate}[label=\\alph*.]|g;
    s|</ol>|\\end{enumerate}|g;
    s|<li>|\\item |g;
    s|</li>||g;
    ' "temp/${name}_temp.md"
    
    # Convert Markdown to PDF
    pandoc "temp/${name}_temp.md" -o "assets/pdf/${name}.pdf" \
      $number_sections \
      --toc-depth=2 \
      --pdf-engine=xelatex \
      -V geometry:margin=1in \
      --include-in-header="$header_file" \
      --resource-path=.:./docs:./templates:./templates/$template_name
done

echo "PDFs successfully generated in assets/pdf/"
