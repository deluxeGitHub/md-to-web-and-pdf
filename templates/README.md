# Templates

This folder contains modular HTML/PDF templates that can be referenced from Markdown files.

## Usage in Markdown front matter

```
template: base
layout: default
pdf: /assets/pdf/<document>.pdf
source: https://github.com/<org>/<repo>/blob/main/docs/<document>.md
```

## Structure

- `templates/<template>/web.css` - Web styles for Jekyll pages
- `templates/<template>/pdf-header.tex` - LaTeX header injected into Pandoc for PDF export
- `templates/<template>/images/` - Shared assets used by both web and PDF

Create a new template by copying `templates/base` and adjusting the assets and styles.
