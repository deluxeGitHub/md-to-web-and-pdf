<?php
/**
 * Gemeinsame Ausgabe für Block und Shortcode.
 *
 * @package md-docs-embed
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Erzeugt das Iframe samt Rückfallebene.
 */
class MDDE_Render {

	/**
	 * Laufende Nummer, damit mehrere Einbettungen eigene IDs bekommen.
	 *
	 * @var int
	 */
	private static $instance = 0;

	/**
	 * Attribute auf gültige Werte bringen.
	 *
	 * @param array<string, mixed> $atts Rohe Attribute.
	 * @return array<string, mixed>
	 */
	public static function normalize( array $atts ) {
		$defaults = array(
			'src'        => '',
			'mode'       => 'page',
			'nav'        => '',
			'chrome'     => mdde_option( 'chrome' ),
			'theme'      => mdde_option( 'theme' ),
			'min_height' => mdde_option( 'min_height' ),
			'max_height' => mdde_option( 'max_height' ),
			'base_url'   => '',
			'title'      => '',
			'sync_url'   => '',
		);

		$atts = wp_parse_args( $atts, $defaults );

		$mode = 'site' === $atts['mode'] ? 'site' : 'page';

		$nav = strtolower( (string) $atts['nav'] );
		if ( 'framework' !== $nav && 'pinned' !== $nav ) {
			// Ohne ausdrückliche Angabe: Einzeldokument ist fest verdrahtet.
			$nav = 'site' === $mode ? 'framework' : 'pinned';
		}

		$chrome = strtolower( (string) $atts['chrome'] );
		if ( ! in_array( $chrome, array( 'none', 'minimal', 'full' ), true ) ) {
			$chrome = 'none';
		}

		$theme = strtolower( (string) $atts['theme'] );
		if ( ! in_array( $theme, array( 'light', 'dark', 'auto' ), true ) ) {
			$theme = 'light';
		}

		$min = absint( $atts['min_height'] );
		$max = absint( $atts['max_height'] );
		if ( $min < 100 ) {
			$min = 100;
		}
		if ( 0 !== $max && $max < $min ) {
			$max = $min;
		}

		$sync = strtolower( (string) $atts['sync_url'] );
		if ( 'yes' !== $sync && 'no' !== $sync ) {
			// Pfad-Rückschreibung nur, wo überhaupt navigiert werden kann.
			$sync = 'framework' === $nav ? 'yes' : 'no';
		}

		return array(
			'src'        => sanitize_text_field( (string) $atts['src'] ),
			'mode'       => $mode,
			'nav'        => $nav,
			'chrome'     => $chrome,
			'theme'      => $theme,
			'min_height' => $min,
			'max_height' => $max,
			'base_url'   => esc_url_raw( (string) $atts['base_url'], array( 'http', 'https' ) ),
			'title'      => sanitize_text_field( (string) $atts['title'] ),
			'sync_url'   => $sync,
		);
	}

