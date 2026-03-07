---
title: "Testdokument Base"
subtitle: "Design-Referenz für das Base-Template"
date: "{{ site.time | date: '%d.%m.%Y' }}"
layout: default
template: base

pdf: /assets/pdf/test-base.pdf
---

* TOC
{:toc}

# Allgemeine Bestimmungen

Dieser Abschnitt prüft die grundlegende §-Nummerierung mit dem Base-Template.
Der Abschnitts-Header soll blau/orange erscheinen (je nach Template-Farbe) und
das Logo oben rechts sichtbar sein.

## Zweck des Dokuments

1. Dieses Dokument dient als Referenz-PDF für automatisierte Tests.
1. Es prüft Schriftart, Farben, Logo, Datum und §-Nummerierung.
1. Das Datum in der Fußzeile soll automatisch aufgelöst werden.

## Geltungsbereich

1. Das Dokument gilt für alle Build-Umgebungen (lokal und CI).
1. Es soll auf macOS und Ubuntu identische Ausgaben erzeugen.

# Textformatierung und Listen

## Geordnete Listen

Normale nummerierte Liste:

1. Erster Punkt
1. Zweiter Punkt
1. Dritter Punkt

## Alphabetische Listen

<ol type="a">
  <li>Erster alphabetischer Punkt</li>
  <li>Zweiter alphabetischer Punkt</li>
  <li>Dritter alphabetischer Punkt</li>
</ol>

## Ungeordnete Liste

- Stichpunkt A
- Stichpunkt B
  - Unterpunkt B1
  - Unterpunkt B2
- Stichpunkt C

# Sonderzeichen und Typografie

## Umlaute

Dieser Abschnitt enthält deutsche Umlaute: ä, ö, ü, Ä, Ö, Ü, ß.

## Hervorhebungen

Text kann **fett**, *kursiv* oder `inline-code` formatiert werden.

## Fußzeile und Datum

<div class="html-only">
Dieser Block ist nur in der HTML-Version sichtbar, nicht im PDF.
</div>

Das Datum in der PDF-Fußzeile soll dem Ausstellungsdatum entsprechen.

# Abschlussbestimmungen

1. Dieses Testdokument wird bei jedem Build neu generiert.
1. Abweichungen vom Referenz-PDF weisen auf Regressionen hin.
