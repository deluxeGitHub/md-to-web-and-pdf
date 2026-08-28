# CLAUDE.md – Repository-Überblick

Dieses Repository verwaltet offizielle Verbandsdokumente (primär für den BTFV) als Markdown-Dateien und rendert sie sowohl als Jekyll-Website (GitHub Pages) als auch als PDF.

> **Lokaler Entwicklungs-Harness:** Falls das Verzeichnis `harness/` existiert (gitignored,
> nur lokal), zuerst `harness/AGENTS.md` lesen — dort liegen Spec-Prozess, Infrastruktur-
> Fakten und der aktuelle Arbeitsstand.

---

## Architektur

### Dokumenten-Pipeline

```
docs/*.md  →  [build.sh / GitHub Actions]  →  assets/pdf/*.pdf
docs/*.md  →  [Jekyll]  →  GitHub Pages (HTML)
```

Die zentrale Logik liegt in `scripts/generate_pdfs.sh`, das Markdown-Dateien vorverarbeitet und via `pandoc` + `xelatex` in PDFs konvertiert.

### Verzeichnisstruktur

| Pfad | Zweck |
|---|---|
| `docs/` | Quell-Dokumente im Markdown-Format |
| `docs/images/` | Bilder, die in Dokumenten referenziert werden |
| `assets/pdf/` | Automatisch generierte PDFs (nicht manuell bearbeiten) |
| `templates/` | Modulare Web- und PDF-Templates pro Verband |
| `templates/shared/` | Gemeinsame Stile (web.css) für alle Templates |
| `templates/base/` | Basis-Template (Fallback) |
| `templates/btfv/` | BTFV-spezifische Styles und Bilder |
| `templates/dtfb/` | DTFB-spezifische Styles und Bilder |
| `_layouts/default.html` | Jekyll-Layout für alle Seiten |
| `_includes/templates/` | Jekyll-Partials (Header, Navigation, etc.) |
| `_config.yml` | Jekyll-Konfiguration |

---

## Dokument-Format (Front Matter)

Jedes Markdown-Dokument beginnt mit einem YAML-Front-Matter-Block:

```yaml
---
title: "Satzung"
subtitle: "des BTFV e.V."
date: 23.11.2025
layout: default
template: btfv                    # Welches Template (base/btfv/dtfb)
section_numbering: paragraph      # paragraph=§1§1.1, arabic=1/1.1, nicht gesetzt=keine
lang: de                          # Dokumentsprache; Default aus _config.yml
pdf: /assets/pdf/satzung.pdf      # Link zur generierten PDF-Version
source: https://github.com/...    # Link zur Markdown-Quelle
---
```

### Wichtige Front-Matter-Felder

- **`template`**: Wählt das Verband-Template (`base`, `btfv`, `dtfb`). Unbekannte Werte fallen auf `base` zurück.
- **`lang`**: Dokumentsprache für PDF **und** HTML. Steuert im PDF die Silbentrennung und die automatischen Bezeichner (`de` → „Abbildung“ statt „Figure“) und setzt `<html lang="…">`. Nicht gesetzt → Default aus `_config.yml` (`de`). Ohne `lang` lädt Pandoc kein `babel` und trennt deutschen Text nach englischen Regeln.
- **`section_numbering`**: `paragraph` → §1, §1.1 … / `arabic` → 1, 1.1 … / nicht gesetzt → keine Nummerierung.
- **`pdf`**: Wird im HTML genutzt, um einen Download-Link zur PDF anzuzeigen.
- **`date`**: Wird von `scripts/generate_pdfs.sh` **überschrieben** – statische Datumsangaben im Front Matter haben im PDF keinen Bestand.

---

## Spezielle Markdown-Syntax

Diese Repo-spezifischen Konstrukte werden von der PDF-Pipeline verarbeitet:

### Inhaltsverzeichnis

```markdown
* TOC
{:toc}
```

Wird im PDF zu `\tableofcontents` konvertiert. In HTML rendert Jekyll daraus automatisch ein TOC.

### Datum-Platzhalter

```markdown
date: {{ site.time | date: "%d.%m.%Y" }}
```

Wird beim PDF-Export durch das aktuelle Datum (des Lauf-Zeitpunkts) ersetzt.

### Breite Tabellen

Breite Tabellen brauchen **kein** Sondermarkup. Ist eine Tabelle breiter als der Inhaltsbereich, legt das Layout-Skript in `_layouts/default.html` zur Laufzeit einen Scroll-Container (`div.table-scroll`) um sie, blendet einen Hinweis ein und lässt ab drei Spalten die erste Spalte stehen. Wrapper-Divs oder `<style>`-Blöcke in der Markdown-Datei sind dafür nicht nötig und sollen nicht eingefügt werden.

Die schmale letzte Spalte (Index-Tabellen mit PDF-Link) wird ebenfalls automatisch erkannt – über die Klasse `table-linkcol`, die das Skript setzt, wenn jede Zelle der letzten Spalte ausschließlich einen Link enthält.

### HTML-Only-Blöcke

```html
<div class="html-only">
  Dieser Inhalt erscheint nur in der HTML-Version.
</div>
```

Wird bei der PDF-Erstellung vollständig entfernt.

### Alphabetische Listen (nur für PDF)

```html
<ol type="a">
  <li>Erster Punkt</li>
  <li>Zweiter Punkt</li>
</ol>
```

