---
title: "Ausschreibung"
subtitle: "DTFB-Template · Arabische Nummerierung"
date: "{{ site.time | date: '%d.%m.%Y' }}"
template: dtfb
section_numbering: arabic
pdf: /assets/pdf/showcase-dtfb.pdf
---

* TOC
{:toc}

# Allgemeine Bestimmungen

Dieses Dokument zeigt das **DTFB-Template** mit arabischer Nummerierung.
Überschriften werden automatisch als 1, 1.1, 1.1.1 usw. nummeriert.

## Zweck

Dieses Dokument dient als Vorlage und Designreferenz für das DTFB-Template.
Es enthält typische Inhalte wie Listen, Hervorhebungen und Tabellen.

## Geltungsbereich

Diese Ausschreibung gilt für alle Mitglieder des DTFB e.V.

# Textformatierung

Text kann **fett**, *kursiv* oder `inline-code` formatiert werden.

## Geordnete Liste

1. Erster Punkt
1. Zweiter Punkt
1. Dritter Punkt

## Ungeordnete Liste

- Stichpunkt A
- Stichpunkt B
  - Unterpunkt B1
  - Unterpunkt B2
- Stichpunkt C

## Alphabetische Liste

<ol type="a">
  <li>Erster alphabetischer Punkt</li>
  <li>Zweiter alphabetischer Punkt</li>
  <li>Dritter alphabetischer Punkt</li>
</ol>

## Tabelle

| Spalte 1 | Spalte 2 | Spalte 3 |
|---|---|---|
| Wert A | Wert B | Wert C |
| Wert D | Wert E | Wert F |

# Überschrift 1
## Überschrift 2
### Überschrift 3

**Fetter Text**  
*Kursiver Text*  
***Fett und kursiv***  
~~Durchgestrichener Text~~  
`Inline-Code`

> Das ist ein Blockzitat.
>> Und hier ein verschachteltes Zitat.

---

### Liste
- Erster Punkt
- Zweiter Punkt
  - Unterpunkt
  - Noch ein Unterpunkt

### Nummerierte Liste
1. Erster Schritt
2. Zweiter Schritt
3. Dritter Schritt

### Aufgabenliste
- [x] Erledigt
- [ ] Offen

### Link und Bild
[OpenAI](https://openai.com)


### Codeblock
```php
function hallo($name) {
    return "Hallo, " . $name . "!";
}
echo hallo("Sam");

# Bilder

Ein Bild, das allein in einem Absatz steht, wird im PDF zu einer Abbildung mit
Bildunterschrift aus dem Alt-Text. Es wird proportional auf die Textbreite skaliert.

![Beispielbild mit Raster und Eckmarken](images/beispielbild.png)

## Bild in einer Aufzählung

Bilder bleiben im PDF an ihrer Textstelle. Ohne diese Festlegung schiebt LaTeX sie
aus der Liste heraus hinter die folgenden Absätze.

1. Erster Schritt vor dem Bild.
1. Zweiter Schritt, zu dem das Bild gehört:

   ![Beispielbild im Listenpunkt](images/beispielbild.png)
1. Dritter Schritt nach dem Bild.

Dieser Absatz steht in der Quelle **nach** dem Bild und muss im PDF ebenfalls
dahinter stehen.

Ein zweiter Absatz, damit genug Text vorhanden ist, um eine falsche Platzierung
sichtbar zu machen.

# Schlussbestimmungen

Diese Ausschreibung tritt mit Veröffentlichung in Kraft.
