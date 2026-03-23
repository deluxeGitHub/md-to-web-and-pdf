# md-to-web-and-pdf

Framework zur automatischen Erstellung von Verbandsdokumenten als PDF und Website (GitHub Pages).
Markdown-Dateien werden per GitHub Actions in PDFs umgewandelt und als Jekyll-Website veröffentlicht.

---

## Funktionsweise

```
docs/*.md  →  GitHub Actions (Pandoc + XeLaTeX)  →  assets/pdf/*.pdf
docs/*.md  →  Jekyll                              →  GitHub Pages (HTML)
```

Dieses Repo stellt das Framework bereit. Dokument-Repos binden es als **reusable workflow** ein und pflegen nur ihre Markdown-Dateien.

---

## Für Anwender: Eigenes Docs-Repo einrichten

Siehe [`example/README.md`](example/README.md) für eine Schritt-für-Schritt-Anleitung.

Kurzfassung:
1. Neues GitHub-Repo erstellen
2. Dateien aus [`example/`](example/) kopieren
3. `baseurl` in `.github/workflows/build.yml` anpassen
4. GitHub Pages aktivieren (`gh-pages`-Branch, Root)
5. Workflow-Berechtigungen auf "Read and write" setzen
6. Pushen – fertig

---

## Web-Features

Die generierten HTML-Seiten enthalten eine Reihe von eingebauten UX-Features.

### PWA-Unterstützung

Jede Website kann auf iOS und Android als Progressive Web App installiert werden:
- `manifest.webmanifest` wird automatisch vom Framework bereitgestellt (kann im Docs-Repo überschrieben werden)
- App-Icon und Name werden aus `_config.yml` und dem jeweiligen Template bezogen
- Auf iOS: transparente Statusleiste (`black-translucent`) mit Safe-Area-Abdeckung in der Template-Farbe
- Scroll-Fortschrittsbalken liegt korrekt unterhalb der Notch/Dynamic Island

### Theme: Hell / Dunkel / Auto

Der Zahnrad-Button im Header enthält einen dreistufigen Theme-Toggle:
- **Hell** – helles Design
- **Dunkel** – dunkles Design
- **Auto** – folgt der Systemeinstellung des Geräts und reagiert auf Wechsel in Echtzeit

Die Auswahl wird in `localStorage` gespeichert.

### Schriftgröße

Im Einstellungs-Panel (Zahnrad) ist ein Stufenregler für die Schriftgröße integriert:
- 5 Stufen: 70 % / 85 % / **100 %** (Standard) / 125 % / 150 %
- Kleines und großes „A" links/rechts vom Slider sind ebenfalls klickbar
- Aktuelle Stufe wird als Prozentzahl angezeigt
- Tabellen, Überschriften, Fließtext und TOC skalieren mit

Die Einstellung wird in `localStorage` gespeichert.

### In-Page-Suche

- **Desktop:** Lupen-Button im Header öffnet eine Suchleiste unten
- **Mobile:** Suche im Einstellungs-Panel (Zahnrad), Suchleiste erscheint oben (über der virtuellen Tastatur)
- Treffer werden gelb markiert, der aktive Treffer orange hervorgehoben
- Navigation mit ←/→-Buttons, Enter-Taste oder Escape zum Schließen
- Öffnet sich auch mit `Ctrl`/`Cmd`+`F`
- Kein Auto-Zoom auf iOS (font-size 16 px, `user-scalable=no`)

### Scroll-Fortschrittsbalken

Ein dünner Balken in der Template-Akzentfarbe zeigt den Lesefortschritt an. Er liegt in der PWA direkt unterhalb der Safe-Area.

### Heading-Links

Klick auf ein Überschriften-Symbol kopiert den direkten Anker-Link in die Zwischenablage. Ein Toast bestätigt den Kopiervorgang.

### Weitere Features

- **Zurück-nach-oben-Button** – erscheint nach 200 px Scroll-Tiefe
- **Staging-Banner** – sichtbar wenn der `baseurl`-Pfad auf `/staging` endet
- **Responsive Design** – auf Mobile (≤540 px) kein Rahmen/Schatten um den Inhalt, volle Breite

---

## Architektur

### Verzeichnisstruktur

