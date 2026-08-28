<?php
/**
 * URL-Bau und Origin-Prüfung.
 *
 * @package md-docs-embed
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Baut Iframe-URLs und entscheidet, welche Quellen überhaupt erlaubt sind.
 */
class MDDE_URL {

	/**
	 * Origin einer URL ("https://host[:port]"), oder leer bei ungültiger URL.
	 *
	 * @param string $url URL.
	 * @return string
	 */
	public static function origin( $url ) {
		$parts = wp_parse_url( (string) $url );
		if ( empty( $parts['scheme'] ) || empty( $parts['host'] ) ) {
			return '';
		}
		$origin = $parts['scheme'] . '://' . $parts['host'];
		if ( ! empty( $parts['port'] ) ) {
			$origin .= ':' . $parts['port'];
		}
		return $origin;
	}

	/**
	 * Alle erlaubten Origins: die der Basis-URL plus ausdrücklich freigegebene.
	 *
	 * @return string[]
	 */
	public static function allowed_origins() {
		$origins = array();

		$base = self::origin( mdde_option( 'base_url' ) );
		if ( '' !== $base ) {
			$origins[] = $base;
		}

		$extra = mdde_option( 'allowed_origins' );
		if ( is_array( $extra ) ) {
			foreach ( $extra as $candidate ) {
				$origin = self::origin( $candidate );
				if ( '' !== $origin ) {
					$origins[] = $origin;
				}
			}
		}

		return array_values( array_unique( $origins ) );
	}

	/**
	 * Ist die URL von einer erlaubten Origin?
	 *
	 * @param string $url URL.
	 * @return bool
	 */
	public static function is_allowed( $url ) {
		$origin = self::origin( $url );
		return '' !== $origin && in_array( $origin, self::allowed_origins(), true );
	}

	/**
	 * Basis-URL für eine Einbettung: das Attribut, sonst die Einstellung.
	 * Eine nicht freigegebene Basis-URL fällt auf die Einstellung zurück.
	 *
	 * @param string $candidate Basis-URL aus dem Block/Shortcode.
	 * @return string Basis-URL mit abschliessendem Schrägstrich, oder leer.
	 */
	public static function resolve_base( $candidate = '' ) {
		$candidate = trim( (string) $candidate );

		if ( '' !== $candidate && self::is_allowed( $candidate ) ) {
			return trailingslashit( $candidate );
		}

		$base = trim( (string) mdde_option( 'base_url' ) );
		return '' === $base ? '' : trailingslashit( $base );
	}

	/**
	 * Pfad eines Dokuments innerhalb der Docs-Instanz ermitteln.
	 *
	 * Reihenfolge: fertiger Pfad im Attribut → Treffer im Manifest → Konvention
	 * "docs/<slug>.html".
	 *
	 * Der leere String ist ein gültiges Ergebnis: die Startseite des Frameworks
	 * liegt auf der Basis-URL selbst. "Nicht auflösbar" ist deshalb `null` und
	 * nicht "".
	 *
	 * @param string $src      Slug oder Pfad.
	 * @param string $base_url Basis-URL.
	 * @return string|null Relativer Pfad ohne führenden Schrägstrich, oder null.
	 */
	public static function resolve_path( $src, $base_url ) {
		$src = trim( (string) $src );
		$src = ltrim( $src, '/' );

		if ( '' === $src ) {
			return null;
		}

		// Bereits ein Pfad? Dann unverändert übernehmen.
		if ( false !== strpos( $src, '/' ) || substr( $src, -5 ) === '.html' ) {
			return $src;
		}

		$document = MDDE_Manifest::find( $src, $base_url );
		if ( $document ) {
			// Die Startseite hat die URL "/" und damit einen leeren Pfad.
			$path = ltrim( (string) ( isset( $document['url'] ) ? $document['url'] : '' ), '/' );
			return self::strip_base_path( $path, $base_url );
		}

		return 'docs/' . $src . '.html';
	}

