<?php
/**
 * Einstellungsseite.
 *
 * @package md-docs-embed
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Einstellungen → Verbandsdokumente.
 */
class MDDE_Settings {

	const PAGE  = 'md-docs-embed';
	const GROUP = 'mdde_settings';

	/**
	 * Hooks registrieren.
	 */
	public static function init() {
		add_action( 'admin_menu', array( __CLASS__, 'add_page' ) );
		add_action( 'admin_init', array( __CLASS__, 'register' ) );
		add_action( 'admin_post_mdde_flush', array( __CLASS__, 'handle_flush' ) );
		add_filter( 'plugin_action_links_' . plugin_basename( MDDE_FILE ), array( __CLASS__, 'action_link' ) );
	}

	/**
	 * Direktlink in der Plugin-Liste.
	 *
	 * @param string[] $links Vorhandene Links.
	 * @return string[]
	 */
	public static function action_link( $links ) {
		$url = admin_url( 'options-general.php?page=' . self::PAGE );
		array_unshift( $links, '<a href="' . esc_url( $url ) . '">' . esc_html__( 'Einstellungen', 'md-docs-embed' ) . '</a>' );
		return $links;
	}

	/**
	 * Menüeintrag.
	 */
	public static function add_page() {
		add_options_page(
			__( 'Verbandsdokumente', 'md-docs-embed' ),
			__( 'Verbandsdokumente', 'md-docs-embed' ),
			'manage_options',
			self::PAGE,
			array( __CLASS__, 'render_page' )
		);
	}

	/**
	 * Option registrieren.
	 */
	public static function register() {
		register_setting(
			self::GROUP,
			MDDE_OPTION,
			array(
				'type'              => 'array',
				'sanitize_callback' => array( __CLASS__, 'sanitize' ),
				'default'           => mdde_default_options(),
			)
		);
	}

	/**
	 * Eingaben prüfen.
	 *
	 * @param mixed $input Rohdaten aus dem Formular.
	 * @return array<string, mixed>
	 */
	public static function sanitize( $input ) {
		$defaults = mdde_default_options();
		$input    = is_array( $input ) ? $input : array();
		$clean    = array();

		$base = isset( $input['base_url'] ) ? esc_url_raw( trim( (string) $input['base_url'] ), array( 'http', 'https' ) ) : '';
		$clean['base_url'] = '' === $base ? '' : trailingslashit( $base );

		$origins = array();
		if ( ! empty( $input['allowed_origins'] ) ) {
			foreach ( preg_split( '/\r\n|\r|\n/', (string) $input['allowed_origins'] ) as $line ) {
				$line = trim( $line );
				if ( '' === $line ) {
					continue;
				}
				$url = esc_url_raw( $line, array( 'http', 'https' ) );
				if ( '' !== $url ) {
					$origins[] = $url;
				}
			}
		}
		$clean['allowed_origins'] = array_values( array_unique( $origins ) );

		$chrome = isset( $input['chrome'] ) ? (string) $input['chrome'] : '';
		$clean['chrome'] = in_array( $chrome, array( 'none', 'minimal', 'full' ), true ) ? $chrome : $defaults['chrome'];

		$theme = isset( $input['theme'] ) ? (string) $input['theme'] : '';
		$clean['theme'] = in_array( $theme, array( 'light', 'dark', 'auto' ), true ) ? $theme : $defaults['theme'];

		$min = isset( $input['min_height'] ) ? absint( $input['min_height'] ) : $defaults['min_height'];
		$clean['min_height'] = $min < 100 ? 100 : $min;

		$max = isset( $input['max_height'] ) ? absint( $input['max_height'] ) : 0;
		if ( 0 !== $max && $max < $clean['min_height'] ) {
			$max = $clean['min_height'];
		}
		$clean['max_height'] = $max;

		$offset = isset( $input['scroll_offset'] ) ? absint( $input['scroll_offset'] ) : 0;
		$clean['scroll_offset'] = $offset > 400 ? 400 : $offset;

		$text = isset( $input['error_text'] ) ? sanitize_text_field( (string) $input['error_text'] ) : '';
		$clean['error_text'] = '' === $text ? $defaults['error_text'] : $text;

		// Quelle geändert? Dann darf das alte Manifest nicht weiterleben.
		MDDE_Manifest::flush_cache();

		return $clean;
	}