| Pfad | Zweck |
|---|---|
| `templates/` | Modulare Web- und PDF-Templates pro Verband |
| `templates/shared/web.css` | Gemeinsame Basis-CSS für alle Templates |
| `templates/base/` | Neutrales Fallback-Template |
| `templates/btfv/` | BTFV-spezifisches Design |
| `templates/dtfb/` | DTFB-spezifisches Design |
| `templates/stfv/` | STFV-spezifisches Design |
| `scripts/generate_pdfs.sh` | PDF-Generierung (Pandoc + XeLaTeX) |
| `scripts/test_pdfs.sh` | Regressionstests gegen LaTeX-Fixtures |
| `_layouts/default.html` | Jekyll-Layout für alle Seiten |
| `_includes/templates/` | Jekyll-Partials (Header, Navigation) |
| `manifest.webmanifest` | PWA-Manifest (Liquid-Template) |
| `.github/workflows/reusable-build.yml` | Reusable Workflow für Docs-Repos |
| `example/` | Vollständiges Beispiel-Repo |
| `test/` | Test-Dokumente und Fixtures |

### Templates

Jedes Template enthält:

| Datei | Zweck |
|---|---|
| `web.css` | CSS-Variablen (Farben) für Hell- und Dunkel-Modus |
| `pdf-header.tex` | LaTeX-Header (Fonts, Farben, Logo, Fußzeile) |
| `images/logo.png` | Verbandslogo |
| `images/favicon.png` | Favicon / PWA-Icon |

---

## Dokument-Format

```yaml
---
title: "Satzung"
subtitle: "des BTFV e.V."              # optional
date: "{{ site.time | date: '%d.%m.%Y' }}"
template: dtfb                         # optional – nur wenn vom Default in _config.yml abweichend
section_numbering: paragraph           # optional – paragraph | arabic | weglassen = keine
pdf: /assets/pdf/satzung.pdf          # optional – für Download-Link auf der Website
---
```

`layout` und `template` müssen nicht gesetzt werden, wenn der Repo-weite Default aus `_config.yml` passt:

```yaml
# _config.yml
defaults:
  - scope:
      path: ""
    values:
      layout: default
      template: btfv
```

### Abschnittsnummerierung

| Wert | HTML & PDF |
|---|---|
| `paragraph` | § 1, § 1.1, § 1.1.1 … |
| `arabic` | 1, 1.1, 1.1.1 … |
| *(nicht gesetzt)* | Keine Nummerierung |

---

## Custom Themes in Docs-Repos

Docs-Repos können eigene Templates mitbringen, ohne dieses Framework-Repo zu verändern.

**Struktur im Docs-Repo:**
```
templates/meinverein/
├── web.css
├── pdf-header.tex
└── images/
    ├── logo.png
    └── favicon.png
```

**Registrierung in `_config.yml` des Docs-Repos:**
```yaml
custom_templates:
  - meinverein
```

Eingebaute Templates können auch partiell überschrieben werden – Dateien im Docs-Repo haben Vorrang vor dem Framework.

---

## Reusable Workflow einbinden

```yaml
# .github/workflows/build.yml im Docs-Repo
jobs:
  build:
    uses: deluxeGitHub/md-to-web-and-pdf/.github/workflows/reusable-build.yml@main
    with:
      source_dir: docs
      baseurl: /mein-repo-name
    permissions:
      contents: write
```

### Workflow-Inputs

| Input | Standard | Beschreibung |
|---|---|---|
| `source_dir` | `docs` | Ordner mit Markdown-Dateien |
| `baseurl` | *(leer)* | Jekyll baseurl für GitHub Pages project pages |
| `framework_ref` | `main` | Branch oder Tag des Framework-Repos |
| `staging_branch` | `staging` | Branch der als Vorschau-Version deployt wird |

---

## Lokale Entwicklung

```bash
bash build.sh
```

Interaktives Menü für PDF-Generierung, Jekyll-Vorschau und Tests.

**Voraussetzungen:** `pandoc`, `xelatex` (TeX Live), `jekyll`

---

## Neues Template zum Framework hinzufügen

1. Ordner `templates/<name>/` anlegen mit `web.css`, `pdf-header.tex`, `images/logo.png`, `images/favicon.png`
2. Template-Namen in `_layouts/default.html` in die `supported_templates`-Liste aufnehmen:
   ```liquid
   {% assign supported_templates = "base,dtfb,btfv,<name>" | split: "," %}
   ```

---

## Lizenz

[UNLICENSE](LICENSE) – Public Domain
