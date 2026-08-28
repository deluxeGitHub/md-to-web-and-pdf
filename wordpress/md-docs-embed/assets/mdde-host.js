/**
 * Host-Skript der Einbettung (SPEC-007).
 *
 * Führt die Iframe-Höhe nach, schreibt bei Framework-Navigation den Pfad in die
 * Adresszeile und blendet bei Ladefehler einen Direktlink ein.
 *
 * Sicherheitsmodell nach Vorbild von wp-embed.js im WordPress-Core: eine Nachricht
 * wird nur akzeptiert, wenn Origin UND Absenderfenster stimmen.
 */
(function () {
	"use strict";

	var settings = window.mddeSettings || {};
	var allowedOrigins = Array.isArray( settings.allowedOrigins ) ? settings.allowedOrigins : [];
	var timeoutMs = typeof settings.timeout === "number" ? settings.timeout : 10000;

	var embeds = [];

	function collect() {
		var nodes = document.querySelectorAll( "[data-mdde]" );
		for ( var i = 0; i < nodes.length; i++ ) {
			var container = nodes[ i ];
			if ( container.mddeInitialised ) {
				continue;
			}
			container.mddeInitialised = true;

			var frame = container.querySelector( ".mdde-embed__frame" );
			if ( ! frame ) {
				continue;
			}

			var embed = {
				container: container,
				frame: frame,
				origin: container.getAttribute( "data-origin" ) || "",
				min: parseInt( container.getAttribute( "data-min-height" ), 10 ) || 400,
				max: parseInt( container.getAttribute( "data-max-height" ), 10 ) || 0,
				sync: container.getAttribute( "data-sync-url" ) === "yes",
				ready: false,
				sized: false
			};

			// Den Ladezustand liefert der Server bereits mit - sonst gaebe es zwischen
			// erstem Frame und DOMContentLoaded ein Fenster, in dem das Iframe sichtbar
			// waere. Ohne JavaScript nimmt ihn ein <noscript>-Style zurueck.
			container.setAttribute( "aria-busy", "true" );

			embeds.push( embed );
			watchForFailure( embed );
		}
	}

	/**
	 * Meldet sich das Dokument nicht, ist es entweder nicht erreichbar oder es
	 * liefert den Embed-Modus nicht aus. Beides bekommt denselben Direktlink.
	 */
	function watchForFailure( embed ) {
		window.setTimeout( function () {
			if ( ! embed.ready ) {
				var fallback = embed.container.querySelector( ".mdde-embed__fallback" );
				if ( fallback ) {
					fallback.hidden = false;
				}
				embed.container.classList.remove( "mdde-embed--loading" );
				embed.container.removeAttribute( "aria-busy" );
				embed.container.classList.add( "mdde-embed--unreachable" );
			}
		}, timeoutMs );
	}

	function findEmbed( source ) {
		for ( var i = 0; i < embeds.length; i++ ) {
			if ( embeds[ i ].frame.contentWindow === source ) {
				return embeds[ i ];
			}
		}
		return null;
	}

	function applyHeight( embed, value ) {
		var height = Number( value );
		if ( ! isFinite( height ) || height <= 0 ) {
			return;
		}
		height = Math.ceil( height );
		if ( height < embed.min ) {
			height = embed.min;
		}
		if ( embed.max > 0 && height > embed.max ) {
			height = embed.max;
			embed.frame.setAttribute( "data-clamped", "1" );
		} else {
			embed.frame.removeAttribute( "data-clamped" );
		}
		// Die erste Hoehe springt, sie waechst nicht: Waehrend einer Animation von der
		// Mindesthoehe auf die volle Hoehe ist das Iframe kurz kleiner als sein Inhalt -
		// und genau dann zeigte das Dokument seine eigene Scrollleiste.
		if ( ! embed.sized ) {
			embed.sized = true;
			embed.frame.style.transition = "none";
			embed.frame.style.height = height + "px";
			void embed.frame.offsetHeight; // Layout erzwingen, bevor die Animation zurueckkommt
			embed.frame.style.transition = "";
			return;
		}

		embed.frame.style.height = height + "px";
	}

	function post( embed, payload ) {
		if ( ! embed.frame.contentWindow || ! embed.origin ) {
			return;
		}
		try {
			embed.frame.contentWindow.postMessage( payload, embed.origin );
		} catch ( e ) { /* Iframe noch nicht bereit */ }
	}

	function markReady( embed ) {
		if ( embed.ready ) {
			return;
		}
		embed.ready = true;
		embed.container.classList.remove( "mdde-embed--loading" );
		embed.container.removeAttribute( "aria-busy" );
		embed.container.classList.add( "mdde-embed--ready" );

		var fallback = embed.container.querySelector( ".mdde-embed__fallback" );
		if ( fallback ) {
			fallback.hidden = true;
		}

		// Anker aus der Adresszeile der WordPress-Seite an das Dokument weiterreichen.
		if ( window.location.hash ) {
			post( embed, { type: "mdde:scrollTo", hash: window.location.hash } );
		}
	}

	function syncLocation( embed, data ) {
		if ( ! embed.sync || ! window.history || ! window.history.replaceState ) {
			return;
		}
		if ( typeof data.path !== "string" || ! data.path ) {
			return;
		}
		try {
			var url = new URL( window.location.href );
			url.searchParams.set( "dok", data.path.replace( /^\/+/, "" ) );
			window.history.replaceState( null, "", url.toString() );
		} catch ( e ) { /* ohne Adresszeilen-Update weiterarbeiten */ }
	}

	window.addEventListener( "message", function ( event ) {
		if ( allowedOrigins.indexOf( event.origin ) === -1 ) {
			return;
		}

		var embed = findEmbed( event.source );
		if ( ! embed || embed.origin !== event.origin ) {
			return;
		}

		var data = event.data;
		if ( ! data || typeof data !== "object" || typeof data.type !== "string" ) {
			return;
		}

		switch ( data.type ) {
			case "mdde:ready":
				// Noch nicht einblenden: Die Hoehe steht erst mit mdde:height fest.
				embed.container.classList.add( "mdde-embed--connected" );
				break;
			case "mdde:height":
				applyHeight( embed, data.height );
				markReady( embed );
				break;
			case "mdde:location":
				syncLocation( embed, data );
				break;
			default:
				break;
		}
	} );

	if ( document.readyState === "loading" ) {
		document.addEventListener( "DOMContentLoaded", collect );
	} else {
		collect();
	}
} )();
