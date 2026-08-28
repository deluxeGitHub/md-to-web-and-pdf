#!/usr/bin/env bash
# =============================================================================
# scripts/normalize_html.sh – HTML für den Fixture-Vergleich normalisieren
#
# Liest eine HTML-Datei und schreibt sie normalisiert nach stdout. Entfernt
# alles, was sich bei jedem Jekyll-Lauf ändert, ohne dass sich am Layout etwas
# geändert hätte.
#
# Genau eine Quelle für die Normalisierung: benutzt von
# scripts/generate_test_fixtures.sh (beim Schreiben der Fixtures) und von
# test_suite_html_fixtures in scripts/test_pdfs.sh (beim Vergleich). Zwei
# getrennte Sätze sed-Aufrufe würden auseinanderlaufen und den Vergleich
# stillschweigend wertlos machen.
#
# Verwendung:
#   bash scripts/normalize_html.sh <datei.html>
# =============================================================================
set -euo pipefail

if [[ $# -lt 1 || ! -f "$1" ]]; then
    echo "Verwendung: bash scripts/normalize_html.sh <datei.html>" >&2
    exit 2
fi

# 1. Wagenrückläufe: Fixtures liegen unter Windows ggf. mit CRLF im
#    Arbeitsverzeichnis, frisch gebautes HTML unter WSL mit LF.
# 2. Datumszeile: kommt aus site.time.
# 3. Cache-Buster an Stylesheets und PDF-Links: Zeitstempel des Builds.
# 4. buildV im Layout-Skript: derselbe Zeitstempel, zweite Stelle.
# 5. Abschliessende Leerzeichen.
tr -d '\r' < "$1" \
| sed 's|<div class="base-doc-date">.*</div>||g' \
| sed -E 's/\?v=[0-9]+//g' \
| sed -E "s/const buildV = '[0-9]+'/const buildV = 'X'/" \
| sed -E 's/[[:space:]]+$//'
