<?php
/**
 * Prueft die Positivliste fuer von aussen kommende Pfade ohne WordPress.
 *
 * Geprueft wird MDDE_URL::safe_relative_path() im Plugin selbst — keine Kopie
 * der Logik im Test. MDDE_Render::deep_link_path() liest nur noch $_GET['dok']
 * aus und reicht den Wert hierher durch.
 *
 * Lauf: php test/wordpress/mdde-deeplink-test.php  (auch ueber scripts/test_pdfs.sh)
 */
define( 'ABSPATH', __DIR__ );

require __DIR__ . '/../../wordpress/md-docs-embed/includes/class-mdde-url.php';

$faelle = array(
	'docs/satzung.html'                  => 'docs/satzung.html',
	'/docs/satzung.html'                 => 'docs/satzung.html',
	''                                   => '',
	'https://boese.example/x.html'       => '',
	'//boese.example/x.html'             => '',
	'../../wp-config.php'                => '',
	'docs/../../etc/passwd'              => '',
	'docs/satzung.html?x=1'              => '',
	'docs/satzung.html"onload=alert(1)'  => '',
	'javascript:alert(1)'                => '',
	'docs/mehrfachmeldung.html'          => 'docs/mehrfachmeldung.html',
);

$fehler = 0;
foreach ( $faelle as $eingabe => $erwartet ) {
	$ist = MDDE_URL::safe_relative_path( $eingabe );
	$ok  = ( $ist === $erwartet );
	if ( ! $ok ) {
		$fehler++;
	}
	printf( "%-7s %-36s -> %s\n", $ok ? 'OK' : 'FEHLER', "'" . $eingabe . "'", "'" . $ist . "'" );
}

echo "---\nFehler: $fehler\n";
exit( $fehler > 0 ? 1 : 0 );