	/**
	 * Manifest-Cache leeren.
	 */
	public static function handle_flush() {
		if ( ! current_user_can( 'manage_options' ) ) {
			wp_die( esc_html__( 'Keine Berechtigung.', 'md-docs-embed' ) );
		}
		check_admin_referer( 'mdde_flush' );

		MDDE_Manifest::flush_cache();

		wp_safe_redirect( add_query_arg( 'mdde-flushed', '1', admin_url( 'options-general.php?page=' . self::PAGE ) ) );
		exit;
	}

	/**
	 * Seite ausgeben.
	 */
	public static function render_page() {
		if ( ! current_user_can( 'manage_options' ) ) {
			return;
		}

		$options   = mdde_options();
		$documents = MDDE_Manifest::documents();
		$flushed   = isset( $_GET['mdde-flushed'] ); // phpcs:ignore WordPress.Security.NonceVerification.Recommended -- nur Anzeige.
		?>
		<div class="wrap">
			<h1><?php esc_html_e( 'Verbandsdokumente', 'md-docs-embed' ); ?></h1>

			<?php if ( $flushed ) : ?>
				<div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'Dokumentenliste neu geladen.', 'md-docs-embed' ); ?></p></div>
			<?php endif; ?>

			<form method="post" action="options.php">
				<?php settings_fields( self::GROUP ); ?>
				<table class="form-table" role="presentation">
					<tr>
						<th scope="row"><label for="mdde-base-url"><?php esc_html_e( 'Basis-URL der Dokumente', 'md-docs-embed' ); ?></label></th>
						<td>
							<input type="url" class="regular-text code" id="mdde-base-url"
								name="<?php echo esc_attr( MDDE_OPTION ); ?>[base_url]"
								value="<?php echo esc_attr( $options['base_url'] ); ?>"
								placeholder="https://docs.btfv.de/">
							<p class="description"><?php esc_html_e( 'Adresse der Dokumenten-Website. Für einen Test der Vorschau-Version: https://docs.btfv.de/staging/', 'md-docs-embed' ); ?></p>
						</td>
					</tr>
					<tr>
						<th scope="row"><label for="mdde-origins"><?php esc_html_e( 'Weitere erlaubte Quellen', 'md-docs-embed' ); ?></label></th>
						<td>
							<textarea id="mdde-origins" class="large-text code" rows="3"
								name="<?php echo esc_attr( MDDE_OPTION ); ?>[allowed_origins]"><?php echo esc_textarea( implode( "\n", (array) $options['allowed_origins'] ) ); ?></textarea>
							<p class="description"><?php esc_html_e( 'Eine URL pro Zeile. Nur Dokumente von diesen Adressen dürfen eingebettet werden.', 'md-docs-embed' ); ?></p>
						</td>
					</tr>
					<tr>
						<th scope="row"><?php esc_html_e( 'Standard-Kopfbereich', 'md-docs-embed' ); ?></th>
						<td>
							<?php
							$chrome_labels = array(
								'none'    => __( 'Nur der Dokumentinhalt', 'md-docs-embed' ),
								'minimal' => __( 'Mit Titel und PDF-Link', 'md-docs-embed' ),
								'full'    => __( 'Vollständig, mit Suche und Einstellungen', 'md-docs-embed' ),
							);
							foreach ( $chrome_labels as $value => $label ) :
								?>
								<label style="display:block;margin-bottom:4px;">
									<input type="radio" name="<?php echo esc_attr( MDDE_OPTION ); ?>[chrome]"
										value="<?php echo esc_attr( $value ); ?>"
										<?php checked( $options['chrome'], $value ); ?>>
									<?php echo esc_html( $label ); ?>
								</label>
							<?php endforeach; ?>
						</td>
					</tr>
					<tr>
						<th scope="row"><label for="mdde-theme"><?php esc_html_e( 'Farbschema', 'md-docs-embed' ); ?></label></th>
						<td>
							<select id="mdde-theme" name="<?php echo esc_attr( MDDE_OPTION ); ?>[theme]">
								<option value="light" <?php selected( $options['theme'], 'light' ); ?>><?php esc_html_e( 'Immer hell', 'md-docs-embed' ); ?></option>
								<option value="dark" <?php selected( $options['theme'], 'dark' ); ?>><?php esc_html_e( 'Immer dunkel', 'md-docs-embed' ); ?></option>
								<option value="auto" <?php selected( $options['theme'], 'auto' ); ?>><?php esc_html_e( 'Dem Gerät des Besuchers folgen', 'md-docs-embed' ); ?></option>
							</select>
							<p class="description"><?php esc_html_e( 'Hat die Website keinen Dunkelmodus, sollte die Einbettung hell bleiben.', 'md-docs-embed' ); ?></p>
						</td>
					</tr>
					<tr>
						<th scope="row"><?php esc_html_e( 'Höhe', 'md-docs-embed' ); ?></th>
						<td>
							<label for="mdde-min"><?php esc_html_e( 'Mindesthöhe', 'md-docs-embed' ); ?></label>
							<input type="number" id="mdde-min" min="100" step="10" class="small-text"
								name="<?php echo esc_attr( MDDE_OPTION ); ?>[min_height]"
								value="<?php echo esc_attr( (string) $options['min_height'] ); ?>"> px
							&nbsp;
							<label for="mdde-max"><?php esc_html_e( 'Maximalhöhe', 'md-docs-embed' ); ?></label>
							<input type="number" id="mdde-max" min="0" step="10" class="small-text"
								name="<?php echo esc_attr( MDDE_OPTION ); ?>[max_height]"
								value="<?php echo esc_attr( (string) $options['max_height'] ); ?>"> px
							<p class="description"><?php esc_html_e( 'Maximalhöhe 0 bedeutet: unbegrenzt, das Dokument wird vollständig ausgeklappt.', 'md-docs-embed' ); ?></p>
						</td>
					</tr>
					<tr>
						<th scope="row"><label for="mdde-scroll-offset"><?php esc_html_e( 'Abstand beim Ankersprung', 'md-docs-embed' ); ?></label></th>
						<td>
							<input type="number" id="mdde-scroll-offset" min="0" max="400" step="5" class="small-text"
								name="<?php echo esc_attr( MDDE_OPTION ); ?>[scroll_offset]"
								value="<?php echo esc_attr( (string) $options['scroll_offset'] ); ?>"> px
							<p class="description"><?php esc_html_e( 'Klick auf einen Eintrag im Inhaltsverzeichnis scrollt die Seite. Hat das Theme eine mitlaufende Kopfzeile, verdeckt sie sonst die Überschrift — hier ihre Höhe eintragen. Die Adminleiste wird automatisch berücksichtigt.', 'md-docs-embed' ); ?></p>
						</td>
					</tr>
					<tr>
						<th scope="row"><label for="mdde-error"><?php esc_html_e( 'Text bei Ladefehler', 'md-docs-embed' ); ?></label></th>
						<td>
							<input type="text" class="regular-text" id="mdde-error"
								name="<?php echo esc_attr( MDDE_OPTION ); ?>[error_text]"
								value="<?php echo esc_attr( $options['error_text'] ); ?>">
						</td>
					</tr>
				</table>
				<?php submit_button(); ?>
			</form>