Wird im PDF-Prozess in LaTeX-`enumerate` mit `[label=\alph*.]` umgewandelt.

---

## Templates

Jedes Template (`base`, `btfv`, `dtfb`) enthält:

| Datei | Zweck |
|---|---|
| `web.css` | Template-spezifische CSS-Overrides für HTML |
| `pdf-header.tex` | LaTeX-Header-Datei für PDF-Rendering (Fonts, Farben, etc.) |
| `images/logo.png` | Verbandslogo (erscheint im Dokumentheader) |
| `images/favicon.png` | Favicon für die Website |

Gemeinsame Styles liegen in `templates/shared/web.css`.

---

## PDF-Generierung

### Lokal

```bash
bash build.sh
```

**Voraussetzungen:** `pandoc`, `xelatex` (TeX Live / MiKTeX)

Das interaktive Menü bietet Optionen für PDF-Generierung, Jekyll-Vorschau und Tests. Die eigentliche Logik liegt in `scripts/generate_pdfs.sh`.

### Automatisch via GitHub Actions

Bei jedem Push auf `main` läuft `.github/workflows/generate-pdf.yml`. Dieser Workflow:
1. Ersetzt Datumsplatzhalter durch das aktuelle Datum
2. Konvertiert Markdown → PDF via Pandoc/XeLaTeX
3. Committet die generierten PDFs zurück in `assets/pdf/`

**Wichtig:** Das Repository benötigt unter `Settings → Actions → General → Workflow permissions` die Einstellung **"Read and write permissions"**, damit der Workflow die PDFs zurückpushen kann.

### Jekyll-Vorschau (lokal)

```bash
bash build.sh
```

Im Menü die Option für Jekyll-Vorschau wählen. Öffne danach `http://localhost:4000/` im Browser.

---

## Neues Dokument anlegen

1. Neue `.md`-Datei in `docs/` erstellen
2. Front Matter einfügen (mindestens `title`, `layout: default`, `template`)
3. Inhalt schreiben (Standard-Markdown + oben beschriebene Spezial-Syntax)
4. Optional: `pdf: /assets/pdf/<name>.pdf` ins Front Matter eintragen, sobald PDF existiert
5. Push auf `main` → PDF wird automatisch generiert

---

## Neues Template anlegen

1. Ordner `templates/<name>/` anlegen
2. `web.css`, `pdf-header.tex` und `images/logo.png` hinzufügen
3. Template-Namen in `_layouts/default.html` in die `supported_templates`-Liste aufnehmen:
   ```liquid
   {% assign supported_templates = "base,dtfb,btfv,<name>" | split: "," %}
   ```

---

## Häufige Fallstricke

- **PDFs nicht manuell bearbeiten** – sie werden bei jedem Workflow-Lauf überschrieben.
- **`date` im Front Matter** wird vom Skript überschrieben; für ein fixes Datum muss die Datum-Ersetzung im Skript angepasst werden.
- **Bilder in PDFs** müssen über `--resource-path` erreichbar sein (aktuell: `.`, `./docs`, `./templates`, `./templates/<name>`). Das Trennzeichen der Liste ist plattformabhängig – unter Git Bash/MSYS `;`, sonst `:`; `scripts/generate_pdfs.sh` setzt das über `RESOURCE_SEP`. Mit dem falschen Trennzeichen findet Pandoc keine Bilddatei und ersetzt das Bild kommentarlos durch seinen Alt-Text.
- **Bilder stehen im PDF fest an ihrer Textstelle** (`\floatplacement{figure}{H}` im Preamble von `scripts/generate_pdfs.sh`). Passt ein Bild nicht mehr auf die Seite, beginnt eine neue – der Weißraum davor ist gewollt und keine Regression.
- **Titelschrift ohne Condensed:** Der Schnitt „TeX Gyre Heros Condensed" existiert unter diesem Namen nicht (korrekt wäre `TeX Gyre Heros Cn`). Die Fallback-Kette in `templates/*/pdf-header.tex` nutzt bewusst weiter `TeX Gyre Heros` – nicht „reparieren", sonst ändern sich alle Titelblätter.
- **`exclude:` in `_config.yml` und `test/_config.test.yml`** müssen zusammen gepflegt
  werden. `test/` steht in `_config.yml` unter `exclude:`, damit die Testdokumente nicht
  auf der Website landen; `test/_config.test.yml` spiegelt dieselbe Liste **ohne** `test/`,
  damit `scripts/test_pdfs.sh` und `scripts/generate_test_fixtures.sh` sie bauen können.
  Wächst die eine Liste, muss die andere mitwachsen — sonst vergleicht die HTML-Suite
  stillschweigend nichts mehr.
- **Normalisierung der HTML-Fixtures** liegt genau einmal in `scripts/normalize_html.sh`
  (Datum, Cache-Buster `?v=`, `buildV`, Zeilenenden). Vergleich und Fixture-Erstellung
  benutzen dieselbe Datei; ein zweiter Satz `sed`-Aufrufe würde auseinanderlaufen.
- **`<ol type="a">`** sollte nur für wirklich alphabetisch nummerierte Listen verwendet werden – die Konvertierung ist ein einfaches Textersetzungs-Pattern und funktioniert nicht für verschachtelte oder gemischte Listen.
