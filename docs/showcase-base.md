---
title: "Musterordnung"
subtitle: "Base-Template · Keine Nummerierung"
date: "{{ site.time | date: '%d.%m.%Y' }}"
template: base
pdf: /assets/pdf/showcase-base.pdf
---

* TOC
{:toc}

# Allgemeine Bestimmungen

Mein Text :)

Dieses Dokument zeigt das **Base-Template** ohne Abschnittsnummerierung.
Es eignet sich als neutrales Fallback-Design ohne Verbandsbranding.

## Zweck

Dieses Dokument dient als Vorlage und Designreferenz für das Base-Template.
Es enthält typische Inhalte wie Listen, Hervorhebungen und Tabellen.

## Geltungsbereich

Diese Ordnung gilt für alle Mitglieder des Verbands.

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

## Breite Tabelle

Braucht kein Sondermarkup: Ist die Tabelle breiter als der Inhaltsbereich, macht das
Framework sie in der HTML-Ansicht seitlich scrollbar und lässt die erste Spalte stehen.

| Merkmal | Variante A | Variante B | Variante C | Bemerkung |
|---|---|---|---|---|
| **Wertung** | vollständig | anteilig | keine | gilt ab Saisonbeginn |
| **Voraussetzung** | Lizenz erforderlich | Grundlizenz, wird automatisch erteilt | keine Voraussetzung | Nachweis beim Ausrichter |
| **Frist** | spätestens 6 Wochen vorher | spätestens 4 Wochen vorher | keine Frist | Ausschlussfrist |
| **Endrunde** | nach Regelwerk | verpflichtend | nur für die Wertung nötig | ohne Endrunde keine Wertung |

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

Diese Ordnung tritt mit Beschluss des Vorstands in Kraft.
