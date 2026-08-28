<?php
/**
 * REST-Route für den Block-Editor.
 *
 * @package md-docs-embed
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Liefert dem Editor die Dokumentenliste. Der Abruf der Docs-Instanz bleibt damit
 * serverseitig — der Editor spricht die fremde Domain nie direkt an.
 */
class MDDE_Rest {

	const NAMESPACE_V1 = 'mdde/v1';

	/**
	 * Hooks registrieren.
	 */
	public static function init() {
		add_action( 'rest_api_init', array( __CLASS__, 'register_routes' ) );
	}

	/**
	 * Routen registrieren.
	 */
	public static function register_routes() {
		register_rest_route(
			self::NAMESPACE_V1,
			'/documents',
			array(
				'methods'             => WP_REST_Server::READABLE,
				'callback'            => array( __CLASS__, 'documents' ),
				'permission_callback' => static function () {
					return current_user_can( 'edit_posts' );
				},
				'args'                => array(
					'base_url' => array(
						'type'              => 'string',
						'required'          => false,
						'sanitize_callback' => static function ( $value ) {
							return esc_url_raw( (string) $value, array( 'http', 'https' ) );
						},
					),
					'refresh'  => array(
						'type'     => 'boolean',
						'required' => false,
						'default'  => false,
					),
				),
			)
		);
	}

	/**
	 * Dokumentenliste.
	 *
	 * @param WP_REST_Request $request Anfrage.
	 * @return WP_REST_Response
	 */
	public static function documents( WP_REST_Request $request ) {
		$base    = (string) $request->get_param( 'base_url' );
		$refresh = (bool) $request->get_param( 'refresh' );

		return new WP_REST_Response(
			array(
				'base'      => MDDE_URL::resolve_base( $base ),
				'documents' => MDDE_Manifest::documents( $base, $refresh ),
			),
			200
		);
	}
}
