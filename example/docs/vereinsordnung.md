---
title: "Vereinsordnung"
subtitle: "des Meinverein e.V."
date: "{{ site.time | date: '%d.%m.%Y' }}"
template: meinverein
section_numbering: paragraph
pdf: /assets/pdf/vereinsordnung.pdf
---

* TOC
{:toc}

# Allgemeine Bestimmungen

Dieses Dokument demonstriert ein **Custom Theme** (`meinverein`) mit eigenem
Farbschema, Logo und Favicon – vollständig im Docs-Repo definiert, ohne das
Framework-Repo zu verändern.

## Zweck

1. Dieses Dokument dient als Beispiel für ein eigenes Theme.
1. Das Theme liegt unter `templates/meinverein/` im Docs-Repo.
1. Es ergänzt die eingebauten Themes (`base`, `btfv`, `dtfb`).

## Geltungsbereich

1. Das Custom-Theme gilt nur für dieses Docs-Repo.
1. Andere Repos bleiben davon unberührt.

# Theme-Konfiguration

## Benötigte Dateien

```
templates/meinverein/
├── web.css              ← CSS-Variablen (Farben, Fonts)
├── pdf-header.tex       ← LaTeX-Header für PDFs
└── images/
    ├── logo.png         ← Logo (mind. 400×120 px, PNG mit Transparenz)
    └── favicon.png      ← Favicon (32×32 px)
```

## Registrierung in _config.yml

```yaml
custom_templates:
  - meinverein
```

## Verwendung im Dokument

```yaml
---
template: meinverein
---
```

# Schlussbestimmungen

1. Logo und Favicon können jederzeit durch eigene Grafiken ersetzt werden.
1. In `web.css` lassen sich alle Farben über CSS-Variablen anpassen.
1. `pdf-header.tex` steuert Schrift, Farben und Layout der PDF-Version.
