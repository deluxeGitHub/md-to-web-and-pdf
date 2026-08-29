/**
 * Host-Skript der Einbettung (SPEC-007).
 *
 * Führt die Iframe-Höhe nach, schreibt bei Framework-Navigation den Pfad in die
 * Adresszeile, scrollt bei Ankersprüngen im Dokument die Seite (A18), kopiert für den
 * Link an einer Überschrift die eigene Adresse (A19) und blendet bei Ladefehler einen
 * Direktlink ein.
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
				scrollOffset: parseInt( container.getAttribute( "data-scroll-offset" ), 10 ) || 0,
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

	/**
	 * Zusätzlicher Abstand über dem Ziel: die Adminleiste, falls sie mitscrollt, dazu
	 * der eingestellte Wert für eine fixe Kopfzeile des Themes.
	 */
	function stickyOffset( embed ) {
		var offset = 8 + embed.scrollOffset;
		var bar = document.getElementById( "wpadminbar" );
		if ( bar ) {
			var position = window.getComputedStyle( bar ).position;
			if ( "fixed" === position || "sticky" === position ) {
				offset += bar.offsetHeight;
			}
		}
		return offset;
	}

	/**
	 * Ankersprung im Dokument. Das Iframe ist so hoch wie sein Inhalt und hat keinen
	 * eigenen Scrollweg - gescrollt wird hier. Nur bei erreichter Höhendeckelung gibt
	 * es im Iframe etwas zu scrollen; dann geht der Abstand zurück (A18).
	 */
	function scrollToAnchor( embed, data ) {
		var offset = Number( data.offset );
		if ( ! isFinite( offset ) || offset < 0 ) {
			return;
		}

		if ( "1" === embed.frame.getAttribute( "data-clamped" ) ) {
			post( embed, { type: "mdde:scrollSelf", offset: offset, smooth: !! data.smooth } );
			return;
		}

		var top = embed.frame.getBoundingClientRect().top + window.pageYOffset + offset - stickyOffset( embed );
		try {
			window.scrollTo( { top: Math.max( 0, top ), behavior: data.smooth ? "smooth" : "auto" } );
		} catch ( e ) {
			window.scrollTo( 0, Math.max( 0, top ) );
		}

		writeHash( data.hash );
	}

	/**
	 * Anker in die eigene Adresszeile schreiben, damit ein geteilter Link denselben
	 * Punkt trifft. Nur unverdächtige Werte - der Text kommt aus dem Iframe.
	 */
	function writeHash( hash ) {
		if ( typeof hash !== "string" || ! /^#[A-Za-z0-9\-._~%!$&'()*+,;=:@\/]+$/.test( hash ) ) {
			return "";
		}
		var href = "";
		try {
			var url = new URL( window.location.href );
			url.hash = hash;
			href = url.toString();
		} catch ( e ) {
			return "";
		}
		if ( window.history && window.history.replaceState ) {
			try {
				window.history.replaceState( null, "", href );
			} catch ( e ) { /* Adresse bleibt stehen */ }
		}
		return href;
	}

	/**
	 * Kopieren in die Zwischenablage. Im Iframe scheitert das an der
	 * Berechtigungsrichtlinie, hier nicht - die Aktivierung durch den Klick im Iframe
	 * gilt auch für dieses Fenster.
	 */
	function copyText( text ) {
		if ( window.navigator && navigator.clipboard && navigator.clipboard.writeText ) {
			return navigator.clipboard.writeText( text ).then(
				function () { return true; },
				function () { return legacyCopy( text ); }
			);
		}
		return Promise.resolve( legacyCopy( text ) );
	}

	function legacyCopy( text ) {
		var field = document.createElement( "textarea" );
		field.value = text;
		field.setAttribute( "readonly", "" );
		field.style.position = "absolute";
		field.style.left = "-9999px";
		document.body.appendChild( field );
		field.select();
		var ok = false;
		try {
			ok = document.execCommand( "copy" );
		} catch ( e ) { /* ohne Zwischenablage bleibt ok false */ }
		document.body.removeChild( field );
		return ok;
	}

	/**
	 * Link an einer Überschrift: kopiert wird die Adresse dieser Seite mit Anker,
	 * nicht die der Docs-Instanz (A19).
	 */
	function copyLink( embed, data ) {
		var href = writeHash( data.hash );
		if ( ! href ) {
			return;
		}
		copyText( href ).then( function ( ok ) {
			post( embed, { type: "mdde:copied", ok: !! ok, url: href } );
		} );
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
			case "mdde:anchor":
				scrollToAnchor( embed, data );
				break;
			case "mdde:copyLink":
				copyLink( embed, data );
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
