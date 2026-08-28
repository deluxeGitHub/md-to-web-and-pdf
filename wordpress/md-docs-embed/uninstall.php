<?php
/**
 * Aufräumen bei der Deinstallation.
 *
 * @package md-docs-embed
 */

if ( ! defined( 'WP_UNINSTALL_PLUGIN' ) ) {
	exit;
}

delete_option( 'mdde_options' );

// Zwischengespeicherte Manifeste entfernen.
global $wpdb;
// phpcs:ignore WordPress.DB.DirectDatabaseQuery -- einmaliges Aufräumen bei der Deinstallation.
$wpdb->query( "DELETE FROM {$wpdb->options} WHERE option_name LIKE '\_transient\_mdde\_manifest\_%' OR option_name LIKE '\_transient\_timeout\_mdde\_manifest\_%'" );
