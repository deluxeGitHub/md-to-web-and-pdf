<?php
/**
 * Shortcode [md_docs].
 *
 * @package md-docs-embed
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Rückfallebene für Classic Editor, Widgets und Theme-Templates.
 */
class MDDE_Shortcode {

	const TAG = 'md_docs';

	/**
	 * Hooks registrieren.
	 */
	public static function init() {
		add_shortcode( self::TAG, array( __CLASS__, 'render' ) );
	}

	/**
	 * Shortcode auswerten.
	 *
	 * @param array<string, string>|string $atts Attribute.
	 * @return string
	 */
	public static function render( $atts ) {
		$atts = shortcode_atts(
			array(
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
			),
			is_array( $atts ) ? $atts : array(),
			self::TAG
		);

		return MDDE_Render::render( $atts );
	}
}