	/**
	 * Einbettung als HTML.
	 *
	 * @param array<string, mixed> $atts Rohe Attribute.
	 * @return string
	 */
	public static function render( array $atts ) {
		// Eine angegebene, aber nicht freigegebene Basis-URL fuehrt zum Rueckfall auf
		// die eingestellte Quelle. Das darf nicht stumm passieren: Sonst sieht der
		// Redakteur ein funktionierendes Dokument und haelt seine Angabe fuer wirksam.
		$raw_base = isset( $atts['base_url'] ) ? trim( (string) $atts['base_url'] ) : '';
		$hinweis  = '';
		if ( '' !== $raw_base && ! MDDE_URL::is_allowed( $raw_base ) ) {
			$hinweis = self::notice(
				sprintf(
					/* translators: %s: die im Block oder Shortcode angegebene Basis-URL. */
					__( 'Verbandsdokumente: Die angegebene Basis-URL „%s" ist nicht freigegeben — es wird die eingestellte Quelle verwendet. Freigabe unter Einstellungen → Verbandsdokumente. Hinweis: Der Block-Editor verlinkt URLs in Shortcodes automatisch und macht sie damit unbrauchbar; dagegen hilft der Block „Shortcode".', 'md-docs-embed' ),
					$raw_base
				)
			);
		}

		$args = self::normalize( $atts );

		// Tiefer Link: Das Host-Skript schreibt bei Framework-Navigation den Pfad als
		// ?dok= in die Adresszeile. Damit ein geteilter Link auch beim Aufruf dort
		// landet, wird er hier wieder aufgegriffen.
		if ( 'yes' === $args['sync_url'] ) {
			$deep = self::deep_link_path();
			if ( '' !== $deep ) {
				$args['src']  = $deep;
				$args['mode'] = 'page';
			}
		}

		// Zwei verschiedene Fehler, zwei verschiedene Meldungen - sonst schickt die
		// Meldung in die Einstellungen, obwohl dort alles stimmt.
		if ( '' === MDDE_URL::resolve_base( $args['base_url'] ) ) {
			return $hinweis . self::notice(
				__( 'Verbandsdokumente: Es ist keine gültige Quelle eingestellt. Basis-URL unter Einstellungen → Verbandsdokumente eintragen.', 'md-docs-embed' )
			);
		}

		$url = MDDE_URL::build( $args );

		if ( '' === $url ) {
			return $hinweis . self::notice(
				sprintf(
					/* translators: %s: Kennung des Dokuments aus dem Shortcode oder Block. */
					__( 'Verbandsdokumente: Es ist kein Dokument ausgewählt (Kennung: %s).', 'md-docs-embed' ),
					'' === $args['src'] ? '–' : $args['src']
				)
			);
		}

		self::$instance++;
		$id = 'mdde-' . self::$instance . '-' . wp_rand( 1000, 9999 );

		$title = $args['title'];
		if ( '' === $title ) {
			$document = 'site' !== $args['mode'] ? MDDE_Manifest::find( $args['src'], $args['base_url'] ) : null;
			if ( $document && ! empty( $document['title'] ) ) {
				$title = $document['title'];
			} elseif ( 'site' === $args['mode'] ) {
				$title = __( 'Verbandsdokumente', 'md-docs-embed' );
			} else {
				$title = __( 'Verbandsdokument', 'md-docs-embed' );
			}
		}

		self::enqueue_assets();

		// In der Editor-Vorschau (ServerSideRender laeuft ueber die REST-API) ist das
		// Host-Skript nicht geladen. Der Ladezustand bliebe dort stehen, der Redakteur
		// saehe dauerhaft nur Platzhalterzeilen - also von vornherein weglassen.
		$is_preview = defined( 'REST_REQUEST' ) && REST_REQUEST;

		$direct_label = __( 'Dokument in neuem Tab öffnen', 'md-docs-embed' );
		$error_text   = (string) mdde_option( 'error_text' );

		ob_start();
		echo $hinweis; // phpcs:ignore WordPress.Security.EscapeOutput -- in notice() bereits escaped.
		?>
		<div class="mdde-embed<?php echo $is_preview ? '' : ' mdde-embed--loading'; ?>"
			id="<?php echo esc_attr( $id ); ?>"
			data-mdde
			data-origin="<?php echo esc_attr( MDDE_URL::origin( $url ) ); ?>"
			data-min-height="<?php echo esc_attr( (string) $args['min_height'] ); ?>"
			data-max-height="<?php echo esc_attr( (string) $args['max_height'] ); ?>"
			data-scroll-offset="<?php echo esc_attr( (string) (int) mdde_option( 'scroll_offset' ) ); ?>"
			data-sync-url="<?php echo esc_attr( $args['sync_url'] ); ?>">
			<iframe
				class="mdde-embed__frame"
				src="<?php echo esc_url( $url ); ?>"
				title="<?php echo esc_attr( $title ); ?>"
				loading="lazy"
				referrerpolicy="strict-origin-when-cross-origin"
				<?php // Rueckfallebene fuer den Kopier-Link im Dokument (A19); regulaer kopiert das Host-Skript. ?>
				allow="clipboard-write"
				<?php
				// Ohne Deckelung folgt die Hoehe dem Inhalt, im Iframe gibt es also nie
				// etwas zu scrollen. Das Attribut ist zwar veraltet, aber das einzige
				// zuverlaessige Mittel gegen die Scrollleiste des fremden Dokuments -
				// CSS am Iframe-Element wirkt darauf nicht.
				if ( 0 === $args['max_height'] ) {
					echo ' scrolling="no"';
				}
				?>
				style="height: <?php echo esc_attr( (string) $args['min_height'] ); ?>px;"></iframe>

			<p class="mdde-embed__fallback" hidden>
				<?php echo esc_html( $error_text ); ?>
				<a href="<?php echo esc_url( $url ); ?>" target="_blank" rel="noopener"><?php echo esc_html( $direct_label ); ?></a>
			</p>

			<noscript>
				<?php // Ohne JavaScript entfernt niemand den Ladezustand - hier zuruecknehmen. ?>
				<style>#<?php echo esc_html( $id ); ?>.mdde-embed--loading .mdde-embed__frame { opacity: 1; }
					#<?php echo esc_html( $id ); ?>.mdde-embed--loading::before { display: none; }</style>
				<p class="mdde-embed__noscript">
					<a href="<?php echo esc_url( $url ); ?>" target="_blank" rel="noopener"><?php echo esc_html( $direct_label ); ?></a>
				</p>
			</noscript>
		</div>
		<?php
		return (string) ob_get_clean();
	}