	/**
	 * Einen im Pfad bereits enthaltenen Basis-Abschnitt entfernen.
	 *
	 * Liegt die Auslieferung in einem Unterverzeichnis (z. B. /staging/), enthalten
	 * die Pfade eines aelteren Manifests dieses Verzeichnis mit. Zusammen mit einer
	 * Basis-URL, die ohnehin dorthin zeigt, ergaebe das den Abschnitt doppelt.
	 * Neuere Manifeste liefern die Pfade ohne — dann tut diese Methode nichts.
	 *
	 * @param string $path     Pfad ohne führenden Schrägstrich.
	 * @param string $base_url Basis-URL.
	 * @return string
	 */
	private static function strip_base_path( $path, $base_url ) {
		$base_path = (string) wp_parse_url( $base_url, PHP_URL_PATH );
		$base_path = trim( $base_path, '/' );

		if ( '' === $base_path ) {
			return $path;
		}
		if ( $path === $base_path ) {
			return '';
		}
		if ( 0 === strpos( $path, $base_path . '/' ) ) {
			return ltrim( substr( $path, strlen( $base_path ) ), '/' );
		}

		return $path;
	}

	/**
	 * Einen von aussen kommenden Pfad annehmen oder verwerfen.
	 *
	 * Bewusst eine Positivliste: Der Wert stammt aus einer URL, die jeder
	 * erzeugen kann. Absolute URLs, protokoll-relative Adressen und
	 * Verzeichniswechsel werden verworfen, damit die Einbettung nicht auf ein
	 * fremdes Ziel umgelenkt werden kann.
	 *
	 * Liegt hier und nicht in MDDE_Render, weil Pfad- und Adressprüfung
	 * inhaltlich hierher gehört und diese Klasse ohne WordPress ladbar ist —
	 * der Test in test/wordpress/ prüft damit die Logik des Plugins selbst und
	 * keine Kopie davon.
	 *
	 * @param string $raw Roher Pfad, etwa aus einem Abfrageparameter.
	 * @return string Relativer Pfad ohne führenden Schrägstrich, oder leerer String.
	 */
	public static function safe_relative_path( $raw ) {
		$raw = (string) $raw;

		// Vor dem Abschneiden prüfen: "//host/pfad" wäre nach dem ltrim nicht
		// mehr als protokoll-relative Adresse erkennbar.
		if ( 0 === strpos( $raw, '//' ) ) {
			return '';
		}
		if ( false !== strpos( $raw, '://' ) || false !== strpos( $raw, '..' ) ) {
			return '';
		}

		$raw = ltrim( $raw, '/' );

		if ( '' === $raw ) {
			return '';
		}
		if ( ! preg_match( '#^[A-Za-z0-9._/-]+$#', $raw ) ) {
			return '';
		}

		return $raw;
	}

	/**
	 * Vollständige Iframe-URL bauen.
	 *
	 * @param array<string, mixed> $args Aufbereitete Attribute.
	 * @return string Leerer String, wenn Basis oder Dokument fehlen.
	 */
	public static function build( array $args ) {
		$base = self::resolve_base( isset( $args['base_url'] ) ? $args['base_url'] : '' );
		if ( '' === $base ) {
			return '';
		}

		$path = '';
		if ( 'site' !== $args['mode'] ) {
			$path = self::resolve_path( isset( $args['src'] ) ? $args['src'] : '', $base );
			if ( null === $path ) {
				return '';
			}
		}

		$url = $base . $path;

		$query = array(
			'embed'  => '1',
			'chrome' => $args['chrome'],
			'nav'    => $args['nav'],
			'theme'  => $args['theme'],
			// Ziel fuer postMessage ausdruecklich mitgeben. Die Bruecke koennte es
			// aus document.referrer ableiten - aber nur beim ersten Laden: Nach einer
			// Navigation im Rahmen ist der Referrer die vorige Dokumentseite, und die
			// Nachrichten gingen an die falsche Adresse.
			'host'   => self::origin( home_url() ),
		);

		return add_query_arg( array_map( 'rawurlencode', $query ), $url );
	}
}
