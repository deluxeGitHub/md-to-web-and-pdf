<?php
/**
 * Plugin Name:       Verbandsdokumente einbetten
 * Plugin URI:        https://github.com/deluxeGitHub/md-to-web-and-pdf
 * Description:       Bettet einzelne Dokumente oder das gesamte Dokumenten-Framework (docs.btfv.de) als Iframe in WordPress-Seiten ein. Höhe folgt dem Inhalt, keine zweite Scrollleiste.
 * Version:           1.0.0
 * Requires at least: 6.4
 * Requires PHP:      7.4
 * Author:            BTFV
 * License:           GPL-2.0-or-later
 * License URI:       https://www.gnu.org/licenses/gpl-2.0.html
 * Text Domain:       md-docs-embed
 *
 * Siehe SPEC-007 im Framework-Repository.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

define( 'MDDE_VERSION', '1.0.0' );
define( 'MDDE_FILE', __FILE__ );
define( 'MDDE_PATH', plugin_dir_path( __FILE__ ) );
define( 'MDDE_PLUGIN_URL', plugin_dir_url( __FILE__ ) );
define( 'MDDE_OPTION', 'mdde_options' );

require_once MDDE_PATH . 'includes/class-mdde-url.php';
require_once MDDE_PATH . 'includes/class-mdde-manifest.php';
require_once MDDE_PATH . 'includes/class-mdde-render.php';
require_once MDDE_PATH . 'includes/class-mdde-settings.php';
require_once MDDE_PATH . 'includes/class-mdde-rest.php';
require_once MDDE_PATH . 'includes/class-mdde-block.php';
require_once MDDE_PATH . 'includes/class-mdde-shortcode.php';

/**
 * Standardwerte der Optionen.
 *
 * @return array<string, mixed>
 */
function mdde_default_options() {
	return array(
		'base_url'         => 'https://docs.btfv.de/',
		'allowed_origins'  => array(),
		'chrome'           => 'none',
		'theme'            => 'light',
		'min_height'       => 400,
		'max_height'       => 0,
		'error_text'       => __( 'Das Dokument konnte nicht geladen werden.', 'md-docs-embed' ),
	);
}

/**
 * Optionen inklusive Standardwerten.
 *
 * @return array<string, mixed>
 */
function mdde_options() {
	$stored = get_option( MDDE_OPTION, array() );
	if ( ! is_array( $stored ) ) {
		$stored = array();
	}
	return wp_parse_args( $stored, mdde_default_options() );
}

/**
 * Eine einzelne Option.
 *
 * @param string $key     Schlüssel.
 * @param mixed  $default Rückfallwert.
 * @return mixed
 */
function mdde_option( $key, $default = null ) {
	$options = mdde_options();
	return array_key_exists( $key, $options ) ? $options[ $key ] : $default;
}

add_action(
	'plugins_loaded',
	static function () {
		MDDE_Settings::init();
		MDDE_Rest::init();
		MDDE_Block::init();
		MDDE_Shortcode::init();
	}
);

register_deactivation_hook(
	__FILE__,
	static function () {
		MDDE_Manifest::flush_cache();
	}
);
