=== Verbandsdokumente einbetten ===
Contributors: btfv
Tags: embed, dokumente, satzung, iframe
Requires at least: 6.4
Tested up to: 6.7
Requires PHP: 7.4
Stable tag: 1.1.0
License: GPLv2 or later
License URI: https://www.gnu.org/licenses/gpl-2.0.html

Bettet Dokumente aus dem Markdown-Dokumentensystem (z. B. docs.btfv.de) in
WordPress-Seiten ein - einzeln oder als komplettes Framework.

== Beschreibung ==

Das Plugin bindet Dokumente per Iframe ein und führt deren Höhe automatisch nach,
sodass keine zweite Scrollleiste entsteht. Es speichert keine Kopie der Inhalte:
Was im Markdown-Repository steht, erscheint nach dem nächsten Build sofort auch
auf der WordPress-Seite.

Zwei Betriebsarten:

* **Einzelnes Dokument** - fest auf ein Dokument verdrahtet. Kein Zurück-Link,
  weiterführende Links öffnen einen neuen Tab.
* **Gesamtes Framework** - die Startseite des Dokumentensystems mit interner
  Navigation; die Adresszeile der WordPress-Seite wird mitgeführt.

Bereitgestellt werden ein Gutenberg-Block ("Verbandsdokument") und der Shortcode
`[md_docs]`.

= Wichtig zur Auffindbarkeit =

Eingebettete Inhalte stehen in einem Iframe. Suchmaschinen ordnen sie der
Dokumenten-Domain zu, und die WordPress-Suche findet den Dokumenttext nicht. Die
einbettende Seite sollte deshalb einen eigenen Titel und eine kurze Beschreibung
bekommen.

== Installation ==

1. ZIP unter *Plugins → Installieren → Plugin hochladen* einspielen und aktivieren.
2. Unter *Einstellungen → Verbandsdokumente* die Basis-URL eintragen, z. B.
   `https://docs.btfv.de/`.
3. Auf einer Seite den Block "Verbandsdokument" einfügen und ein Dokument wählen.

Die Dokumentenseite muss den Embed-Modus ausliefern (Framework `md-to-web-and-pdf`,
SPEC-007). Fehlt er, erscheint nach zehn Sekunden ein Direktlink statt der
Einbettung.

== Shortcode ==

`[md_docs src="satzung"]`
`[md_docs src="satzung" chrome="minimal" max_height="1200"]`
`[md_docs mode="site" chrome="full"]`

Attribute: `src`, `mode` (page|site), `nav` (pinned|framework), `chrome`
(none|minimal|full), `theme` (light|dark|auto), `min_height`, `max_height`,
`base_url`, `title`, `sync_url` (yes|no).

== Häufige Fragen ==

= Warum ist die Einbettung immer hell, obwohl das Dokumentensystem einen Dunkelmodus hat? =

Weil die meisten Vereinsseiten keinen haben und ein dunkler Kasten auf heller
Seite auffällt. Unter *Einstellungen → Verbandsdokumente* oder pro Block lässt
sich das auf "dunkel" oder "dem Gerät folgen" umstellen.

= Kann ich beliebige Websites einbetten? =

Nein. Nur die eingestellte Basis-URL und ausdrücklich freigegebene Adressen.

== Changelog ==

= 1.1.0 =
* Sprungmarken im Inhaltsverzeichnis funktionieren: Da das eingebettete Dokument
  so hoch ist wie sein Inhalt, hat es keinen eigenen Scrollweg — jetzt scrollt die
  WordPress-Seite zur Überschrift. Bei gesetzter Maximalhöhe scrollt weiterhin das
  Dokument selbst.
* Der Link an einer Überschrift kopiert die Adresse der WordPress-Seite statt der
  des Dokumentenservers.
* Neue Einstellung "Abstand beim Ankersprung" für Themes mit mitlaufender Kopfzeile.

= 1.0.0 =
* Erste Fassung: Block, Shortcode, Einstellungsseite, Höhen-Nachführung,
  Navigationsmodell, Direktlink bei Ladefehler.