			<h2><?php esc_html_e( 'Gefundene Dokumente', 'md-docs-embed' ); ?></h2>
			<?php if ( empty( $documents ) ) : ?>
				<p><?php esc_html_e( 'Keine Dokumente gefunden. Basis-URL prüfen — erwartet wird dort die Datei docs.json.', 'md-docs-embed' ); ?></p>
			<?php else : ?>
				<table class="widefat striped" style="max-width:60em">
					<thead>
						<tr>
							<th><?php esc_html_e( 'Titel', 'md-docs-embed' ); ?></th>
							<th><?php esc_html_e( 'Kennung', 'md-docs-embed' ); ?></th>
							<th><?php esc_html_e( 'Shortcode', 'md-docs-embed' ); ?></th>
						</tr>
					</thead>
					<tbody>
						<?php foreach ( $documents as $document ) : ?>
							<tr>
								<td><?php echo esc_html( $document['title'] ); ?></td>
								<td><code><?php echo esc_html( $document['slug'] ); ?></code></td>
								<td><code>[md_docs src="<?php echo esc_html( $document['slug'] ); ?>"]</code></td>
							</tr>
						<?php endforeach; ?>
					</tbody>
				</table>
			<?php endif; ?>

			<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" style="margin-top:1em">
				<input type="hidden" name="action" value="mdde_flush">
				<?php wp_nonce_field( 'mdde_flush' ); ?>
				<?php submit_button( __( 'Dokumentenliste neu laden', 'md-docs-embed' ), 'secondary', 'submit', false ); ?>
			</form>
		</div>
		<?php
	}
}
