# Neues Dokument-Repo einrichten

Diese Anleitung erklärt Schritt für Schritt, wie du ein eigenes Repository
für Verbandsdokumente aufsetzt. Das Build-System (PDF-Erstellung, Website)
kommt automatisch aus dem Framework – du musst nur die Markdown-Dateien pflegen.

---

## Was du bekommst

- Automatische PDF-Erstellung bei jedem Push
- Öffentliche Website (GitHub Pages) mit allen Dokumenten
- Keine Installation nötig – alles läuft in der Cloud

---

## Schritt 1: Repository erstellen

1. Gehe auf [github.com](https://github.com) und melde dich an
2. Klicke oben rechts auf **"+"** → **"New repository"**
3. Gib einen Namen ein (z.B. `btfv-docs`)
4. Wähle **"Public"** (für GitHub Pages kostenlos nötig)
5. Klicke **"Create repository"**

---

## Schritt 2: Dateien aus diesem Beispiel-Ordner kopieren

Kopiere folgende Dateien/Ordner in dein neues Repository:

```
_config.yml
.github/
    workflows/
        build.yml
docs/
    beispiel.md       ← als Vorlage, kann umbenannt/gelöscht werden
```

**Wichtig:** Die Ordnerstruktur muss exakt so erhalten bleiben.

---

## Schritt 3: GitHub Pages aktivieren

1. Gehe in deinem Repository auf **Settings** → **Pages**
2. Unter "Source" wähle **"Deploy from a branch"**
3. Branch: **`gh-pages`**, Ordner: **`/ (root)`**
4. Speichern

> Der `gh-pages`-Branch wird automatisch beim ersten Workflow-Run angelegt.
>
> - `main`-Branch → live unter `https://<name>.github.io/<repo>/`
> - `development`-Branch → Vorschau unter `https://<name>.github.io/<repo>/staging/`

---

## Schritt 4: Workflow-Berechtigungen setzen

1. Gehe auf **Settings** → **Actions** → **General**
2. Scrolle zu "Workflow permissions"
3. Wähle **"Read and write permissions"**
4. Klicke **"Save"**

---

## Schritt 5: Ersten Push machen

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
3. Passe `title`, `subtitle` und `pdf` an
4. Schreibe deinen Inhalt darunter
5. Push auf `main` → PDF und Website werden automatisch aktualisiert

### Front Matter (Kopfbereich jeder Datei)

```yaml
---
title: "Spielordnung"           # Titel des Dokuments
subtitle: "des BTFV e.V."      # Untertitel (optional)
date: "{{ site.time | date: '%d.%m.%Y' }}"   # Datum – nicht ändern!
layout: default                 # Immer so lassen
template: btfv                  # btfv, dtfb oder base
section_numbering: paragraph    # paragraph=§1§1.1 / arabic=1/1.1 / weglassen=keine
pdf: /assets/pdf/spielordnung.pdf  # Pfad zur PDF (Name = Dateiname ohne .md)
---
```

### Abschnittsnummerierung

| Wert | Ergebnis |
|---|---|
| `section_numbering: paragraph` | §1, §1.1, §1.1.1 … |
| `section_numbering: arabic` | 1, 1.1, 1.1.1 … |
| *(nicht angegeben)* | Keine Nummerierung |

### Inhaltsverzeichnis

Füge diese zwei Zeilen an die Stelle im Dokument, wo das Inhaltsverzeichnis erscheinen soll:

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

## Häufige Fragen

**Wann wird das PDF aktualisiert?**
Automatisch bei jedem Push auf den `main`-Branch. Unter "Actions" siehst du den Fortschritt.

**Kann ich das Datum manuell setzen?**
Nein – das Datum wird automatisch auf das Datum des letzten Commits gesetzt.

**Wo finde ich die fertige PDF?**
Im Repository unter `assets/pdf/<dateiname>.pdf`, oder als Download-Link auf der Website.

**Was ist der Unterschied zwischen den Templates?**
- `btfv` – BTFV-Design (blau)
- `dtfb` – DTFB-Design (grün)
- `base` – neutrales Design ohne Verbandslogo

**Der Workflow schlägt fehl – was tun?**
Unter **Actions** → letzter Workflow-Run → auf den roten Schritt klicken → Fehlermeldung lesen.
Häufige Ursache: Schreibrechte nicht aktiviert (siehe Schritt 4).
