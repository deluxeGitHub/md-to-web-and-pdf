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

## Architektur

### Verzeichnisstruktur

| Pfad | Zweck |
|---|---|
| `templates/` | Modulare Web- und PDF-Templates pro Verband |
| `templates/shared/web.css` | Gemeinsame Basis-CSS für alle Templates |
| `templates/base/` | Neutrales Fallback-Template |
| `templates/btfv/` | BTFV-spezifisches Design |
| `templates/dtfb/` | DTFB-spezifisches Design |
| `scripts/generate_pdfs.sh` | PDF-Generierung (Pandoc + XeLaTeX) |
| `scripts/test_pdfs.sh` | Regressionstests gegen LaTeX-Fixtures |
| `_layouts/default.html` | Jekyll-Layout für alle Seiten |
| `_includes/templates/` | Jekyll-Partials (Header, Navigation) |
| `.github/workflows/reusable-build.yml` | Reusable Workflow für Docs-Repos |
| `example/` | Vollständiges Beispiel-Repo |
| `test/` | Test-Dokumente und Fixtures |

### Templates

Jedes Template enthält:

| Datei | Zweck |
|---|---|
| `web.css` | CSS-Variablen (Farben, Fonts) |
| `pdf-header.tex` | LaTeX-Header (Fonts, Farben, Logo, Fußzeile) |
| `images/logo.png` | Verbandslogo |
| `images/favicon.png` | Favicon |

---

## Dokument-Format

```yaml
---
title: "Satzung"
subtitle: "des BTFV e.V."
date: "{{ site.time | date: '%d.%m.%Y' }}"
layout: default
template: btfv                  # base | btfv | dtfb | eigenes Custom Theme
section_numbering: paragraph    # paragraph=§ | arabic=1.1 | weglassen=keine
pdf: /assets/pdf/satzung.pdf
---
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
