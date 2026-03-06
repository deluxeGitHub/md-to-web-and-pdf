# CLAUDE.md – Repository-Überblick

Dieses Repository verwaltet offizielle Verbandsdokumente (primär für den BTFV) als Markdown-Dateien und rendert sie sowohl als Jekyll-Website (GitHub Pages) als auch als PDF.

---

## Architektur

### Dokumenten-Pipeline

```
docs/*.md  →  [generate_pdf_local.sh / GitHub Actions]  →  assets/pdf/*.pdf
docs/*.md  →  [Jekyll]  →  GitHub Pages (HTML)
```

Die zentrale Logik liegt in `generate_pdf_local.sh`, das Markdown-Dateien vorverarbeitet und via `pandoc` + `xelatex` in PDFs konvertiert.

### Verzeichnisstruktur

| Pfad | Zweck |
|---|---|
| `docs/` | Quell-Dokumente im Markdown-Format |
| `docs/images/` | Bilder, die in Dokumenten referenziert werden |
| `assets/pdf/` | Automatisch generierte PDFs (nicht manuell bearbeiten) |
| `assets/css/` | Globales CSS für HTML-Darstellung |
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
template: btfv          # Welches Template soll verwendet werden (base/btfv/dtfb)
section_prefix: "§"     # Aktiviert §-Präfix für Überschriften-Nummerierung
pdf: /assets/pdf/satzung.pdf   # Link zur generierten PDF-Version
source: https://github.com/...  # Link zur Markdown-Quelle
---
```

### Wichtige Front-Matter-Felder

- **`template`**: Wählt das Verband-Template (`base`, `btfv`, `dtfb`). Unbekannte Werte fallen auf `base` zurück.
- **`section_prefix`**: Wenn gesetzt, werden Abschnittsnummern mit `§` dargestellt (LaTeX-Header wird angepasst).
- **`pdf`**: Wird im HTML genutzt, um einen Download-Link zur PDF anzuzeigen.
- **`date`**: Wird von `generate_pdf_local.sh` **überschrieben** – statische Datumsangaben im Front Matter haben im PDF keinen Bestand.

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
bash generate_pdf_local.sh
```

**Voraussetzungen:** `pandoc`, `xelatex` (TeX Live / MiKTeX)

Das Skript verarbeitet alle `*.md`-Dateien in `docs/` und legt PDFs in `assets/pdf/` ab.

### Automatisch via GitHub Actions

Bei jedem Push auf `main` läuft `.github/workflows/generate-pdf.yml`. Dieser Workflow:
1. Ersetzt Datumsplatzhalter durch das aktuelle Datum
2. Konvertiert Markdown → PDF via Pandoc/XeLaTeX
3. Committet die generierten PDFs zurück in `assets/pdf/`

**Wichtig:** Das Repository benötigt unter `Settings → Actions → General → Workflow permissions` die Einstellung **"Read and write permissions"**, damit der Workflow die PDFs zurückpushen kann.

### Jekyll-Vorschau (lokal)

```bash
bash run_jekyll.sh
```

Öffne danach `http://localhost:4000/` im Browser. Das Skript installiert fehlende Gems automatisch.

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
- **Bilder in PDFs** müssen über `--resource-path` erreichbar sein (aktuell: `.`, `./docs`, `./templates`, `./templates/<name>`).
- **`<ol type="a">`** sollte nur für wirklich alphabetisch nummerierte Listen verwendet werden – die Konvertierung ist ein einfaches Textersetzungs-Pattern und funktioniert nicht für verschachtelte oder gemischte Listen.
