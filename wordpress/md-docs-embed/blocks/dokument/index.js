/**
 * Editor-Oberfläche des Blocks "Verbandsdokument" (SPEC-007).
 *
 * Bewusst ohne JSX und ohne Build-Schritt geschrieben, damit das Plugin als
 * fertiges ZIP ausgeliefert werden kann.
 */
( function ( blocks, blockEditor, components, element, i18n, apiFetch, serverSideRender ) {
	"use strict";

	var el = element.createElement;
	var __ = i18n.__;
	var useState = element.useState;
	var useEffect = element.useEffect;

	var InspectorControls = blockEditor.InspectorControls;
	var useBlockProps = blockEditor.useBlockProps;

	var PanelBody = components.PanelBody;
	var SelectControl = components.SelectControl;
	var TextControl = components.TextControl;
	var ToggleControl = components.ToggleControl;
	var Notice = components.Notice;
	var Spinner = components.Spinner;

	var ServerSideRender = serverSideRender;

	/**
	 * Dokumentenliste über die eigene REST-Route holen. Der Editor spricht die
	 * Docs-Instanz nie direkt an - die Prüfung der Quelle bleibt serverseitig.
	 */
	function useDocuments( baseUrl ) {
		var state = useState( { loading: true, documents: [], error: "" } );
		var data = state[ 0 ];
		var setData = state[ 1 ];

		useEffect(
			function () {
				var cancelled = false;
				setData( { loading: true, documents: [], error: "" } );

				apiFetch( {
					path: "/mdde/v1/documents" + ( baseUrl ? "?base_url=" + encodeURIComponent( baseUrl ) : "" )
				} )
					.then( function ( response ) {
						if ( cancelled ) {
							return;
						}
						setData( {
							loading: false,
							documents: ( response && response.documents ) || [],
							error: ""
						} );
					} )
					.catch( function ( err ) {
						if ( cancelled ) {
							return;
						}
						setData( {
							loading: false,
							documents: [],
							error: ( err && err.message ) || __( "Dokumentenliste konnte nicht geladen werden.", "md-docs-embed" )
						} );
					} );

				return function () {
					cancelled = true;
				};
			},
			[ baseUrl ]
		);

		return data;
	}

	blocks.registerBlockType( "mdde/dokument", {
		edit: function ( props ) {
			var attributes = props.attributes;
			var setAttributes = props.setAttributes;
			var blockProps = useBlockProps();

			var docs = useDocuments( attributes.baseUrl );

			var options = [ { label: __( "— Dokument wählen —", "md-docs-embed" ), value: "" } ];
			docs.documents.forEach( function ( doc ) {
				options.push( { label: doc.title || doc.slug, value: doc.slug } );
			} );

			// Kennung eines vorhandenen Blocks anzeigen, auch wenn sie (noch) nicht
			// in der Liste steht - sonst sähe es aus, als wäre nichts gewählt.
			if ( attributes.src && ! docs.documents.some( function ( doc ) { return doc.slug === attributes.src; } ) ) {
				options.push( { label: attributes.src, value: attributes.src } );
			}

			var isSite = attributes.mode === "site";

			var inspector = el(
				InspectorControls,
				null,
				el(
					PanelBody,
					{ title: __( "Dokument", "md-docs-embed" ), initialOpen: true },
					el( SelectControl, {
						label: __( "Was soll eingebettet werden?", "md-docs-embed" ),
						value: attributes.mode,
						options: [
							{ label: __( "Ein einzelnes Dokument", "md-docs-embed" ), value: "page" },
							{ label: __( "Das gesamte Dokumenten-Framework", "md-docs-embed" ), value: "site" }
						],
						onChange: function ( value ) {
							// Navigation folgt dem Modus, damit niemand daran denken muss:
							// Einzeldokument bleibt fest verdrahtet, Framework darf navigieren.
							setAttributes( {
								mode: value,
								nav: value === "site" ? "framework" : "pinned",
								chrome: value === "site" ? "full" : attributes.chrome
							} );
						}
					} ),
					! isSite && docs.loading && el( Spinner ),
					! isSite && ! docs.loading && docs.error
						? el( Notice, { status: "warning", isDismissible: false }, docs.error )
						: null,
					! isSite && ! docs.loading
						? el( SelectControl, {
							label: __( "Dokument", "md-docs-embed" ),
							value: attributes.src,
							options: options,
							onChange: function ( value ) {
								setAttributes( { src: value } );
							},
							help: docs.documents.length
								? ""
								: __( "Keine Dokumente gefunden. Basis-URL unter Einstellungen → Verbandsdokumente prüfen.", "md-docs-embed" )
						} )
						: null
				),
				el(
					PanelBody,
					{ title: __( "Darstellung", "md-docs-embed" ), initialOpen: false },
					el( SelectControl, {
						label: __( "Kopfbereich", "md-docs-embed" ),
						value: attributes.chrome,
						options: [
							{ label: __( "Nur der Dokumentinhalt", "md-docs-embed" ), value: "none" },
							{ label: __( "Mit Titel und PDF-Link", "md-docs-embed" ), value: "minimal" },
							{ label: __( "Vollständig, mit Suche", "md-docs-embed" ), value: "full" }
						],
						onChange: function ( value ) {
							setAttributes( { chrome: value } );
						}
					} ),
					el( SelectControl, {
						label: __( "Farbschema", "md-docs-embed" ),
						value: attributes.theme,
						options: [
							{ label: __( "Immer hell", "md-docs-embed" ), value: "light" },
							{ label: __( "Immer dunkel", "md-docs-embed" ), value: "dark" },
							{ label: __( "Dem Gerät des Besuchers folgen", "md-docs-embed" ), value: "auto" }
						],
						onChange: function ( value ) {
							setAttributes( { theme: value } );
						}
					} ),
					el( TextControl, {
						label: __( "Mindesthöhe in Pixeln", "md-docs-embed" ),
						type: "number",
						value: String( attributes.minHeight ),
						onChange: function ( value ) {
							setAttributes( { minHeight: parseInt( value, 10 ) || 400 } );
						}
					} ),
					el( TextControl, {
						label: __( "Maximalhöhe in Pixeln (0 = unbegrenzt)", "md-docs-embed" ),
						type: "number",
						value: String( attributes.maxHeight ),
						onChange: function ( value ) {
							setAttributes( { maxHeight: parseInt( value, 10 ) || 0 } );
						}
					} ),
					el( TextControl, {
						label: __( "Beschriftung für Screenreader", "md-docs-embed" ),
						value: attributes.title,
						onChange: function ( value ) {
							setAttributes( { title: value } );
						},
						help: __( "Leer lassen, um den Titel des Dokuments zu verwenden.", "md-docs-embed" )
					} )
				),
				el(
					PanelBody,
					{ title: __( "Navigation", "md-docs-embed" ), initialOpen: false },
					el( ToggleControl, {
						label: __( "Im Dokument navigieren erlauben", "md-docs-embed" ),
						checked: attributes.nav === "framework",
						onChange: function ( checked ) {
							setAttributes( { nav: checked ? "framework" : "pinned" } );
						},
						help: attributes.nav === "framework"
							? __( "Links führen innerhalb der Einbettung weiter; der Zurück-Weg ins Framework ist sichtbar.", "md-docs-embed" )
							: __( "Fest auf dieses Dokument verdrahtet: kein Zurück-Link, weiterführende Links öffnen einen neuen Tab.", "md-docs-embed" )
					} ),
					attributes.nav === "framework"
						? el( ToggleControl, {
							label: __( "Adresszeile mitführen", "md-docs-embed" ),
							checked: attributes.syncUrl !== "no",
							onChange: function ( checked ) {
								setAttributes( { syncUrl: checked ? "yes" : "no" } );
							}
						} )
						: null,
					el( TextControl, {
						label: __( "Abweichende Basis-URL", "md-docs-embed" ),
						value: attributes.baseUrl,
						onChange: function ( value ) {
							setAttributes( { baseUrl: value } );
						},
						help: __( "Leer lassen, um die Einstellung zu verwenden. Nur freigegebene Adressen sind möglich.", "md-docs-embed" )
					} )
				)
			);

			var preview;
			if ( ! isSite && ! attributes.src ) {
				preview = el(
					components.Placeholder,
					{
						icon: "media-document",
						label: __( "Verbandsdokument", "md-docs-embed" ),
						instructions: __( "Rechts in der Seitenleiste ein Dokument auswählen.", "md-docs-embed" )
					}
				);
			} else if ( ServerSideRender ) {
				preview = el( ServerSideRender, {
					block: "mdde/dokument",
					attributes: attributes
				} );
			} else {
				preview = el(
					components.Placeholder,
					{
						icon: "media-document",
						label: __( "Verbandsdokument", "md-docs-embed" ),
						instructions: isSite
							? __( "Das gesamte Dokumenten-Framework wird eingebettet.", "md-docs-embed" )
							: attributes.src
					}
				);
			}

			return el( "div", blockProps, inspector, preview );
		},

		// Die Ausgabe erzeugt PHP, im Beitrag steht nur der Block-Kommentar.
		save: function () {
			return null;
		}
	} );
} )(
	window.wp.blocks,
	window.wp.blockEditor,
	window.wp.components,
	window.wp.element,
	window.wp.i18n,
	window.wp.apiFetch,
	window.wp.serverSideRender
);
