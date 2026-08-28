<?php
/**
 * Gutenberg-Block.
 *
 * @package md-docs-embed
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Block "Verbandsdokument".
 */
class MDDE_Block {

	/**
	 * Hooks registrieren.
	 */
	public static function init() {
		add_action( 'init', array( __CLASS__, 'register' ) );
	}

	/**
	 * Block registrieren. Die Darstellung erzeugt PHP, damit Block und Shortcode
	 * dieselbe Ausgabe liefern und gespeicherte Beiträge kein veraltetes Markup
	 * mitschleppen.
	 */
	public static function register() {
		if ( ! function_exists( 'register_block_type' ) ) {
			return;
		}

		register_block_type(
			MDDE_PATH . 'blocks/dokument',
			array(
				'render_callback' => array( __CLASS__, 'render' ),
			)
		);
	}

	/**
	 * Serverseitige Darstellung.
	 *
	 * @param array<string, mixed> $attributes Block-Attribute.
	 * @return string
	 */
	public static function render( $attributes ) {
		$attributes = is_array( $attributes ) ? $attributes : array();

		return MDDE_Render::render(
			array(
				'src'        => isset( $attributes['src'] ) ? $attributes['src'] : '',
				'mode'       => isset( $attributes['mode'] ) ? $attributes['mode'] : 'page',
				'nav'        => isset( $attributes['nav'] ) ? $attributes['nav'] : '',
				'chrome'     => isset( $attributes['chrome'] ) ? $attributes['chrome'] : mdde_option( 'chrome' ),
				'theme'      => isset( $attributes['theme'] ) ? $attributes['theme'] : mdde_option( 'theme' ),
				'min_height' => isset( $attributes['minHeight'] ) ? $attributes['minHeight'] : mdde_option( 'min_height' ),
				'max_height' => isset( $attributes['maxHeight'] ) ? $attributes['maxHeight'] : mdde_option( 'max_height' ),
				'base_url'   => isset( $attributes['baseUrl'] ) ? $attributes['baseUrl'] : '',
				'title'      => isset( $attributes['title'] ) ? $attributes['title'] : '',
				'sync_url'   => isset( $attributes['syncUrl'] ) ? $attributes['syncUrl'] : '',
			)
		);
	}
}
