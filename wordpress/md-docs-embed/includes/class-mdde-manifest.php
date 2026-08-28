<?php
/**
 * Dokument-Manifest (docs.json) der Docs-Instanz.
 *
 * @package md-docs-embed
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Holt und cached /docs.json. Das Manifest füllt die Auswahlliste im Editor und
 * löst Slugs auf Pfade auf.
 */
class MDDE_Manifest {

	const TRANSIENT_PREFIX = 'mdde_manifest_';
	const TTL              = HOUR_IN_SECONDS;

	/**
	 * Dokumente der Instanz.
	 *
	 * @param string $base_url Basis-URL; leer = Einstellung.
	 * @param bool   $force    Cache umgehen.
	 * @return array<int, array<string, mixed>>
	 */
	public static function documents( $base_url = '', $force = false ) {
		$base = MDDE_URL::resolve_base( $base_url );
		if ( '' === $base ) {
			return array();
		}

		$key = self::TRANSIENT_PREFIX . md5( $base );

		if ( ! $force ) {
			$cached = get_transient( $key );
			if ( is_array( $cached ) ) {
				return $cached;
			}
		}

		$documents = self::fetch( $base );

		// Auch ein leeres Ergebnis wird kurz gecached, damit eine nicht erreichbare
		// Instanz nicht bei jedem Seitenaufruf erneut angefragt wird.
		set_transient( $key, $documents, empty( $documents ) ? 5 * MINUTE_IN_SECONDS : self::TTL );

		return $documents;
	}

	/**
	 * Ein Dokument anhand seines Slugs.
	 *
	 * @param string $slug     Slug.
	 * @param string $base_url Basis-URL.
	 * @return array<string, mixed>|null
	 */
	public static function find( $slug, $base_url = '' ) {
		foreach ( self::documents( $base_url ) as $document ) {
			if ( isset( $document['slug'] ) && $document['slug'] === $slug ) {
				return $document;
			}
		}
		return null;
	}

	/**
	 * Manifest abrufen und normalisieren.
	 *
	 * @param string $base Basis-URL mit abschliessendem Schrägstrich.
	 * @return array<int, array<string, mixed>>
	 */
	private static function fetch( $base ) {
		$url = $base . 'docs.json';

		if ( ! MDDE_URL::is_allowed( $url ) ) {
			return array();
		}

		$response = wp_remote_get(
			$url,
			array(
				'timeout'     => 10,
				'redirection' => 2,
				'headers'     => array( 'Accept' => 'application/json' ),
			)
		);

		if ( is_wp_error( $response ) || 200 !== (int) wp_remote_retrieve_response_code( $response ) ) {
			return array();
		}

		$data = json_decode( wp_remote_retrieve_body( $response ), true );
		if ( ! is_array( $data ) || empty( $data['documents'] ) || ! is_array( $data['documents'] ) ) {
			return array();
		}

		$documents = array();
		foreach ( $data['documents'] as $entry ) {
			if ( ! is_array( $entry ) || empty( $entry['slug'] ) ) {
				continue;
			}
			$documents[] = array(
				'slug'     => sanitize_key( $entry['slug'] ),
				'title'    => isset( $entry['title'] ) ? sanitize_text_field( (string) $entry['title'] ) : '',
				'subtitle' => isset( $entry['subtitle'] ) ? sanitize_text_field( (string) $entry['subtitle'] ) : '',
				'url'      => isset( $entry['url'] ) ? esc_url_raw( (string) $entry['url'], array( 'http', 'https' ) ) : '',
				'pdf'      => isset( $entry['pdf'] ) ? esc_url_raw( (string) $entry['pdf'], array( 'http', 'https' ) ) : '',
				'template' => isset( $entry['template'] ) ? sanitize_key( $entry['template'] ) : '',
				'home'     => ! empty( $entry['home'] ),
			);
		}

		return $documents;
	}

	/**
	 * Alle zwischengespeicherten Manifeste verwerfen.
	 */
	public static function flush_cache() {
		global $wpdb;

		$like = $wpdb->esc_like( '_transient_' . self::TRANSIENT_PREFIX ) . '%';
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery -- gezieltes Aufräumen der eigenen Transients.
		$names = $wpdb->get_col( $wpdb->prepare( "SELECT option_name FROM {$wpdb->options} WHERE option_name LIKE %s", $like ) );

		foreach ( (array) $names as $name ) {
			delete_transient( str_replace( '_transient_', '', $name ) );
		}
	}
}
