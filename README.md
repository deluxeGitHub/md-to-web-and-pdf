# BTFV Verbandsdokumente

Dieses Repository enthält die offiziellen Dokumente des Bayerischen Tischfußballverbands e.V. (BTFV) als Markdown-Dateien. Die Dokumente werden automatisch in PDF-Dateien umgewandelt und stehen zum Download bereit.

## Inhalt

- **docs/**: Enthält die Markdown-Quellen der Verbandsdokumente (`satzung.md`, `spielordnung.md`, `gebuehrenordnung.md` usw.).
- **assets/pdf/**: Hier werden die automatisch generierten PDF-Versionen der Dokumente abgelegt.
- **templates/**: Enthält modulare Templates (Web + PDF) für verschiedene Verbände.
- **scripts/**: Build- und Test-Skripte (werden von `build.sh` aufgerufen).
- **.github/workflows/generate-pdf.yml**: GitHub Actions Workflow zur automatischen PDF-Erstellung bei jedem Push auf den `main`-Branch.
- **_layouts/** und **_config.yml**: Dateien für das Jekyll-Setup zur HTML-Darstellung auf GitHub Pages.

---

## Hinweise zur Bearbeitung der Markdown-Dokumente

Die Dokumente werden im [Markdown-Format](https://www.markdownguide.org/basic-syntax/) geschrieben. Markdown ist eine einfache Auszeichnungssprache, die leicht zu lesen und zu bearbeiten ist – auch für Nicht-ITler.

### Automatische Platzhalter und "Magic"

- **Datum:** Ganz oben im Dokument steht oft eine Zeile wie
  `date: {{ site.time | date: "%d-%m-%Y" }}`
  Beim PDF-Export wird dieser Platzhalter automatisch durch das Datum des letzten Commits ersetzt.
- **TOC (Inhaltsverzeichnis):**
  Die Zeile
  ```
  * TOC
  {:toc}
  ```
  erzeugt beim Export ein automatisches Inhaltsverzeichnis an dieser Stelle.
- **HTML-Blöcke:**
  Blöcke wie `<div class="html-only">...</div>` werden beim PDF-Export entfernt und erscheinen nur in der HTML-Version.
- **Templates:**
  Mit `template: btfv` im Front-Matter werden Web- und PDF-Styles aus `templates/btfv` aktiviert.
- **Abschnittsnummerierung:**
  Mit `section_numbering: paragraph` werden Überschriften als §1, §1.1 … nummeriert.
  Mit `section_numbering: arabic` als 1, 1.1 … nummeriert.
- **Alphabetische Listen:**
  Für Listen mit Buchstaben (a, b, c, ...) wird in HTML folgendes verwendet:
  ```html
  <ol type="a">
    <li>Erster Punkt</li>
    <li>Zweiter Punkt</li>
  </ol>
  ```
  Diese Syntax wird beim PDF-Export automatisch in eine passende Darstellung umgewandelt.

---

### Überschriften

```
# Überschrift 1
## Überschrift 2
### Überschrift 3
```

---

### Aufzählungen (Listen)

**Ungeordnete Liste:**
```
- Erster Punkt
- Zweiter Punkt
  - Unterpunkt
```

**Geordnete Liste:**
```
1. Erster Punkt
2. Zweiter Punkt
```

---

### Weitere Tipps

- **Fett:** `**Text**` → **Text**
- **Kursiv:** `_Text_` → _Text_
- **Links:** `[Linktext](URL)`

Eine ausführliche Anleitung: [Markdown Guide](https://www.markdownguide.org/basic-syntax/)

---

## Automatische PDF-Erstellung

Bei jedem Push auf den `main`-Branch wird der [GitHub Actions Workflow](.github/workflows/generate-pdf.yml) ausgeführt:

1. Das Änderungsdatum wird automatisch in die Dokumente eingefügt.
2. Die Markdown-Dateien werden mit Pandoc und LaTeX in PDFs umgewandelt.
3. Die PDFs werden im Ordner [`assets/pdf/`](assets/pdf/) gespeichert und ins Repository zurückgepusht.

**Hinweis:** Für GitHub Actions muss unter `Settings → Actions → General → Workflow permissions` die Einstellung **"Read and write permissions"** aktiviert sein.

---

## Lokale Entwicklung

Alle lokalen Aufgaben werden über `build.sh` gesteuert:

```sh
bash build.sh
```

Das Skript zeigt ein interaktives Menü mit Optionen für PDF-Generierung, Jekyll-Vorschau und Tests.

**Voraussetzungen:** [Pandoc](https://pandoc.org/), [XeLaTeX](https://www.tug.org/xetex/), [Jekyll](https://jekyllrb.com/) (für HTML-Vorschau)

---

## Lizenz

[UNLICENSE](LICENSE) – Public Domain

Bei Fragen oder Verbesserungsvorschlägen bitte ein Issue eröffnen oder einen Pull Request stellen.