	/**
	 * Assets nur laden, wenn tatsächlich eine Einbettung ausgegeben wird.
	 */
	private static function enqueue_assets() {
		if ( wp_script_is( 'mdde-host', 'enqueued' ) ) {
			return;
		}

		wp_enqueue_style( 'mdde-host', MDDE_PLUGIN_URL . 'assets/mdde-host.css', array(), self::asset_version( 'assets/mdde-host.css' ) );
		wp_enqueue_script( 'mdde-host', MDDE_PLUGIN_URL . 'assets/mdde-host.js', array(), self::asset_version( 'assets/mdde-host.js' ), true );
		wp_localize_script(
			'mdde-host',
			'mddeSettings',
			array(
				'allowedOrigins' => MDDE_URL::allowed_origins(),
				'timeout'        => 10000,
			)
		);
	}

	/**
	 * Pfad aus dem Abfrageparameter ?dok=, sofern unbedenklich.
	 *
	 * Die Prüfung selbst liegt in MDDE_URL::safe_relative_path() — dort, wo die
	 * übrige Adressprüfung sitzt und wo der Test sie ohne WordPress erreicht.
	 * Hier bleibt nur das Auslesen des Parameters.
	 *
	 * @return string Relativer Pfad oder leerer String.
	 */
	private static function deep_link_path() {
		// phpcs:ignore WordPress.Security.NonceVerification.Recommended -- Leseparameter ohne Zustandsaenderung.
		$raw = isset( $_GET['dok'] ) ? (string) wp_unslash( $_GET['dok'] ) : '';

		return MDDE_URL::safe_relative_path( $raw );
	}

	/**
	 * Version einer Asset-Datei: Plugin-Version plus Änderungszeitpunkt.
	 *
	 * Ohne den Zeitstempel liefern Browser nach einer Dateiänderung weiter die
	 * zwischengespeicherte Fassung, solange die Plugin-Version gleich bleibt —
	 * beim Entwickeln ist das die Regel, nicht die Ausnahme.
	 *
	 * @param string $relative Pfad innerhalb des Plugins.
	 * @return string
	 */
	private static function asset_version( $relative ) {
		$path = MDDE_PATH . $relative;
		$time = file_exists( $path ) ? filemtime( $path ) : 0;
		return $time ? MDDE_VERSION . '.' . $time : MDDE_VERSION;
	}

	/**
	 * Hinweis, der nur Redakteuren angezeigt wird.
	 *
	 * @param string $message Text.
	 * @return string
	 */
	private static function notice( $message ) {
		if ( ! current_user_can( 'edit_posts' ) ) {
			return '';
		}
		return '<p class="mdde-embed__notice">' . esc_html( $message ) . '</p>';
	}
}
