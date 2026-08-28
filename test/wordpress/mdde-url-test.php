<?php
/**
 * Prueft MDDE_URL::build() ohne WordPress. Stubs nur so weit wie noetig.
 *
 * Lauf: php test/wordpress/mdde-url-test.php  (auch ueber scripts/test_pdfs.sh)
 */
define( 'ABSPATH', __DIR__ );

function wp_parse_url( $url, $component = -1 ) {
	return parse_url( $url, $component );
}

function trailingslashit( $s ) {
	return rtrim( $s, '/' ) . '/';
}

function add_query_arg( $args, $url ) {
	$sep   = ( strpos( $url, '?' ) === false ) ? '?' : '&';
	$parts = array();
	foreach ( $args as $k => $v ) {
		$parts[] = $k . '=' . $v;
	}
	return $url . $sep . implode( '&', $parts );
}

function home_url( $path = '' ) {
	return 'http://docs-test.local' . $path;
}

function mdde_option( $key, $default = null ) {
	$o = array(
		'base_url'        => 'http://localhost:4000/',
		'allowed_origins' => array( 'http://localhost:4000/staging/' ),
	);
	return array_key_exists( $key, $o ) ? $o[ $key ] : $default;
}

class MDDE_Manifest {
	public static function find( $slug, $base = '' ) {
		$docs = array(
			'index'           => array( 'slug' => 'index', 'url' => '/', 'title' => 'MD to PDF and Web' ),
			'satzung'         => array( 'slug' => 'satzung', 'url' => '/docs/satzung.html', 'title' => 'Satzung' ),
			'mehrfachmeldung' => array( 'slug' => 'mehrfachmeldung', 'url' => '/docs/mehrfachmeldung.html', 'title' => 'Mehrfachmeldung' ),
			'alt'             => array( 'slug' => 'alt', 'url' => '/staging/docs/alt.html', 'title' => 'Altes Manifest' ),
		);
		return isset( $docs[ $slug ] ) ? $docs[ $slug ] : null;
	}
}

require __DIR__ . '/../../wordpress/md-docs-embed/includes/class-mdde-url.php';

$q      = '?embed=1&chrome=none&nav=pinned&theme=light&host=http%3A%2F%2Fdocs-test.local';
$faelle = array(
	'Startseite ueber Slug'  => array( 'src' => 'index', 'mode' => 'page', 'erwartet' => 'http://localhost:4000/' . $q ),
	'Einzeldokument'         => array( 'src' => 'satzung', 'mode' => 'page', 'erwartet' => 'http://localhost:4000/docs/satzung.html' . $q ),
	'Gesamtes Framework'     => array( 'src' => '', 'mode' => 'site', 'erwartet' => 'http://localhost:4000/' . $q ),
	'Kein Dokument gewaehlt' => array( 'src' => '', 'mode' => 'page', 'erwartet' => '' ),
	'Unbekannter Slug'       => array( 'src' => 'gibtsnicht', 'mode' => 'page', 'erwartet' => 'http://localhost:4000/docs/gibtsnicht.html' . $q ),
	'Fertiger Pfad'          => array( 'src' => 'docs/x.html', 'mode' => 'page', 'erwartet' => 'http://localhost:4000/docs/x.html' . $q ),
	'Fremde Basis-URL'       => array( 'src' => 'satzung', 'mode' => 'page', 'base_url' => 'https://boese.example/', 'erwartet' => 'http://localhost:4000/docs/satzung.html' . $q ),
	// Auslieferung in einem Unterverzeichnis: Der Abschnitt darf nicht doppelt
	// erscheinen, auch wenn ein aelteres Manifest ihn im Pfad mitliefert.
	'Staging: Pfad ohne Praefix' => array( 'src' => 'satzung', 'mode' => 'page', 'base_url' => 'http://localhost:4000/staging/', 'erwartet' => 'http://localhost:4000/staging/docs/satzung.html' . $q ),
	'Staging: Pfad mit Praefix'  => array( 'src' => 'alt', 'mode' => 'page', 'base_url' => 'http://localhost:4000/staging/', 'erwartet' => 'http://localhost:4000/staging/docs/alt.html' . $q ),
	'Staging: Startseite'        => array( 'src' => 'index', 'mode' => 'page', 'base_url' => 'http://localhost:4000/staging/', 'erwartet' => 'http://localhost:4000/staging/' . $q ),
);

$fehler = 0;
foreach ( $faelle as $name => $fall ) {
	$args = array(
		'src'      => $fall['src'],
		'mode'     => $fall['mode'],
		'chrome'   => 'none',
		'nav'      => 'pinned',
		'theme'    => 'light',
		'base_url' => isset( $fall['base_url'] ) ? $fall['base_url'] : '',
	);

	$ist = MDDE_URL::build( $args );
	$ok  = ( $ist === $fall['erwartet'] );
	if ( ! $ok ) {
		$fehler++;
	}

	printf( "%-7s %s\n", $ok ? 'OK' : 'FEHLER', $name );
	if ( ! $ok ) {
		printf( "        erwartet: %s\n        ist:      %s\n", var_export( $fall['erwartet'], true ), var_export( $ist, true ) );
	}
}

echo "---\nFehler: $fehler\n";
exit( $fehler > 0 ? 1 : 0 );
