<?php
/**
 * Abhängigkeiten des Editor-Skripts.
 *
 * Wird normalerweise von @wordpress/scripts erzeugt. Dieses Plugin kommt ohne
 * Build-Schritt aus, deshalb ist die Datei von Hand gepflegt.
 *
 * @package md-docs-embed
 */

return array(
	'dependencies' => array(
		'wp-blocks',
		'wp-block-editor',
		'wp-components',
		'wp-element',
		'wp-i18n',
		'wp-api-fetch',
		'wp-server-side-render',
	),
	'version'      => '1.0.0',
);
