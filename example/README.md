# Neues Dokument-Repo einrichten

Diese Anleitung erklärt Schritt für Schritt, wie du ein eigenes Repository
für Verbandsdokumente aufsetzt. Das Build-System (PDF-Erstellung, Website)
kommt automatisch aus dem Framework – du musst nur die Markdown-Dateien pflegen.

---

## Was du bekommst

- Automatische PDF-Erstellung bei jedem Push
- Öffentliche Website (GitHub Pages) mit allen Dokumenten
- Staging-Vorschau für jeden Branch unter `/staging/`
- Keine Installation nötig – alles läuft in der Cloud

---

## Schritt 1: Repository erstellen

1. Gehe auf [github.com](https://github.com) und melde dich an
2. Klicke oben rechts auf **"+"** → **"New repository"**
3. Gib einen Namen ein (z.B. `meinverein-docs`)
4. Wähle **"Public"** (für GitHub Pages kostenlos nötig)
5. Klicke **"Create repository"**

---

## Schritt 2: Dateien aus diesem Beispiel-Ordner kopieren

Kopiere folgende Dateien/Ordner in dein neues Repository:

```
_config.yml
index.md
.github/
    workflows/
        build.yml
docs/
    beispiel.md           ← als Vorlage, kann umbenannt/gelöscht werden
    vereinsordnung.md     ← Beispiel für ein Custom Theme
templates/
    meinverein/           ← Beispiel-Custom-Theme, kann umbenannt/angepasst werden
```

**Wichtig:** Die Ordnerstruktur muss exakt so erhalten bleiben.

---

## Schritt 3: `build.yml` anpassen

Öffne `.github/workflows/build.yml` und trage die `baseurl` deines Repos ein:

```yaml
with:
  source_dir: docs
  baseurl: /meinverein-docs   # ← Name deines GitHub-Repos
```

---

## Schritt 4: GitHub Pages aktivieren

1. Gehe in deinem Repository auf **Settings** → **Pages**
2. Unter "Source" wähle **"Deploy from a branch"**
3. Branch: **`gh-pages`**, Ordner: **`/ (root)`**
4. Speichern

> Der `gh-pages`-Branch wird automatisch beim ersten Workflow-Run angelegt.
>
> - `main`-Branch → live unter `https://<name>.github.io/<repo>/`
> - Alle anderen Branches → Vorschau unter `https://<name>.github.io/<repo>/staging/`

---

## Schritt 5: Workflow-Berechtigungen setzen

1. Gehe auf **Settings** → **Actions** → **General**
2. Scrolle zu "Workflow permissions"
3. Wähle **"Read and write permissions"**
4. Klicke **"Save"**

---

## Schritt 6: Ersten Push machen

Sobald du Dateien gepusht hast, startet der Workflow automatisch.
Du siehst den Fortschritt unter **Actions** in deinem Repository.

Nach ca. 5 Minuten:
- Die Website ist unter `https://<dein-name>.github.io/<repo-name>/` erreichbar
- PDFs liegen unter `assets/pdf/` im Repository

---

## Dokumente anlegen und bearbeiten

### Neue Datei anlegen

1. Erstelle eine neue `.md`-Datei im Ordner `docs/`
2. Kopiere den Front-Matter-Block aus `docs/beispiel.md` an den Anfang
3. Passe `title`, `subtitle`, `template` und `pdf` an
4. Schreibe deinen Inhalt darunter
5. Push → PDF und Website werden automatisch aktualisiert

### Front Matter (Kopfbereich jeder Datei)

```yaml
---
title: "Spielordnung"           # Titel des Dokuments
subtitle: "des BTFV e.V."      # Untertitel (optional)
date: "{{ site.time | date: '%d.%m.%Y' }}"   # Datum – nicht ändern!
# template: dtfb                # nur setzen, wenn vom Default in _config.yml abweichend
section_numbering: paragraph    # paragraph=§1/§1.1 | arabic=1/1.1 | weglassen=keine
pdf: /assets/pdf/spielordnung.pdf  # Pfad zur PDF (Name = Dateiname ohne .md)
---
```

### Abschnittsnummerierung

| Wert | Ergebnis |
|---|---|
| `section_numbering: paragraph` | § 1, § 1.1, § 1.1.1 … |
| `section_numbering: arabic` | 1, 1.1, 1.1.1 … |
| *(nicht angegeben)* | Keine Nummerierung |

### Inhaltsverzeichnis

```
* TOC
{:toc}
```

### Nur-HTML-Inhalte (erscheinen nicht im PDF)

```html
<div class="html-only">
  Dieser Text erscheint nur auf der Website, nicht im PDF.
</div>
```

### Alphabetische Listen

```html
<ol type="a">
  <li>Erster Punkt</li>
  <li>Zweiter Punkt</li>
</ol>
```

---

## Eigenes Theme erstellen

Du kannst ein vollständig eigenes Design definieren, ohne das Framework zu verändern.

### Benötigte Dateien

Lege folgende Dateien im Docs-Repo an:

```
templates/
└── meinverein/
    ├── web.css              ← CSS-Variablen (Farben, Fonts)
    ├── pdf-header.tex       ← LaTeX-Header für PDFs
    └── images/
        ├── logo.png         ← Logo (mind. 400×120 px, PNG mit Transparenz)
        └── favicon.png      ← Favicon (32×32 px)
```

### Registrierung in `_config.yml`

```yaml
custom_templates:
  - meinverein
```

### Verwendung im Dokument

```yaml
---
template: meinverein
---
```

### Bestehendes Theme überschreiben

Du kannst auch einzelne Dateien eines eingebauten Themes überschreiben.
Lege dazu die Datei am gleichen Pfad im Docs-Repo ab – sie hat Vorrang vor der Framework-Version:

```
templates/btfv/web.css        ← überschreibt das btfv-CSS
templates/btfv/pdf-header.tex ← überschreibt den PDF-Header
```

---

## Häufige Fragen

**Wann wird das PDF aktualisiert?**
Automatisch bei jedem Push. Unter "Actions" siehst du den Fortschritt.

**Kann ich das Datum manuell setzen?**
Nein – das Datum wird automatisch auf das Datum des letzten Commits gesetzt.

**Wo finde ich die fertige PDF?**
Im Repository unter `assets/pdf/<dateiname>.pdf`, oder als Download-Link auf der Website.

**Was ist der Unterschied zwischen den eingebauten Templates?**
- `btfv` – BTFV-Design (blau)
- `dtfb` – DTFB-Design (grün)
- `base` – neutrales Design ohne Verbandslogo

**Der Workflow schlägt fehl – was tun?**
Unter **Actions** → letzter Workflow-Run → auf den roten Schritt klicken → Fehlermeldung lesen.
Häufige Ursache: Schreibrechte nicht aktiviert (siehe Schritt 5).
