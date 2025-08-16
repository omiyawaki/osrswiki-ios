'use strict';

/**
 * Adds accessibility attributes to citation links.
 *
 * @see https://phabricator.wikimedia.org/T40141
 * @author Marius Hoch <hoo@online.de>
 */
mw.hook( 'wikipage.content' ).add( ( $content ) => {
	const accessibilityLabelOne = mw.msg( 'cite_references_link_accessibility_label' );
	const accessibilityLabelMany = mw.msg( 'cite_references_link_many_accessibility_label' );

	$content.find( '.mw-cite-backlink' ).each( ( i, el ) => {
		const $links = $( el ).find( 'a' );

		if ( $links.length > 1 ) {
			// This citation is used multiple times. Let's only set the accessibility
			// label on the first link, the following ones should then be
			// self-explaining. This is needed to make sure this isn't getting too
			// wordy.
			$links.eq( 0 ).prepend(
				$( '<span>' )
					.addClass( 'cite-accessibility-label' )
					// Also make sure we have at least one space between the accessibility
					// label and the visual one
					.text( accessibilityLabelMany + ' ' )
			);
		} else {
			$links
				.attr( 'aria-label', accessibilityLabelOne )
				.attr( 'title', accessibilityLabelOne );
		}
	} );
} );
'use strict';

/**
 * Dynamic highlighting while reading an article
 *
 * @author Thiemo Kreuz
 */
( function () {
	/**
	 * Checks if the ID uses a composite format that does not only consist of a sequential number.
	 *
	 * @param {string} id
	 * @return {boolean}
	 */
	function isNamedReference( id ) {
		// Note: This assumes IDs start with the prefix; this is guaranteed by the parser function
		return /^cite_ref-\D/.test( id );
	}

	/**
	 * @param {string} id
	 * @param {jQuery} $content
	 * @return {boolean}
	 */
	function isReusedNamedReference( id, $content ) {
		if ( !isNamedReference( id ) ) {
			return false;
		}

		// Either the ID is already a reuse, or at least one reuse exists somewhere else on the page
		return id.slice( -2 ) !== '-0' ||
			$content.find( '.references a[href="#' + $.escapeSelector( id.slice( 0, -1 ) ) + '1"]' ).length;
	}

	/**
	 * @param {jQuery} $backlinkWrapper
	 * @return {jQuery}
	 */
	function makeUpArrowLink( $backlinkWrapper ) {
		let textNode = $backlinkWrapper[ 0 ].firstChild;
		const accessibilityLabel = mw.msg( 'cite_references_link_accessibility_back_label' );
		const $upArrowLink = $( '<a>' )
			.addClass( 'mw-cite-up-arrow-backlink' )
			.attr( 'aria-label', accessibilityLabel )
			.attr( 'title', accessibilityLabel );

		if ( !textNode ) {
			return $upArrowLink;
		}

		// Skip additional, custom HTML wrappers, if any.
		while ( textNode.firstChild ) {
			textNode = textNode.firstChild;
		}

		if ( textNode.nodeType !== Node.TEXT_NODE || textNode.data.trim() === '' ) {
			return $upArrowLink;
		}

		const upArrow = textNode.data.trim();
		// The text node typically contains "↑ ", and we need to keep the space.
		textNode.data = textNode.data.replace( upArrow, '' );

		// Create a plain text and a clickable "↑". CSS :target selectors make sure only
		// one is visible at a time.
		$backlinkWrapper.prepend(
			$( '<span>' )
				.addClass( 'mw-cite-up-arrow' )
				.text( upArrow ),
			$upArrowLink
				.text( upArrow )
		);

		return $upArrowLink;
	}

	/**
	 * @param {jQuery} $backlink
	 */
	function updateUpArrowLink( $backlink ) {
		// It's convenient to stop at the class name, but it's not guaranteed to be there.
		const $backlinkWrapper = $backlink.closest( '.mw-cite-backlink, li' );
		let $upArrowLink = $backlinkWrapper.find( '.mw-cite-up-arrow-backlink' );

		if ( !$upArrowLink.length && $backlinkWrapper.length ) {
			$upArrowLink = makeUpArrowLink( $backlinkWrapper );
		}

		$upArrowLink.attr( 'href', $backlink.attr( 'href' ) );
	}

	mw.hook( 'wikipage.content' ).add( ( $content ) => {
		// We are going to use the ID in the code below, so better be sure one is there.
		$content.find( '.reference[id] > a' ).on( 'click', function () {
			const id = $( this ).parent().attr( 'id' );

			$content.find( '.mw-cite-targeted-backlink' ).removeClass( 'mw-cite-targeted-backlink' );

			// Bail out if there is not at least a second backlink ("cite_references_link_many").
			if ( !isReusedNamedReference( id, $content ) ) {
				return;
			}

			// The :not() skips the duplicate link created below. Relevant when double clicking.
			const $backlink = $content.find( '.references a[href="#' + $.escapeSelector( id ) + '"]:not(.mw-cite-up-arrow-backlink)' )
				.first()
				.addClass( 'mw-cite-targeted-backlink' );

			if ( $backlink.length ) {
				updateUpArrowLink( $backlink );
			}
		} );
	} );
}() );
'use strict';

/**
 * Temporary tracking to evaluate the impact of Reference Previews on
 * users' interaction with references.
 *
 * @memberof module:ext.cite.ux-enhancements
 * @see https://phabricator.wikimedia.org/T214493
 * @see https://phabricator.wikimedia.org/T231529
 * @see https://phabricator.wikimedia.org/T353798
 * @see https://meta.wikimedia.org/wiki/Schema:ReferencePreviewsBaseline
 * @see https://meta.wikimedia.org/wiki/Schema:ReferencePreviewsCite
 */

const CITE_BASELINE_LOGGING_SCHEMA = 'ext.cite.baseline';
// Same as in the Popups extension
// FIXME: Could be an extension wide constant when Reference Previews is merged into this code base
const REFERENCE_PREVIEWS_LOGGING_SCHEMA = 'event.ReferencePreviewsPopups';

// EventLogging may not be installed
mw.loader.using( 'ext.eventLogging' ).then( () => {
	$( () => {
		if ( !navigator.sendBeacon ||
			!mw.config.get( 'wgIsArticle' )
		) {
			return;
		}

		// FIXME: This might be obsolete when the code moves to the this extension
		mw.trackSubscribe( REFERENCE_PREVIEWS_LOGGING_SCHEMA, ( type, data ) => {
			if ( data.action.indexOf( 'anonymous' ) !== -1 ) {
				mw.config.set( 'wgCiteReferencePreviewsVisible', data.action === 'anonymousEnabled' );
			}
		} );

		// eslint-disable-next-line no-jquery/no-global-selector
		$( '#mw-content-text' ).on(
			'click',
			// Footnote links, references block in VisualEditor, and reference content links.
			'.reference a[ href*="#" ], .mw-reference-text a, .reference-text a',
			function () {
				const isInReferenceBlock = $( this ).parents( '.references' ).length > 0;
				mw.eventLog.dispatch( CITE_BASELINE_LOGGING_SCHEMA, {
					action: ( isInReferenceBlock ?
						'clickedReferenceContentLink' :
						'clickedFootnote' ),
					// FIXME: This might be obsolete when the code moves to the this extension and
					//  we get state directly.
					// eslint-disable-next-line camelcase
					with_ref_previews: mw.config.get( 'wgCiteReferencePreviewsVisible' )
				} );
			}
		);
	} );
} );
mw.loader.impl(function(){return["ext.kartographer.link@",{"main":"modules/maplink/maplink.js","files":{"modules/maplink/maplink.js":function(require,module,exports){/**
 * Link module.
 *
 * Once the page is loaded and ready, turn all `<maplink/>` tags into a link
 * that opens the map in full screen mode.
 *
 * @alternateClassName Link
 * @alternateClassName ext.kartographer.link
 * @class Kartographer.Link
 * @singleton
 */
var kartolink = require( 'ext.kartographer.linkbox' ),
	/**
	 * References the maplinks of the page.
	 *
	 * @type {Kartographer.Linkbox.LinkClass[]}
	 */
	maplinks = [];

/**
 * Gets the map data attached to an element.
 *
 * @param {HTMLElement} element Element
 * @return {Object} Map properties
 * @return {number} return.mapID MapID in RuneScape
 * @return {number} return.plane Plane in RuneScape
 * @return {string} return.mapVersion Map version
 * @return {number} return.latitude
 * @return {number} return.longitude
 * @return {number} return.zoom
 * @return {string} return.style Map style
 * @return {string[]} return.overlays Overlay groups
 */
function getMapData( element ) {
	var $el = $( element );
	return {
	    mapID: +$el.data( 'mapid' ),
	    plane: +$el.data( 'plane' ),
	    mapVersion: $el.data( 'mapversion' ),
	    plainTiles: $el.data( 'plaintiles' ),
		latitude: +$el.data( 'lat' ),
		longitude: +$el.data( 'lon' ),
		zoom: +$el.data( 'zoom' ),
		lang: $el.data( 'lang' ),
		style: $el.data( 'style' ),
		captionText: $el.get( 0 ).innerText,
		overlays: $el.data( 'overlays' ) || []
	};
}

/**
 * Attach the maplink handler.
 *
 * @param {jQuery} jQuery element with the content
 */
function handleMapLinks( $content ) {
	$content.find( '.mw-kartographer-maplink[data-mw="interface"]' ).each( function () {
		var data = getMapData( this );

		var index = maplinks.length;
		maplinks[ index ] = kartolink.link( {
			featureType: 'maplink',
			container: this,
	        mapID: data.mapID,
	        plane: data.plane,
	        mapVersion: data.mapVersion,
	        plainTiles: data.plainTiles,
			center: [ data.latitude, data.longitude ],
			zoom: data.zoom,
			lang: data.lang,
			dataGroups: data.overlays,
			captionText: data.captionText
		} );
		maplinks[ index ].$container.attr('href', '#mapFullscreen')
	} );
}

mw.hook( 'wikipage.indicators' ).add( handleMapLinks );
mw.hook( 'wikipage.content' ).add( handleMapLinks );

module.exports = maplinks;
}}}];});
mw.loader.impl(function(){return["mediawiki.page.ready@",{"main":"ready.js","files":{"ready.js":function(require,module,exports){const checkboxShift = require( './checkboxShift.js' );
const config = require( './config.json' );
const teleportTarget = require( './teleportTarget.js' );

// Break out of framesets
if ( mw.config.get( 'wgBreakFrames' ) ) {
	// Note: In IE < 9 strict comparison to window is non-standard (the standard didn't exist yet)
	// it works only comparing to window.self or window.window (https://stackoverflow.com/q/4850978/319266)
	if ( window.top !== window.self ) {
		// Un-trap us from framesets
		window.top.location.href = location.href;
	}
}

mw.hook( 'wikipage.content' ).add( ( $content ) => {
	const modules = [];

	let $collapsible;
	if ( config.collapsible ) {
		$collapsible = $content.find( '.mw-collapsible' );
		if ( $collapsible.length ) {
			modules.push( 'jquery.makeCollapsible' );
		}
	}

	let $sortable;
	if ( config.sortable ) {
		$sortable = $content.find( 'table.sortable' );
		if ( $sortable.length ) {
			modules.push( 'jquery.tablesorter' );
		}
	}

	if ( modules.length ) {
		// Both modules are preloaded by Skin::getDefaultModules()
		mw.loader.using( modules ).then( () => {
			// For tables that are both sortable and collapsible,
			// it must be made sortable first and collapsible second.
			// This is because jquery.tablesorter stumbles on the
			// elements inserted by jquery.makeCollapsible (T64878)
			if ( $sortable && $sortable.length ) {
				$sortable.tablesorter();
			}
			if ( $collapsible && $collapsible.length ) {
				$collapsible.makeCollapsible();
			}
		} );
	}
	if ( $content[ 0 ] && $content[ 0 ].isConnected === false ) {
		mw.log.warn( 'wikipage.content hook should not be fired on unattached content' );
	}

	checkboxShift( $content.find( 'input[type="checkbox"]:not(.noshiftselect)' ) );
} );

// Add toolbox portlet to toggle all collapsibles if there are any
require( './toggleAllCollapsibles.js' );

// Handle elements outside the wikipage content
$( () => {
	/**
	 * There is a bug on iPad and maybe other browsers where if initial-scale is not set
	 * the page cannot be zoomed. If the initial-scale is set on the server side, this will result
	 * in an unwanted zoom on mobile devices. To avoid this we check innerWidth and set the
	 * initial-scale on the client where needed. The width must be synced with the value in
	 * Skin::initPage.
	 * More information on this bug in [[phab:T311795]].
	 *
	 * @ignore
	 */
	function fixViewportForTabletDevices() {
		const $viewport = $( 'meta[name=viewport]' );
		const content = $viewport.attr( 'content' );
		const scale = window.outerWidth / window.innerWidth;
		// This adjustment is limited to tablet devices. It must be a non-zero value to work.
		// (these values correspond to @min-width-breakpoint-tablet and @min-width-breakpoint-desktop
		// See https://doc.wikimedia.org/codex/main/design-tokens/breakpoint.html
		if ( window.innerWidth >= 640 && window.innerWidth < 1120 &&
			content && content.indexOf( 'initial-scale' ) === -1
		) {
			// Note:
			// - The `width` value must be equal to @min-width-breakpoint-desktop above
			// - If `initial-scale` value is 1 the font-size adjust feature will not work on iPad
			$viewport.attr( 'content', 'width=1120,initial-scale=' + scale );
		}
	}

	// Add accesskey hints to the tooltips
	$( '[accesskey]' ).updateTooltipAccessKeys();

	const node = document.querySelector( '.mw-indicators' );
	if ( node && node.children.length ) {
		/**
		 * Fired when a page's status indicators are being added to the DOM.
		 *
		 * @event ~'wikipage.indicators'
		 * @memberof Hooks
		 * @param {jQuery} $content jQuery object with the elements of the indicators
		 * @see https://www.mediawiki.org/wiki/Special:MyLanguage/Help:Page_status_indicators
		 */
		mw.hook( 'wikipage.indicators' ).fire( $( node.children ) );
	}

	const $content = $( '#mw-content-text' );
	// Avoid unusable events, and the errors they cause, for custom skins that
	// do not display any content (T259577).
	if ( $content.length ) {
		/**
		 * Fired when wiki content has been added to the DOM.
		 *
		 * This should only be fired after $content has been attached.
		 *
		 * This includes the ready event on a page load (including post-edit loads)
		 * and when content has been previewed with LivePreview.
		 *
		 * @event ~'wikipage.content'
		 * @memberof Hooks
		 * @param {jQuery} $content The most appropriate element containing the content,
		 *   such as #mw-content-text (regular content root) or #wikiPreview (live preview
		 *   root)
		 */
		mw.hook( 'wikipage.content' ).fire( $content );
	}

	let $nodes = $( '.catlinks[data-mw="interface"]' );
	if ( $nodes.length ) {
		/**
		 * Fired when categories are being added to the DOM.
		 *
		 * It is encouraged to fire it before the main DOM is changed (when $content
		 * is still detached).  However, this order is not defined either way, so you
		 * should only rely on $content itself.
		 *
		 * This includes the ready event on a page load (including post-edit loads)
		 * and when content has been previewed with LivePreview.
		 *
		 * @event ~'wikipage.categories'
		 * @memberof Hooks
		 * @param {jQuery} $content The most appropriate element containing the content,
		 *   such as .catlinks
		 */
		mw.hook( 'wikipage.categories' ).fire( $nodes );
	}

	$nodes = $( 'table.diff[data-mw="interface"]' );
	if ( $nodes.length ) {
		/**
		 * Fired when the diff is added to a page containing a diff.
		 *
		 * Similar to the {@link Hooks~'wikipage.content' wikipage.content hook}
		 * $diff may still be detached when the hook is fired.
		 *
		 * @event ~'wikipage.diff'
		 * @memberof Hooks
		 * @param {jQuery} $diff The root element of the MediaWiki diff (`table.diff`).
		 */
		mw.hook( 'wikipage.diff' ).fire( $nodes.eq( 0 ) );
	}

	$( '#t-print a' ).on( 'click', ( e ) => {
		window.print();
		e.preventDefault();
	} );

	const $permanentLink = $( '#t-permalink a' );
	function updatePermanentLinkHash() {
		if ( mw.util.getTargetFromFragment() ) {
			$permanentLink[ 0 ].hash = location.hash;
		} else {
			$permanentLink[ 0 ].hash = '';
		}
	}
	if ( $permanentLink.length ) {
		$( window ).on( 'hashchange', updatePermanentLinkHash );
		updatePermanentLinkHash();
	}

	/**
	 * Fired when a trusted UI element to perform a logout has been activated.
	 *
	 * This will end the user session, and either redirect to the given URL
	 * on success, or queue an error message via {@link mw.notification}.
	 *
	 * @event ~'skin.logout'
	 * @memberof Hooks
	 * @param {string} href Full URL
	 */
	const LOGOUT_EVENT = 'skin.logout';
	function logoutViaPost( href ) {
		mw.notify(
			mw.message( 'logging-out-notify' ),
			{ tag: 'logout', autoHide: false }
		);
		const api = new mw.Api();
		if ( mw.user.isTemp() ) {
			// Indicate to the success page that the user was previously a temporary account, so that the success
			// message can be customised appropriately.
			const url = new URL( href );
			url.searchParams.append( 'wasTempUser', 1 );
			href = url;
		}
		api.postWithToken( 'csrf', {
			action: 'logout'
		} ).then(
			() => {
				location.href = href;
			},
			( err, data ) => {
				mw.notify(
					api.getErrorMessage( data ),
					{ type: 'error', tag: 'logout', autoHide: false }
				);
			}
		);
	}
	// Turn logout to a POST action
	mw.hook( LOGOUT_EVENT ).add( logoutViaPost );
	$( config.selectorLogoutLink ).on( 'click', function ( e ) {
		mw.hook( LOGOUT_EVENT ).fire( this.href );
		e.preventDefault();
	} );
	fixViewportForTabletDevices();

	teleportTarget.attach();
} );

/**
 * @private
 * @param {HTMLElement} element
 * @return {boolean} Whether the element is a search input.
 */
function isSearchInput( element ) {
	return element.id === 'searchInput' ||
		element.classList.contains( 'mw-searchInput' );
}

/**
 * Load a given module when a search input is focused.
 *
 * @memberof module:mediawiki.page.ready
 * @param {string} moduleName Name of a module
 */
function loadSearchModule( moduleName ) {
	// T251544: Collect search performance metrics to compare Vue search with
	// mediawiki.searchSuggest performance. Marks and Measures will only be
	// recorded on the Vector skin.
	//
	// Vue search isn't loaded through this function so we are only collecting
	// legacy search performance metrics here.

	const shouldTestSearch = !!( moduleName === 'mediawiki.searchSuggest' &&
		mw.config.get( 'skin' ) === 'vector' &&
		window.performance &&
		performance.mark &&
		performance.measure &&

		performance.getEntriesByName ),
		loadStartMark = 'mwVectorLegacySearchLoadStart',
		loadEndMark = 'mwVectorLegacySearchLoadEnd';

	function requestSearchModule() {
		if ( shouldTestSearch ) {
			performance.mark( loadStartMark );
		}
		mw.loader.using( moduleName, () => {
			if ( shouldTestSearch && performance.getEntriesByName( loadStartMark ).length ) {
				performance.mark( loadEndMark );
				performance.measure( 'mwVectorLegacySearchLoadStartToLoadEnd', loadStartMark, loadEndMark );
			}
		} );
	}

	// Load the module once a search input is focussed.
	function eventListener( e ) {
		if ( isSearchInput( e.target ) ) {
			requestSearchModule();

			document.removeEventListener( 'focusin', eventListener );
		}
	}

	// Load the module now if the search input is already focused,
	// because the user started typing before the JavaScript arrived.
	if ( document.activeElement && isSearchInput( document.activeElement ) ) {
		requestSearchModule();
		return;
	}

	document.addEventListener( 'focusin', eventListener );
}

// Skins may decide to disable this behaviour or use an alternative module.
if ( config.search ) {
	loadSearchModule( 'mediawiki.searchSuggest' );
}

try {
	// Load the post-edit notification module if a notification has been scheduled.
	// Use `sessionStorage` directly instead of 'mediawiki.storage' to minimize dependencies.
	if ( sessionStorage.getItem( 'mw-PostEdit' + mw.config.get( 'wgPageName' ) ) ) {
		mw.loader.load( 'mediawiki.action.view.postEdit' );
	}
} catch ( err ) {}

/**
 * @exports mediawiki.page.ready
 */
module.exports = {
	loadSearchModule,
	/** @type {module:mediawiki.page.ready.CheckboxHack} */
	checkboxHack: require( './checkboxHack.js' ),
	/**
	 * A container for displaying elements that overlay the page, such as dialogs.
	 *
	 * @type {HTMLElement}
	 */
	teleportTarget: teleportTarget.target
};
},"checkboxShift.js":function(require,module,exports){/**
 * Enable checkboxes to be checked or unchecked in a row by clicking one,
 * holding shift and clicking another one.
 *
 * @method checkboxShift
 * @memberof module:mediawiki.page.ready
 * @param {jQuery} $box
 */
module.exports = function ( $box ) {
	let prev;
	// When our boxes are clicked..
	$box.on( 'click', ( e ) => {
		// And one has been clicked before...
		if ( prev && e.shiftKey ) {
			// Check or uncheck this one and all in-between checkboxes,
			// except for disabled ones
			$box
				.slice(
					Math.min( $box.index( prev ), $box.index( e.target ) ),
					Math.max( $box.index( prev ), $box.index( e.target ) ) + 1
				)
				.filter( function () {
					return !this.disabled && this.checked !== e.target.checked;
				} )
				.prop( 'checked', e.target.checked )
				// Since the state change is a consequence of direct user action,
				// fire the 'change' event (see T313077).
				.trigger( 'change' );
		}
		// Either way, remember this as the last clicked one
		prev = e.target;
	} );
};
},"checkboxHack.js":function(require,module,exports){/**
 * Utility library for managing components using the [CSS checkbox hack]{@link https://css-tricks.com/the-checkbox-hack/}.
 * To access call ```require('mediawiki.page.ready').checkboxHack```.
 *
 * The checkbox hack works without JavaScript for graphical user-interface users, but relies on
 * enhancements to work well for screen reader users. This module provides required a11y
 * interactivity for updating the `aria-expanded` accessibility state, and optional enhancements
 * for avoiding the distracting focus ring when using a pointing device, and target dismissal on
 * focus loss or external click.
 *
 * The checkbox hack is a prevalent pattern in MediaWiki similar to disclosure widgets[0]. Although
 * dated and out-of-fashion, it's surprisingly flexible allowing for both `details` / `summary`-like
 * patterns, menu components, and more complex structures (to be used sparingly) where the toggle
 * button and target are in different parts of the Document without an enclosing element, so long as
 * they can be described as a sibling to the input. It's complicated and frequent enough to warrant
 * single implementation.
 *
 * In time, proper disclosure widgets should replace checkbox hacks. However, the second pattern has
 * no equivalent so the checkbox hack may have a continued use case for some time to come.
 *
 * When the abstraction is leaky, the underlying implementation is simpler than anything built to
 * hide it. Attempts to abstract the functionality for the second pattern failed so all related code
 * celebrates the implementation as directly as possible.
 *
 * All the code assumes that when the input is checked, the target is in an expanded state.
 *
 * Consider the disclosure widget pattern first mentioned:
 *
 * ```html
 * <details>                                              <!-- Container -->
 *     <summary>Click to expand navigation menu</summary> <!-- Button -->
 *     <ul>                                               <!-- Target -->
 *         <li>Main page</li>
 *         <li>Random article</li>
 *         <li>Donate to Wikipedia</li>
 *     </ul>
 * </details>
 * ```
 *
 * Which is represented verbosely by a checkbox hack as such:
 *
 * ```html
 * <div>                                                 <!-- Container -->
 *     <input                                            <!-- Visually hidden checkbox -->
 *         type="checkbox"
 *         id="sidebar-checkbox"
 *         class="mw-checkbox-hack-checkbox"
 *         {{#visible}}checked{{/visible}}
 *         role="button"
 *         aria-labelledby="sidebar-button"
 *         aria-expanded="true||false"
 *         aria-haspopup="true">                         <!-- Optional attribute -->
 *     <label                                            <!-- Button -->
 *         id="sidebar-button"
 *         class="mw-checkbox-hack-button"
 *         for="sidebar-checkbox"
 *         aria-hidden="true">
 *         Click to expand navigation menu
 *     </label>
 *     <ul id="sidebar" class="mw-checkbox-hack-target"> <!-- Target -->
 *         <li>Main page</li>
 *         <li>Random article</li>
 *         <li>Donate to Wikipedia</li>
 *     </ul>
 * </div>
 * ```
 *
 * Where the checkbox is the input, the label is the button, and the target is the unordered list.
 * `aria-haspopup` is an optional attribute that can be applied when dealing with popup elements (i.e. menus).
 *
 * Note that while the label acts as a button for visual users (i.e. it's usually styled as a button and is clicked),
 * the checkbox is what's actually interacted with for keyboard and screenreader users. Many of the HTML attributes
 * and JS enhancements serve to give the checkbox the behavior and semantics of a button.
 * For this reason any hover/focus/active state styles for the button should be applied based on the checkbox state
 * (i.e. https://github.com/wikimedia/mediawiki/blob/master/resources/src/mediawiki.ui.button/button.less#L90)
 *
 * Consider the disparate pattern:
 *
 * ```html
 * <!-- ... -->
 * <!-- The only requirement is that the button and target can be described as a sibling to the
 *      checkbox. -->
 * <input
 *     type="checkbox"
 *     id="sidebar-checkbox"
 *     class="mw-checkbox-hack-checkbox"
 *     {{#visible}}checked{{/visible}}
 *     role="button"
 *     aria-labelledby="sidebar-button"
 *     aria-expanded="true||false"
 *     aria-haspopup="true">
 * <!-- ... -->
 * <label
 *     id="sidebar-button"
 *     class="mw-checkbox-hack-button"
 *     for="sidebar-checkbox"
 *     aria-hidden="true">
 *     Toggle navigation menu
 * </label>
 * <!-- ... -->
 * <ul id="sidebar" class="mw-checkbox-hack-target">
 *     <li>Main page</li>
 *     <li>Random article</li>
 *     <li>Donate to Wikipedia</li>
 * </ul>
 * <!-- ... -->
 * ```
 *
 * Which is the same as the disclosure widget but without the enclosing container and the input only
 * needs to be a preceding sibling of the button and target. It's possible to bend the checkbox hack
 * further to allow the button and target to be at an arbitrary depth so long as a parent can be
 * described as a succeeding sibling of the input, but this requires a mixin implementation that
 * duplicates the rules for each relation selector.
 *
 * Exposed APIs should be considered stable.
 *
 * Accompanying checkbox hack styles are tracked in T252774.
 *
 * [0]: https://developer.mozilla.org/docs/Web/HTML/Element/details
 *
 * @namespace CheckboxHack
 * @memberof module:mediawiki.page.ready
 */
/**
 * Revise the button's `aria-expanded` state to match the checked state.
 *
 * @memberof module:mediawiki.page.ready.CheckboxHack
 * @param {HTMLInputElement} checkbox
 * @param {HTMLElement} button
 */
function updateAriaExpanded( checkbox, button ) {
	if ( button ) {
		mw.log.warn( '[1.38] The button parameter in updateAriaExpanded is deprecated, aria-expanded will be applied to the checkbox going forward. View the updated checkbox hack documentation for more details.' );
		button.setAttribute( 'aria-expanded', checkbox.checked.toString() );
		return;
	}

	checkbox.setAttribute( 'aria-expanded', checkbox.checked.toString() );
}

/**
 * Set the checked state and fire the 'input' event.
 * Programmatic changes to checkbox.checked do not trigger an input or change event.
 * The input event in turn will call updateAriaExpanded().
 *
 * setCheckedState() is called when a user event on some element other than the checkbox
 * should result in changing the checkbox state.
 *
 * Per https://html.spec.whatwg.org/multipage/indices.html#event-input
 * Input event is fired at controls when the user changes the value.
 * Per https://html.spec.whatwg.org/multipage/input.html#checkbox-state-(type=checkbox):event-input
 * Fire an event named input at the element with the bubbles attribute initialized to true.
 *
 * https://html.spec.whatwg.org/multipage/indices.html#event-change
 * For completeness the 'change' event should be fired too,
 * however we make no use of the 'change' event,
 * nor expect it to be used, thus firing it
 * would be unnecessary load.
 *
 * @param {HTMLInputElement} checkbox
 * @param {boolean} checked
 * @ignore
 */
function setCheckedState( checkbox, checked ) {
	checkbox.checked = checked;
	// Chrome and Firefox sends the builtin Event with .bubbles == true and .composed == true.
	/** @type {Event} */
	let e;
	if ( typeof Event === 'function' ) {
		e = new Event( 'input', { bubbles: true, composed: true } );
	} else {
		// IE 9-11, FF 6-10, Chrome 9-14, Safari 5.1, Opera 11.5, Android 3-4.3
		e = document.createEvent( 'CustomEvent' );
		if ( !e ) {
			return;
		}
		e.initCustomEvent( 'input', true /* canBubble */, false, false );
	}
	checkbox.dispatchEvent( e );
}

/**
 * Returns true if the Event's target is an inclusive descendant of any the checkbox hack's
 * constituents (checkbox, button, or target), and false otherwise.
 *
 * @param {HTMLInputElement} checkbox
 * @param {HTMLElement} button
 * @param {Node} target
 * @param {Event} event
 * @return {boolean}
 * @ignore
 */
function containsEventTarget( checkbox, button, target, event ) {
	return event.target instanceof Node && (
		checkbox.contains( event.target ) ||
		button.contains( event.target ) ||
		target.contains( event.target )
	);
}

/**
 * Dismiss the target when event is outside the checkbox, button, and target.
 * In simple terms this closes the target (menu, typically) when clicking somewhere else.
 *
 * @param {HTMLInputElement} checkbox
 * @param {HTMLElement} button
 * @param {Node} target
 * @param {Event} event
 * @ignore
 */
function dismissIfExternalEventTarget( checkbox, button, target, event ) {
	if ( checkbox.checked && !containsEventTarget( checkbox, button, target, event ) ) {
		setCheckedState( checkbox, false );
	}
}

/**
 * Update the `aria-expanded` attribute based on checkbox state (target visibility) changes.
 *
 * @memberof module:mediawiki.page.ready.CheckboxHack
 * @param {HTMLInputElement} checkbox
 * @param {HTMLElement} button
 * @return {function(): void} Cleanup function that removes the added event listeners.
 */
function bindUpdateAriaExpandedOnInput( checkbox, button ) {
	if ( button ) {
		mw.log.warn( '[1.38] The button parameter in bindUpdateAriaExpandedOnInput is deprecated, aria-expanded will be applied to the checkbox going forward. View the updated checkbox hack documentation for more details.' );
	}

	const listener = updateAriaExpanded.bind( undefined, checkbox, button );
	// Whenever the checkbox state changes, update the `aria-expanded` state.
	checkbox.addEventListener( 'input', listener );

	return function () {
		checkbox.removeEventListener( 'input', listener );
	};
}

/**
 * Manually change the checkbox state to avoid a focus change when using a pointing device.
 *
 * @memberof module:mediawiki.page.ready.CheckboxHack
 * @param {HTMLInputElement} checkbox
 * @param {HTMLElement} button
 * @return {function(): void} Cleanup function that removes the added event listeners.
 */
function bindToggleOnClick( checkbox, button ) {
	function listener( event ) {
		// Do not allow the browser to handle the checkbox. Instead, manually toggle it which does
		// not alter focus.
		event.preventDefault();
		setCheckedState( checkbox, !checkbox.checked );
	}
	button.addEventListener( 'click', listener, true );

	return function () {
		button.removeEventListener( 'click', listener, true );
	};
}

/**
 * Manually change the checkbox state when the button is focused and SPACE is pressed.
 *
 * @deprecated Use `bindToggleOnEnter` instead.
 * @memberof module:mediawiki.page.ready.CheckboxHack
 * @param {HTMLInputElement} checkbox
 * @param {HTMLElement} button
 * @return {function(): void} Cleanup function that removes the added event listeners.
 */
function bindToggleOnSpaceEnter( checkbox, button ) {
	mw.log.warn( '[1.38] bindToggleOnSpaceEnter is deprecated. Use `bindToggleOnEnter` instead.' );

	function isEnterOrSpace( /** @type {KeyboardEvent} */ event ) {
		return event.key === ' ' || event.key === 'Enter';
	}

	function onKeydown( /** @type {KeyboardEvent} */ event ) {
		// Only handle SPACE and ENTER.
		if ( !isEnterOrSpace( event ) ) {
			return;
		}
		// Prevent the browser from scrolling when pressing space. The browser will
		// try to do this unless the "button" element is a button or a checkbox.
		// Depending on the actual "button" element, this also possibly prevents a
		// native click event from being triggered so we programatically trigger a
		// click event in the keyup handler.
		event.preventDefault();
	}

	function onKeyup( /** @type {KeyboardEvent} */ event ) {
		// Only handle SPACE and ENTER.
		if ( !isEnterOrSpace( event ) ) {
			return;
		}

		// A native button element triggers a click event when the space or enter
		// keys are pressed. Since the passed in "button" may or may not be a
		// button, programmatically trigger a click event to make it act like a
		// button.
		button.click();
	}

	button.addEventListener( 'keydown', onKeydown );
	button.addEventListener( 'keyup', onKeyup );

	return function () {
		button.removeEventListener( 'keydown', onKeydown );
		button.removeEventListener( 'keyup', onKeyup );
	};
}

/**
 * Manually change the checkbox state when the button is focused and Enter is pressed.
 *
 * @memberof module:mediawiki.page.ready.CheckboxHack
 * @param {HTMLInputElement} checkbox
 * @return {function(): void} Cleanup function that removes the added event listeners.
 */
function bindToggleOnEnter( checkbox ) {
	function onKeyup( /** @type {KeyboardEvent} */ event ) {
		// Only handle ENTER.
		if ( event.key !== 'Enter' ) {
			return;
		}

		setCheckedState( checkbox, !checkbox.checked );
	}

	checkbox.addEventListener( 'keyup', onKeyup );

	return function () {
		checkbox.removeEventListener( 'keyup', onKeyup );
	};
}

/**
 * Dismiss the target when clicking elsewhere and update the `aria-expanded` attribute based on
 * checkbox state (target visibility).
 *
 * @memberof module:mediawiki.page.ready.CheckboxHack
 * @param {window} window
 * @param {HTMLInputElement} checkbox
 * @param {HTMLElement} button
 * @param {Node} target
 * @return {function(): void} Cleanup function that removes the added event listeners.
 */
function bindDismissOnClickOutside( window, checkbox, button, target ) {
	const listener = dismissIfExternalEventTarget.bind( undefined, checkbox, button, target );
	window.addEventListener( 'click', listener, true );

	return function () {
		window.removeEventListener( 'click', listener, true );
	};
}

/**
 * Dismiss the target when focusing elsewhere and update the `aria-expanded` attribute based on
 * checkbox state (target visibility).
 *
 * @param {window} window
 * @param {HTMLInputElement} checkbox
 * @param {HTMLElement} button
 * @param {Node} target
 * @return {function(): void} Cleanup function that removes the added event listeners.
 * @memberof module:mediawiki.page.ready.CheckboxHack
 */
function bindDismissOnFocusLoss( window, checkbox, button, target ) {
	// If focus is given to any element outside the target, dismiss the target. Setting a focusout
	// listener on the target would be preferable, but this interferes with the click listener.
	const listener = dismissIfExternalEventTarget.bind( undefined, checkbox, button, target );
	window.addEventListener( 'focusin', listener, true );

	return function () {
		window.removeEventListener( 'focusin', listener, true );
	};
}

/**
 * Dismiss the target when clicking on a link to prevent the target from being open
 * when navigating to a new page.
 *
 * @param {HTMLInputElement} checkbox
 * @param {Node} target
 * @return {function(): void} Cleanup function that removes the added event listeners.
 * @memberof module:mediawiki.page.ready.CheckboxHack
 */
function bindDismissOnClickLink( checkbox, target ) {
	function dismissIfClickLinkEvent( event ) {
		// Handle clicks to links and link children elements
		if (
			// check that the element wasn't removed from the DOM.
			event.target && event.target.parentNode &&
			( event.target.nodeName === 'A' || event.target.parentNode.nodeName === 'A' )
		) {
			setCheckedState( checkbox, false );
		}
	}
	target.addEventListener( 'click', dismissIfClickLinkEvent );

	return function () {
		target.removeEventListener( 'click', dismissIfClickLinkEvent );
	};
}

/**
 * Dismiss the target when clicking or focusing elsewhere and update the `aria-expanded` attribute
 * based on checkbox state (target visibility) changes made by **the user.** When tapping the button
 * itself, clear the focus outline.
 *
 * This function calls the other bind* functions and is the only expected interaction for most use
 * cases. It's constituents are provided distinctly for the other use cases.
 *
 * @memberof module:mediawiki.page.ready.CheckboxHack
 * @param {window} window
 * @param {HTMLInputElement} checkbox The underlying hidden checkbox that controls target
 *   visibility.
 * @param {HTMLElement} button The visible label icon associated with the checkbox. This button
 *   toggles the state of the underlying checkbox.
 * @param {Node} target The Node to toggle visibility of based on checkbox state.
 * @return {function(): void} Cleanup function that removes the added event listeners.
 */
function bind( window, checkbox, button, target ) {
	const cleanups = [
		bindUpdateAriaExpandedOnInput( checkbox ),
		bindToggleOnClick( checkbox, button ),
		bindToggleOnEnter( checkbox ),
		bindDismissOnClickOutside( window, checkbox, button, target ),
		bindDismissOnFocusLoss( window, checkbox, button, target ),
		bindDismissOnClickLink( checkbox, target )
	];

	return function () {
		cleanups.forEach( ( cleanup ) => {
			cleanup();
		} );
	};
}

module.exports = {
	updateAriaExpanded,
	bindUpdateAriaExpandedOnInput,
	bindToggleOnClick,
	bindToggleOnSpaceEnter,
	bindToggleOnEnter,
	bindDismissOnClickOutside,
	bindDismissOnFocusLoss,
	bindDismissOnClickLink,
	bind
};
},"teleportTarget.js":function(require,module,exports){/**
 * @private
 * @class mw.plugin.page.ready
 */

const ID = 'mw-teleport-target';

const target = document.createElement( 'div' );
target.id = ID;

/**
 * Manages a dedicated container element for modals and dialogs.
 *
 * This creates an empty div and attaches it to the end of the body element.
 * This div can be used by Codex Dialogs and similar components that
 * may need to be displayed on the page.
 *
 * Skins should apply body content styles to this element so that
 * dialogs will use the same styles (font sizes, etc).
 *
 * @ignore
 * @return {Object}
 * @return {HTMLDivElement} return.target The div element
 * @return {Function} return.attach Call this function to attach the div to the <body>
 */
module.exports = {
	target,
	attach() {
		document.body.appendChild( target );
	}
};
},"toggleAllCollapsibles.js":function(require,module,exports){/*!
 * Add portlet link to toggle all collapsibles created by
 * the jquery.makeCollapsible module.
 */
let toggleAll;

mw.hook( 'wikipage.content' ).add( () => {
	// return early if the link was already added
	if ( toggleAll ) {
		return;
	}
	// return early if there are no collapsibles within the parsed page content
	if ( !document.querySelector( '#mw-content-text .mw-parser-output .mw-collapsible' ) ) {
		return;
	}

	// create portlet link for expand/collapse all
	const portletLink = mw.util.addPortletLink(
		'p-tb',
		'#',
		mw.msg( 'collapsible-expand-all-text' ),
		't-collapsible-toggle-all',
		mw.msg( 'collapsible-expand-all-tooltip' )
	);
	// return early if no link was added (e.g. no toolbox)
	if ( !portletLink ) {
		return;
	}

	// set up the toggle link
	toggleAll = portletLink.querySelector( 'a' );
	toggleAll.setAttribute( 'role', 'button' );

	// initially treat as collapsed
	toggleAll.setAttribute( 'aria-expanded', 'false' );
	let allExpanded = false;

	// on click, expand/collapse all collapsibles, then prepare to do the opposite on the next click
	toggleAll.addEventListener( 'click', ( e ) => {
		// Prevent scrolling
		e.preventDefault();
		// expand
		if ( !allExpanded ) {
			const collapsed = document.querySelectorAll( '#mw-content-text .mw-parser-output .mw-made-collapsible.mw-collapsed' );
			Array.prototype.forEach.call( collapsed, ( collapsible ) => {
				$( collapsible ).data( 'mw-collapsible' ).expand();
			} );
			toggleAll.textContent = mw.msg( 'collapsible-collapse-all-text' );
			toggleAll.title = mw.msg( 'collapsible-collapse-all-tooltip' );
			toggleAll.setAttribute( 'aria-expanded', 'true' );
			allExpanded = true;
		// collapse
		} else {
			const expanded = document.querySelectorAll( '#mw-content-text .mw-parser-output .mw-made-collapsible:not( .mw-collapsed )' );
			Array.prototype.forEach.call( expanded, ( collapsible ) => {
				$( collapsible ).data( 'mw-collapsible' ).collapse();
			} );
			toggleAll.textContent = mw.msg( 'collapsible-expand-all-text' );
			toggleAll.title = mw.msg( 'collapsible-expand-all-tooltip' );
			toggleAll.setAttribute( 'aria-expanded', 'false' );
			allExpanded = false;
		}
	} );
} );
},"config.json":{
    "search": false,
    "collapsible": true,
    "sortable": true,
    "selectorLogoutLink": "#pt-logout a[data-mw=\"interface\"]"
}}}];});
/**
 * Provides a {@link jQuery} plugin that creates a sortable table.
 *
 * Depends on mw.config (wgDigitTransformTable, wgDefaultDateFormat, wgPageViewLanguage)
 * and {@link mw.language.months}.
 *
 * Uses 'tableSorterCollation' in {@link mw.config} (if available).
 *
 * @module jquery.tablesorter
 * @author Written 2011 Leo Koppelkamm. Based on tablesorter.com plugin, written (c) 2007 Christian Bach/christian.bach@polyester.se
 * @license Dual licensed under the MIT (http://www.opensource.org/licenses/mit-license.php) and  GPL (http://www.gnu.org/licenses/gpl.html) licenses
 */
/**
 * @typedef {Object} module:jquery.tablesorter~TableSorterOptions
 * @property {string} [cssHeader="headerSort"] A string of the class name to be appended to sortable
 *         tr elements in the thead of the table.
 * @property {string} [cssAsc="headerSortUp"] A string of the class name to be appended to
 *         sortable tr elements in the thead on a ascending sort.
 * @property {string} [cssDesc="headerSortDown"] A string of the class name to be appended to
 *         sortable tr elements in the thead on a descending sort.
 * @property {string} [sortMultisortKey="shiftKey"] A string of the multi-column sort key.
 * @property {boolean} [cancelSelection=true] Boolean flag indicating iftablesorter should cancel
 *         selection of the table headers text.
 * @property {Array} [sortList] An array containing objects specifying sorting. By passing more
 *         than one object, multi-sorting will be applied. Object structure:
 *         { <Integer column index>: <String 'asc' or 'desc'> }
 */
( function () {
	const parsers = [];
	let ts = null;

	/* Parser utility functions */

	function getParserById( name ) {
		for ( let i = 0; i < parsers.length; i++ ) {
			if ( parsers[ i ].id.toLowerCase() === name.toLowerCase() ) {
				return parsers[ i ];
			}
		}
		return false;
	}

	/**
	 * @param {HTMLElement} node
	 * @return {string}
	 */
	function getElementSortKey( node ) {
		// Browse the node to build the raw sort key, which will then be normalized.
		function buildRawSortKey( currentNode ) {
			// Get data-sort-value attribute. Uses jQuery to allow live value
			// changes from other code paths via data(), which reside only in jQuery.
			// Must use $().data() instead of $.data(), as the latter *only*
			// accesses the live values, without reading HTML5 attribs first (T40152).
			const data = $( currentNode ).data( 'sortValue' );

			if ( data !== null && data !== undefined ) {
				// Cast any numbers or other stuff to a string. Methods
				// like charAt, toLowerCase and split are expected in callers.
				return String( data );
			}

			// Iterate the NodeList (not an array).
			// Also uses null-return as filter in the same pass.
			// eslint-disable-next-line no-jquery/no-map-util
			return $.map( currentNode.childNodes, ( elem ) => {
				if ( elem.nodeType === Node.ELEMENT_NODE ) {
					const nodeName = elem.nodeName.toLowerCase();
					if ( nodeName === 'img' ) {
						return elem.alt;
					}
					if ( nodeName === 'br' ) {
						return ' ';
					}
					if ( nodeName === 'style' ) {
						return null;
					}
					if ( elem.classList.contains( 'reference' ) ) {
						return null;
					}
					return buildRawSortKey( elem );
				}
				if ( elem.nodeType === Node.TEXT_NODE ) {
					return elem.textContent;
				}
				// Ignore other node types, such as HTML comments.
				return null;
			} ).join( '' );
		}

		return buildRawSortKey( node ).replace( /  +/g, ' ' ).trim();
	}

	function detectParserForColumn( table, rows, column ) {
		const l = parsers.length,
			config = $( table ).data( 'tablesorter' ).config,
			needed = ( rows.length > 4 ) ? 5 : rows.length;
		// Start with 1 because 0 is the fallback parser
		let i = 1,
			nextRow = false,
			lastRowIndex = -1,
			rowIndex = 0,
			concurrent = 0,
			empty = 0;

		let nodeValue;
		while ( i < l ) {
			// if this is a child row, continue to the next row (as buildCache())
			// eslint-disable-next-line no-jquery/no-class-state
			if ( rows[ rowIndex ] && !$( rows[ rowIndex ] ).hasClass( config.cssChildRow ) ) {
				if ( rowIndex !== lastRowIndex ) {
					lastRowIndex = rowIndex;
					const cellIndex = $( rows[ rowIndex ] ).data( 'columnToCell' )[ column ];
					nodeValue = getElementSortKey( rows[ rowIndex ].cells[ cellIndex ] );
				}
			} else {
				nodeValue = '';
			}

			if ( nodeValue !== '' ) {
				if ( parsers[ i ].is( nodeValue, table ) ) {
					concurrent++;
					nextRow = true;
					if ( concurrent >= needed ) {
						// Confirmed the parser for multiple cells, let's return it
						return parsers[ i ];
					}
				} else {
					// Check next parser, reset rows
					i++;
					rowIndex = 0;
					concurrent = 0;
					empty = 0;
					nextRow = false;
				}
			} else {
				// Empty cell
				empty++;
				nextRow = true;
			}

			if ( nextRow ) {
				nextRow = false;
				rowIndex++;
				if ( rowIndex >= rows.length ) {
					if ( concurrent > 0 && concurrent >= rows.length - empty ) {
						// Confirmed the parser for all filled cells
						return parsers[ i ];
					}
					// Check next parser, reset rows
					i++;
					rowIndex = 0;
					concurrent = 0;
					empty = 0;
				}
			}
		}

		// 0 is always the generic parser (text)
		return parsers[ 0 ];
	}

	function buildParserCache( table, $headers ) {
		const rows = table.tBodies[ 0 ].rows,
			config = $( table ).data( 'tablesorter' ).config,
			cachedParsers = [];

		if ( rows[ 0 ] ) {
			for ( let j = 0; j < config.columns; j++ ) {
				let parser = false;
				const sortType = $headers.eq( config.columnToHeader[ j ] ).data( 'sortType' );
				if ( sortType !== undefined ) {
					// Cast any numbers or other stuff to a string. Methods
					// like charAt, toLowerCase and split are expected in callers.
					parser = getParserById( String( sortType ) );
				}

				if ( parser === false ) {
					parser = detectParserForColumn( table, rows, j );
				}

				cachedParsers.push( parser );
			}
		}
		return cachedParsers;
	}

	/* Other utility functions */

	function buildCache( table ) {
		const totalRows = ( table.tBodies[ 0 ] && table.tBodies[ 0 ].rows.length ) || 0,
			config = $( table ).data( 'tablesorter' ).config,
			cachedParsers = config.parsers,
			cache = {
				row: [],
				normalized: []
			};

		for ( let i = 0; i < totalRows; i++ ) {

			// Add the table data to main data array
			const $row = $( table.tBodies[ 0 ].rows[ i ] );
			let cols = [];

			// if this is a child row, add it to the last row's children and
			// continue to the next row
			// eslint-disable-next-line no-jquery/no-class-state
			if ( $row.hasClass( config.cssChildRow ) ) {
				cache.row[ cache.row.length - 1 ] = cache.row[ cache.row.length - 1 ].add( $row );
				// go to the next for loop
				continue;
			}

			cache.row.push( $row );

			if ( $row.data( 'initialOrder' ) === undefined ) {
				$row.data( 'initialOrder', i );
			}

			for ( let j = 0; j < cachedParsers.length; j++ ) {
				const cellIndex = $row.data( 'columnToCell' )[ j ];
				cols.push( cachedParsers[ j ].format( getElementSortKey( $row[ 0 ].cells[ cellIndex ] ) ) );
			}

			// Store the initial sort order, from when the page was loaded
			cols.push( $row.data( 'initialOrder' ) );

			// Store the current sort order, before rows are re-sorted
			cols.push( cache.normalized.length );

			cache.normalized.push( cols );
			cols = null;
		}

		return cache;
	}

	function appendToTable( table, cache ) {
		const row = cache.row,
			normalized = cache.normalized,
			totalRows = normalized.length,
			checkCell = ( normalized[ 0 ].length - 1 ),
			fragment = document.createDocumentFragment();

		for ( let i = 0; i < totalRows; i++ ) {
			const pos = normalized[ i ][ checkCell ];

			const l = row[ pos ].length;
			for ( let j = 0; j < l; j++ ) {
				fragment.appendChild( row[ pos ][ j ] );
			}

		}
		table.tBodies[ 0 ].appendChild( fragment );

		$( table ).trigger( 'sortEnd.tablesorter' );
	}

	/**
	 * Find all header rows in a thead-less table and put them in a <thead> tag.
	 * This only treats a row as a header row if it contains only <th>s (no <td>s)
	 * and if it is preceded entirely by header rows. The algorithm stops when
	 * it encounters the first non-header row.
	 *
	 * After this, it will look at all rows at the bottom for footer rows
	 * And place these in a tfoot using similar rules.
	 *
	 * @param {jQuery} $table object for a <table>
	 */
	function emulateTHeadAndFoot( $table ) {
		const $rows = $table.find( '> tbody > tr' );

		if ( !$table.get( 0 ).tHead ) {
			const $thead = $( '<thead>' );
			$rows.each( function () {
				if ( $( this ).children( 'td' ).length ) {
					// This row contains a <td>, so it's not a header row
					// Stop here
					return false;
				}
				$thead.append( this );
			} );
			$table.find( '> tbody' ).first().before( $thead );
		}
		if ( !$table.get( 0 ).tFoot ) {
			const $tfoot = $( '<tfoot>' );
			let tfootRows = [],
				remainingCellRowSpan = 0;

			$rows.each( function () {
				$( this ).children( 'td' ).each( function () {
					remainingCellRowSpan = Math.max( this.rowSpan, remainingCellRowSpan );
				} );

				if ( remainingCellRowSpan > 0 ) {
					tfootRows = [];
					remainingCellRowSpan--;
				} else {
					tfootRows.push( this );
				}
			} );

			$tfoot.append( tfootRows );
			$table.append( $tfoot );
		}
	}

	function uniqueElements( array ) {
		const uniques = [];
		array.forEach( ( elem ) => {
			if ( elem !== undefined && uniques.indexOf( elem ) === -1 ) {
				uniques.push( elem );
			}
		} );
		return uniques;
	}

	function buildHeaders( table, msg ) {
		const config = $( table ).data( 'tablesorter' ).config,
			$tableRows = $( table ).find( 'thead' ).eq( 0 ).find( '> tr:not(.sorttop)' );
		let $tableHeaders = $( [] );

		let maxSeen = 0,
			colspanOffset = 0;

		if ( $tableRows.length <= 1 ) {
			$tableHeaders = $tableRows.children( 'th' );
		} else {
			const exploded = [];

			// Loop through all the dom cells of the thead
			$tableRows.each( ( rowIndex, row ) => {
				// eslint-disable-next-line no-jquery/no-each-util
				$.each( row.cells, ( columnIndex, cell ) => {
					const rowspan = Number( cell.rowSpan );
					const colspan = Number( cell.colSpan );

					// Skip the spots in the exploded matrix that are already filled
					while ( exploded[ rowIndex ] && exploded[ rowIndex ][ columnIndex ] !== undefined ) {
						++columnIndex;
					}

					let matrixRowIndex,
						matrixColumnIndex;
					// Find the actual dimensions of the thead, by placing each cell
					// in the exploded matrix rowspan times colspan times, with the proper offsets
					for ( matrixColumnIndex = columnIndex; matrixColumnIndex < columnIndex + colspan; ++matrixColumnIndex ) {
						for ( matrixRowIndex = rowIndex; matrixRowIndex < rowIndex + rowspan; ++matrixRowIndex ) {
							if ( !exploded[ matrixRowIndex ] ) {
								exploded[ matrixRowIndex ] = [];
							}
							exploded[ matrixRowIndex ][ matrixColumnIndex ] = cell;
						}
					}
				} );
			} );
			let longestTR;
			// We want to find the row that has the most columns (ignoring colspan)
			exploded.forEach( ( cellArray, index ) => {
				const headerCount = $( uniqueElements( cellArray ) ).filter( 'th' ).length;
				if ( headerCount >= maxSeen ) {
					maxSeen = headerCount;
					longestTR = index;
				}
			} );
			// We cannot use $.unique() here because it sorts into dom order, which is undesirable
			$tableHeaders = $( uniqueElements( exploded[ longestTR ] ) ).filter( 'th' );
		}

		// as each header can span over multiple columns (using colspan=N),
		// we have to bidirectionally map headers to their columns and columns to their headers
		config.columnToHeader = [];
		config.headerToColumns = [];
		config.headerList = [];
		let headerIndex = 0;
		$tableHeaders.each( function () {
			const $cell = $( this );
			const columns = [];

			// eslint-disable-next-line no-jquery/no-class-state
			if ( !$cell.hasClass( config.unsortableClass ) ) {
				$cell
					// The following classes are used here:
					// * headerSort
					// * other passed by config
					.addClass( config.cssHeader )
					.prop( 'tabIndex', 0 )
					.attr( {
						role: 'columnheader button',
						title: msg[ 2 ]
					} );

				for ( let k = 0; k < this.colSpan; k++ ) {
					config.columnToHeader[ colspanOffset + k ] = headerIndex;
					columns.push( colspanOffset + k );
				}

				config.headerToColumns[ headerIndex ] = columns;

				$cell.data( {
					headerIndex: headerIndex,
					order: 0,
					count: 0
				} );

				// add only sortable cells to headerList
				config.headerList[ headerIndex ] = this;
				headerIndex++;
			}

			colspanOffset += this.colSpan;
		} );

		// number of columns with extended colspan, inclusive unsortable
		// parsers[j], cache[][j], columnToHeader[j], columnToCell[j] have so many elements
		config.columns = colspanOffset;

		return $tableHeaders.not( '.' + config.unsortableClass );
	}

	function isValueInArray( v, a ) {
		for ( let i = 0; i < a.length; i++ ) {
			if ( a[ i ][ 0 ] === v ) {
				return true;
			}
		}
		return false;
	}

	/**
	 * Sets the sort count of the columns that are not affected by the sorting to have them sorted
	 * in default (ascending) order when their header cell is clicked the next time.
	 *
	 * @param {jQuery} $headers
	 * @param {Array} sortList 2D number array
	 * @param {Array} headerToColumns 2D number array
	 */
	function setHeadersOrder( $headers, sortList, headerToColumns ) {
		// Loop through all headers to retrieve the indices of the columns the header spans across:
		headerToColumns.forEach( ( columns, headerIndex ) => {

			columns.forEach( ( columnIndex, i ) => {
				const header = $headers[ headerIndex ],
					$header = $( header );

				if ( !isValueInArray( columnIndex, sortList ) ) {
					// Column shall not be sorted: Reset header count and order.
					$header.data( {
						order: 0,
						count: 0
					} );
				} else {
					// Column shall be sorted: Apply designated count and order.
					for ( let j = 0; j < sortList.length; j++ ) {
						const sortColumn = sortList[ j ];
						if ( sortColumn[ 0 ] === i ) {
							$header.data( {
								order: sortColumn[ 1 ],
								count: sortColumn[ 1 ] + 1
							} );
							break;
						}
					}
				}
			} );

		} );
	}

	function setHeadersCss( table, $headers, list, css, msg, columnToHeader ) {
		// Remove all header information and reset titles to default message
		// The following classes are used here:
		// * headerSortUp
		// * headerSortDown
		$headers.removeClass( css ).attr( 'title', msg[ 2 ] );

		for ( let i = 0; i < list.length; i++ ) {
			// The following classes are used here:
			// * headerSortUp
			// * headerSortDown
			$headers
				.eq( columnToHeader[ list[ i ][ 0 ] ] )
				.addClass( css[ list[ i ][ 1 ] ] )
				.attr( 'title', msg[ list[ i ][ 1 ] ] );
		}
	}

	function sortText( a, b ) {
		return ts.collator.compare( a, b );
	}

	function sortNumeric( a, b ) {
		return ( ( a < b ) ? -1 : ( ( a > b ) ? 1 : 0 ) );
	}

	function multisort( table, sortList, cache ) {
		const sortFn = [],
			cachedParsers = $( table ).data( 'tablesorter' ).config.parsers;

		for ( let i = 0; i < sortList.length; i++ ) {
			// Android doesn't support Intl.Collator
			if ( window.Intl && Intl.Collator && cachedParsers[ sortList[ i ][ 0 ] ].type === 'text' ) {
				sortFn[ i ] = sortText;
			} else {
				sortFn[ i ] = sortNumeric;
			}
		}
		cache.normalized.sort( function ( array1, array2 ) {
			for ( let n = 0; n < sortList.length; n++ ) {
				const col = sortList[ n ][ 0 ];
				let ret;
				if ( sortList[ n ][ 1 ] === 2 ) {
					// initial order
					const orderIndex = array1.length - 2;
					ret = sortNumeric.call( this, array1[ orderIndex ], array2[ orderIndex ] );
				} else if ( sortList[ n ][ 1 ] === 1 ) {
					// descending
					ret = sortFn[ n ].call( this, array2[ col ], array1[ col ] );
				} else {
					// ascending
					ret = sortFn[ n ].call( this, array1[ col ], array2[ col ] );
				}
				if ( ret !== 0 ) {
					return ret;
				}
			}
			// Fall back to index number column to ensure stable sort
			return sortText.call( this, array1[ array1.length - 1 ], array2[ array2.length - 1 ] );
		} );
		return cache;
	}

	function buildTransformTable() {
		const digits = '0123456789,.'.split( '' ),
			separatorTransformTable = mw.config.get( 'wgSeparatorTransformTable' ),
			digitTransformTable = mw.config.get( 'wgDigitTransformTable' );

		if ( separatorTransformTable === null || ( separatorTransformTable[ 0 ] === '' && digitTransformTable[ 2 ] === '' ) ) {
			ts.transformTable = false;
		} else {
			ts.transformTable = {};

			// Unpack the transform table
			const ascii = separatorTransformTable[ 0 ].split( '\t' ).concat( digitTransformTable[ 0 ].split( '\t' ) );
			const localised = separatorTransformTable[ 1 ].split( '\t' ).concat( digitTransformTable[ 1 ].split( '\t' ) );

			// Construct regexes for number identification
			for ( let i = 0; i < ascii.length; i++ ) {
				ts.transformTable[ localised[ i ] ] = ascii[ i ];
				digits.push( mw.util.escapeRegExp( localised[ i ] ) );
			}
		}
		const digitClass = '[' + digits.join( '', digits ) + ']';

		// We allow a trailing percent sign, which we just strip. This works fine
		// if percents and regular numbers aren't being mixed.

		ts.numberRegex = new RegExp(
			'^(' +
				'[-+\u2212]?[0-9][0-9,]*(\\.[0-9,]*)?(E[-+\u2212]?[0-9][0-9,]*)?' + // Fortran-style scientific
				'|' +
				'[-+\u2212]?' + digitClass + '+[\\s\\xa0]*%?' + // Generic localised
			')$',
			'i'
		);
	}

	function buildDateTable() {
		let regex = [];

		ts.monthNames = {};

		for ( let i = 0; i < 12; i++ ) {
			let name = mw.language.months.names[ i ].toLowerCase();
			ts.monthNames[ name ] = i + 1;
			regex.push( mw.util.escapeRegExp( name ) );
			name = mw.language.months.genitive[ i ].toLowerCase();
			ts.monthNames[ name ] = i + 1;
			regex.push( mw.util.escapeRegExp( name ) );
			name = mw.language.months.abbrev[ i ].toLowerCase().replace( '.', '' );
			ts.monthNames[ name ] = i + 1;
			regex.push( mw.util.escapeRegExp( name ) );
		}

		// Build piped string
		regex = regex.join( '|' );

		// Build RegEx
		// Any date formated with . , ' - or /
		ts.dateRegex[ 0 ] = new RegExp( /^\s*(\d{1,2})[,.\-/'\s]{1,2}(\d{1,2})[,.\-/'\s]{1,2}(\d{2,4})\s*?/i );

		// Written Month name, dmy

		ts.dateRegex[ 1 ] = new RegExp(
			'^\\s*(\\d{1,2})[\\,\\.\\-\\/\'º\\s]+(' +
				regex +
			')' +
			'[\\,\\.\\-\\/\'\\s]+(\\d{2,4})\\s*$',
			'i'
		);

		// Written Month name, mdy

		ts.dateRegex[ 2 ] = new RegExp(
			'^\\s*(' + regex + ')' +
			'[\\,\\.\\-\\/\'\\s]+(\\d{1,2})[\\,\\.\\-\\/\'\\s]+(\\d{2,4})\\s*$',
			'i'
		);

	}

	/**
	 * Replace all rowspanned cells in the body with clones in each row, so sorting
	 * need not worry about them.
	 *
	 * @param {jQuery} $table jQuery object for a <table>
	 */
	function explodeRowspans( $table ) {
		let spanningRealCellIndex, colSpan,
			rowspanCells = $table.find( '> tbody > tr > [rowspan]' ).get();

		// Short circuit
		if ( !rowspanCells.length ) {
			return;
		}

		// First, we need to make a property like cellIndex but taking into
		// account colspans. We also cache the rowIndex to avoid having to take
		// cell.parentNode.rowIndex in the sorting function below.
		$table.find( '> tbody > tr' ).each( function () {
			let col = 0;
			for ( let c = 0; c < this.cells.length; c++ ) {
				$( this.cells[ c ] ).data( 'tablesorter', {
					realCellIndex: col,
					realRowIndex: this.rowIndex
				} );
				col += this.cells[ c ].colSpan;
			}
		} );

		// Split multi row cells into multiple cells with the same content.
		// Sort by column then row index to avoid problems with odd table structures.
		// Re-sort whenever a rowspanned cell's realCellIndex is changed, because it
		// might change the sort order.
		function resortCells() {
			rowspanCells = rowspanCells.sort( ( a, b ) => {
				const cellAData = $.data( a, 'tablesorter' );
				const cellBData = $.data( b, 'tablesorter' );
				let ret = cellAData.realCellIndex - cellBData.realCellIndex;
				if ( !ret ) {
					ret = cellAData.realRowIndex - cellBData.realRowIndex;
				}
				return ret;
			} );
			rowspanCells.forEach( ( cellNode ) => {
				$.data( cellNode, 'tablesorter' ).needResort = false;
			} );
		}
		resortCells();

		function filterfunc() {
			return $.data( this, 'tablesorter' ).realCellIndex >= spanningRealCellIndex;
		}

		function fixTdCellIndex() {
			$.data( this, 'tablesorter' ).realCellIndex += colSpan;
			if ( this.rowSpan > 1 ) {
				$.data( this, 'tablesorter' ).needResort = true;
			}
		}

		while ( rowspanCells.length ) {
			if ( $.data( rowspanCells[ 0 ], 'tablesorter' ).needResort ) {
				resortCells();
			}

			const cell = rowspanCells.shift();
			const cellData = $.data( cell, 'tablesorter' );
			const rowSpan = cell.rowSpan;
			colSpan = cell.colSpan;
			spanningRealCellIndex = cellData.realCellIndex;
			cell.rowSpan = 1;
			const $nextRows = $( cell ).parent().nextAll();

			for ( let i = 0; i < rowSpan - 1; i++ ) {
				const row = $nextRows[ i ];
				if ( !row ) {
					// Badly formatted HTML for table.
					// Ignore this row, but leave a warning for someone to be able to find this.
					// Perhaps in future this could be a wikitext linter rule, or preview warning
					// on the edit page.
					mw.log.warn( mw.message( 'sort-rowspan-error' ).plain() );
					break;
				}
				const $tds = $( row.cells ).filter( filterfunc );
				const $clone = $( cell ).clone();
				$clone.data( 'tablesorter', {
					realCellIndex: spanningRealCellIndex,
					realRowIndex: cellData.realRowIndex + i,
					needResort: true
				} );
				if ( $tds.length ) {
					$tds.each( fixTdCellIndex );
					$tds.first().before( $clone );
				} else {
					$nextRows.eq( i ).append( $clone );
				}
			}
		}
	}

	/**
	 * Build index to handle colspanned cells in the body.
	 * Set the cell index for each column in an array,
	 * so that colspaned cells set multiple in this array.
	 * columnToCell[collumnIndex] point at the real cell in this row.
	 *
	 * @param {jQuery} $table object for a <table>
	 */
	function manageColspans( $table ) {
		const $rows = $table.find( '> tbody > tr' ),
			totalRows = $rows.length || 0,
			config = $table.data( 'tablesorter' ).config,
			columns = config.columns;

		for ( let i = 0; i < totalRows; i++ ) {

			const $row = $rows.eq( i );
			// if this is a child row, continue to the next row (as buildCache())
			// eslint-disable-next-line no-jquery/no-class-state
			if ( $row.hasClass( config.cssChildRow ) ) {
				// go to the next for loop
				continue;
			}

			const columnToCell = [];
			let cellsInRow = ( $row[ 0 ].cells.length ) || 0; // all cells in this row
			let index = 0; // real cell index in this row
			for ( let j = 0; j < columns; index++ ) {
				if ( index === cellsInRow ) {
					// Row with cells less than columns: add empty cell
					$row.append( '<td>' );
					cellsInRow++;
				}
				for ( let k = 0; k < $row[ 0 ].cells[ index ].colSpan; k++ ) {
					columnToCell[ j++ ] = index;
				}
			}
			// Store it in $row
			$row.data( 'columnToCell', columnToCell );
		}
	}

	function buildCollation() {
		const keys = [];
		ts.collationTable = mw.config.get( 'tableSorterCollation' );
		ts.collationRegex = null;
		if ( ts.collationTable ) {
			// Build array of key names
			for ( const key in ts.collationTable ) {
				keys.push( mw.util.escapeRegExp( key ) );
			}
			if ( keys.length ) {

				ts.collationRegex = new RegExp( keys.join( '|' ), 'ig' );
			}
		}
		if ( window.Intl && Intl.Collator ) {
			ts.collator = new Intl.Collator( [
				mw.config.get( 'wgPageViewLanguage' ),
				mw.config.get( 'wgUserLanguage' )
			], {
				numeric: true
			} );
		}
	}

	function cacheRegexs() {
		if ( ts.rgx ) {
			return;
		}
		ts.rgx = {
			IPAddress: [
				new RegExp( /^\d{1,3}[.]\d{1,3}[.]\d{1,3}[.]\d{1,3}$/ )
			],
			currency: [
				new RegExp( /(^[£$€¥]|[£$€¥]$)/ ),
				new RegExp( /[£$€¥]/g )
			],
			usLongDate: [
				new RegExp( /^[A-Za-z]{3,10}\.? [0-9]{1,2}, ([0-9]{4}|'?[0-9]{2}) (([0-2]?[0-9]:[0-5][0-9])|([0-1]?[0-9]:[0-5][0-9]\s(AM|PM)))$/ )
			],
			time: [
				new RegExp( /^(([0-2]?[0-9]:[0-5][0-9])|([0-1]?[0-9]:[0-5][0-9]\s(am|pm)))$/ )
			]
		};
	}

	/**
	 * Converts sort objects [ { Integer: String }, ... ] to the internally used nested array
	 * structure [ [ Integer, Integer ], ... ]
	 *
	 * @param {Array} sortObjects List of sort objects.
	 * @return {Array} List of internal sort definitions.
	 */
	function convertSortList( sortObjects ) {
		const sortList = [];
		sortObjects.forEach( ( sortObject ) => {
			// eslint-disable-next-line no-jquery/no-each-util
			$.each( sortObject, ( columnIndex, order ) => {
				const orderIndex = ( order === 'desc' ) ? 1 : 0;
				sortList.push( [ parseInt( columnIndex, 10 ), orderIndex ] );
			} );
		} );
		return sortList;
	}

	/* Public scope */

	$.tablesorter = {
		defaultOptions: {
			cssHeader: 'headerSort',
			cssAsc: 'headerSortUp',
			cssDesc: 'headerSortDown',
			cssInitial: '',
			cssChildRow: 'expand-child',
			sortMultiSortKey: 'shiftKey',
			unsortableClass: 'unsortable',
			parsers: [],
			cancelSelection: true,
			sortList: [],
			headerList: [],
			headerToColumns: [],
			columnToHeader: [],
			columns: 0
		},

		dateRegex: [],
		monthNames: {},

		/**
		 * @param {jQuery} $tables
		 * @param {Object} [settings]
		 * @return {jQuery}
		 */
		construct: function ( $tables, settings ) {
			return $tables.each( ( i, table ) => {
				// Declare and cache.
				let cache,
					firstTime = true;
				const $table = $( table );

				// Don't construct twice on the same table
				if ( $.data( table, 'tablesorter' ) ) {
					return;
				}
				// Quit if no tbody
				if ( !table.tBodies ) {
					return;
				}
				if ( !table.tHead ) {
					// No thead found. Look for rows with <th>s and
					// move them into a <thead> tag or a <tfoot> tag
					emulateTHeadAndFoot( $table );

					// Still no thead? Then quit
					if ( !table.tHead ) {
						return;
					}
				}
				// The `sortable` class is used to identify tables which will become sortable
				// If not used it will create a FOUC but it should be added since the sortable class
				// is responsible for certain crucial style elements. If the class is already present
				// this action will be harmless.
				$table.addClass( 'jquery-tablesorter sortable' );

				// Merge and extend
				const config = Object.assign( {}, $.tablesorter.defaultOptions, settings );

				// Save the settings where they read
				$.data( table, 'tablesorter', { config: config } );

				// Get the CSS class names, could be done elsewhere
				const sortCSS = [ config.cssAsc, config.cssDesc, config.cssInitial ];
				// Messages tell the user what the *next* state will be
				// so are shifted by one relative to the CSS classes.
				const sortMsg = [ mw.msg( 'sort-descending' ), mw.msg( 'sort-initial' ), mw.msg( 'sort-ascending' ) ];

				// Build headers
				const $headers = buildHeaders( table, sortMsg );

				// Grab and process locale settings.
				buildTransformTable();
				buildDateTable();

				// Precaching regexps can bring 10 fold
				// performance improvements in some browsers.
				cacheRegexs();

				function setupForFirstSort() {
					firstTime = false;

					// Defer buildCollationTable to first sort. As user and site scripts
					// may customize tableSorterCollation but load after $.ready(), other
					// scripts may call .tablesorter() before they have done the
					// tableSorterCollation customizations.
					buildCollation();

					// Move .sortbottom rows to the <tfoot> at the bottom of the <table>
					const $sortbottoms = $table.find( '> tbody > tr.sortbottom' );
					if ( $sortbottoms.length ) {
						const $tfoot = $table.children( 'tfoot' );
						if ( $tfoot.length ) {
							$tfoot.eq( 0 ).prepend( $sortbottoms );
						} else {
							$table.append( $( '<tfoot>' ).append( $sortbottoms ) );
						}
					}

					// Move .sorttop rows to the <thead> at the top of the <table>
					// <thead> should exist if we got this far
					const $sorttops = $table.find( '> tbody > tr.sorttop' );
					if ( $sorttops.length ) {
						$table.children( 'thead' ).append( $sorttops );
					}

					explodeRowspans( $table );
					manageColspans( $table );

					// Try to auto detect column type, and store in tables config
					config.parsers = buildParserCache( table, $headers );
				}

				// Apply event handling to headers
				// this is too big, perhaps break it out?
				$headers.on( 'keypress click', function ( e ) {
					if ( e.type === 'click' && e.target.nodeName.toLowerCase() === 'a' ) {
						// The user clicked on a link inside a table header.
						// Do nothing and let the default link click action continue.
						return true;
					}

					if ( e.type === 'keypress' && e.which !== 13 ) {
						// Only handle keypresses on the "Enter" key.
						return true;
					}

					if ( firstTime ) {
						setupForFirstSort();
					}

					// Build the cache for the tbody cells
					// to share between calculations for this sort action.
					// Re-calculated each time a sort action is performed due to possibility
					// that sort values change. Shouldn't be too expensive, but if it becomes
					// too slow an event based system should be implemented somehow where
					// cells get event .change() and bubbles up to the <table> here
					cache = buildCache( table );

					const totalRows = ( $table[ 0 ].tBodies[ 0 ] && $table[ 0 ].tBodies[ 0 ].rows.length ) || 0;
					if ( totalRows > 0 ) {
						const cell = this;
						const $cell = $( cell );
						const numSortOrders = 3;

						// Get current column sort order
						$cell.data( {
							order: $cell.data( 'count' ) % numSortOrders,
							count: $cell.data( 'count' ) + 1
						} );

						// Get current column index
						const columns = config.headerToColumns[ $cell.data( 'headerIndex' ) ];
						const newSortList = columns.map( ( c ) => [ c, $cell.data( 'order' ) ] );
						// Index of first column belonging to this header
						const col = columns[ 0 ];

						if ( !e[ config.sortMultiSortKey ] ) {
							// User only wants to sort on one column set
							// Flush the sort list and add new columns
							config.sortList = newSortList;
						} else {
							// Multi column sorting
							// It is not possible for one column to belong to multiple headers,
							// so this is okay - we don't need to check for every value in the columns array
							if ( isValueInArray( col, config.sortList ) ) {
								// The user has clicked on an already sorted column.
								// Reverse the sorting direction for all tables.
								for ( let j = 0; j < config.sortList.length; j++ ) {
									const s = config.sortList[ j ];
									const o = config.headerList[ config.columnToHeader[ s[ 0 ] ] ];
									if ( isValueInArray( s[ 0 ], newSortList ) ) {
										$( o ).data( 'count', s[ 1 ] + 1 );
										s[ 1 ] = $( o ).data( 'count' ) % numSortOrders;
									}
								}
							} else {
								// Add columns to sort list array
								config.sortList = config.sortList.concat( newSortList );
							}
						}

						// Reset order/counts of cells not affected by sorting
						setHeadersOrder( $headers, config.sortList, config.headerToColumns );

						// Set CSS for headers
						setHeadersCss( $table[ 0 ], $headers, config.sortList, sortCSS, sortMsg, config.columnToHeader );
						appendToTable(
							$table[ 0 ], multisort( $table[ 0 ], config.sortList, cache )
						);

						// Stop normal event by returning false
						return false;
					}

				// Cancel selection
				} ).on( 'mousedown', function () {
					if ( config.cancelSelection ) {
						this.onselectstart = function () {
							return false;
						};
						return false;
					}
				} );

				/**
				 * Sorts the table. If no sorting is specified by passing a list of sort
				 * objects, the table is sorted according to the initial sorting order.
				 * Passing an empty array will reset sorting (basically just reset the headers
				 * making the table appear unsorted).
				 *
				 * @param {Array} [sortList] List of sort objects.
				 * @ignore
				 */
				$table.data( 'tablesorter' ).sort = function ( sortList ) {

					if ( firstTime ) {
						setupForFirstSort();
					}

					if ( sortList === undefined ) {
						sortList = config.sortList;
					} else if ( sortList.length > 0 ) {
						sortList = convertSortList( sortList );
					}

					// Set each column's sort count to be able to determine the correct sort
					// order when clicking on a header cell the next time
					setHeadersOrder( $headers, sortList, config.headerToColumns );

					// re-build the cache for the tbody cells
					cache = buildCache( table );

					// set css for headers
					setHeadersCss( table, $headers, sortList, sortCSS, sortMsg, config.columnToHeader );

					// sort the table and append it to the dom
					appendToTable( table, multisort( table, sortList, cache ) );
				};

				// sort initially
				if ( config.sortList.length > 0 ) {
					config.sortList = convertSortList( config.sortList );
					$table.data( 'tablesorter' ).sort();
				}

			} );
		},

		addParser: function ( parser ) {
			if ( !getParserById( parser.id ) ) {
				parsers.push( parser );
			}
		},

		formatDigit: function ( s ) {
			if ( ts.transformTable !== false ) {
				let out = '';
				for ( let p = 0; p < s.length; p++ ) {
					const c = s.charAt( p );
					if ( c in ts.transformTable ) {
						out += ts.transformTable[ c ];
					} else {
						out += c;
					}
				}
				s = out;
			}
			const i = parseFloat( s.replace( /[, ]/g, '' ).replace( '\u2212', '-' ) );
			return isNaN( i ) ? -Infinity : i;
		},

		formatFloat: function ( s ) {
			const i = parseFloat( s );
			return isNaN( i ) ? -Infinity : i;
		},

		formatInt: function ( s ) {
			const i = parseInt( s, 10 );
			return isNaN( i ) ? -Infinity : i;
		},

		clearTableBody: function ( table ) {
			$( table.tBodies[ 0 ] ).empty();
		},

		getParser: function ( id ) {
			buildTransformTable();
			buildDateTable();
			cacheRegexs();
			buildCollation();

			return getParserById( id );
		},

		getParsers: function () { // for table diagnosis
			return parsers;
		}
	};

	// Shortcut
	ts = $.tablesorter;

	// Register as jQuery prototype method
	/**
	 * Create a sortable table with multi-column sorting capabilities.
	 *
	 * To use this {@link jQuery} plugin, load the `jquery.tablesorter` module with {@link mw.loader}.
	 *
	 * @memberof module:jquery.tablesorter
	 * @example
	 * mw.loader.using( 'jquery.tablesorter' ).then( () => {
	 *      // Create a simple tablesorter interface
	 *      $( 'table' ).tablesorter();
	 *
	 *      // Create a tablesorter interface, initially sorting on the first and second column
	 *      $( 'table' ).tablesorter( { sortList: [ { 0: 'desc' }, { 1: 'asc' } ] } )
	 *          .on( 'sortEnd.tablesorter', () => console.log( 'Triggered as soon as any sorting has been applied.' ) );
	 * } );
	 * @param {module:jquery.tablesorter~TableSorterOptions} settings
	 * @return {jQuery}
	 */
	$.fn.tablesorter = function ( settings ) {
		return ts.construct( this, settings );
	};

	// Add default parsers
	ts.addParser( {
		id: 'text',
		is: function () {
			return true;
		},
		format: function ( s ) {
			if ( ts.collationRegex ) {
				const tsc = ts.collationTable;
				s = s.replace( ts.collationRegex, ( match ) => {
					const upper = match.toUpperCase(),
						lower = match.toLowerCase();
					let r;
					if ( upper === match && !lower === match ) {
						r = tsc[ lower ] ? tsc[ lower ] : tsc[ upper ];
						r = r.toUpperCase();
					} else {
						r = tsc[ lower ];
					}
					return r;
				} );
			}
			return s;
		},
		type: 'text'
	} );

	ts.addParser( {
		id: 'IPAddress',
		is: function ( s ) {
			return ts.rgx.IPAddress[ 0 ].test( s );
		},
		format: function ( s ) {
			const a = s.split( '.' );
			let r = '';
			for ( let i = 0; i < a.length; i++ ) {
				const item = a[ i ];
				if ( item.length === 1 ) {
					r += '00' + item;
				} else if ( item.length === 2 ) {
					r += '0' + item;
				} else {
					r += item;
				}
			}
			return $.tablesorter.formatFloat( r );
		},
		type: 'numeric'
	} );

	ts.addParser( {
		id: 'currency',
		is: function ( s ) {
			return ts.rgx.currency[ 0 ].test( s );
		},
		format: function ( s ) {
			return $.tablesorter.formatDigit( s.replace( ts.rgx.currency[ 1 ], '' ) );
		},
		type: 'numeric'
	} );

	ts.addParser( {
		id: 'usLongDate',
		is: function ( s ) {
			return ts.rgx.usLongDate[ 0 ].test( s );
		},
		format: function ( s ) {
			return $.tablesorter.formatFloat( new Date( s ).getTime() );
		},
		type: 'numeric'
	} );

	ts.addParser( {
		id: 'date',
		is: function ( s ) {
			return ( ts.dateRegex[ 0 ].test( s ) || ts.dateRegex[ 1 ].test( s ) || ts.dateRegex[ 2 ].test( s ) );
		},
		format: function ( s ) {
			s = s.toLowerCase();

			let match;
			if ( ( match = s.match( ts.dateRegex[ 0 ] ) ) !== null ) {
				if ( mw.config.get( 'wgDefaultDateFormat' ) === 'mdy' || mw.config.get( 'wgPageViewLanguage' ) === 'en' ) {
					s = [ match[ 3 ], match[ 1 ], match[ 2 ] ];
				} else if ( mw.config.get( 'wgDefaultDateFormat' ) === 'dmy' ) {
					s = [ match[ 3 ], match[ 2 ], match[ 1 ] ];
				} else {
					// If we get here, we don't know which order the dd-dd-dddd
					// date is in. So return something not entirely invalid.
					return '99999999';
				}
			} else if ( ( match = s.match( ts.dateRegex[ 1 ] ) ) !== null ) {
				s = [ match[ 3 ], String( ts.monthNames[ match[ 2 ] ] ), match[ 1 ] ];
			} else if ( ( match = s.match( ts.dateRegex[ 2 ] ) ) !== null ) {
				s = [ match[ 3 ], String( ts.monthNames[ match[ 1 ] ] ), match[ 2 ] ];
			} else {
				// Should never get here
				return '99999999';
			}

			// Pad Month and Day
			if ( s[ 1 ].length === 1 ) {
				s[ 1 ] = '0' + s[ 1 ];
			}
			if ( s[ 2 ].length === 1 ) {
				s[ 2 ] = '0' + s[ 2 ];
			}

			let y;
			if ( ( y = parseInt( s[ 0 ], 10 ) ) < 100 ) {
				// Guestimate years without centuries
				if ( y < 30 ) {
					s[ 0 ] = 2000 + y;
				} else {
					s[ 0 ] = 1900 + y;
				}
			}
			while ( s[ 0 ].length < 4 ) {
				s[ 0 ] = '0' + s[ 0 ];
			}
			return parseInt( s.join( '' ), 10 );
		},
		type: 'numeric'
	} );

	ts.addParser( {
		id: 'time',
		is: function ( s ) {
			return ts.rgx.time[ 0 ].test( s );
		},
		format: function ( s ) {
			return $.tablesorter.formatFloat( new Date( '2000/01/01 ' + s ).getTime() );
		},
		type: 'numeric'
	} );

	ts.addParser( {
		id: 'number',
		is: function ( s ) {
			return $.tablesorter.numberRegex.test( s );
		},
		format: function ( s ) {
			return $.tablesorter.formatDigit( s );
		},
		type: 'numeric'
	} );

}() );
mw.loader.impl(function(){return["skins.minerva.scripts@",{"main":"setup.js","files":{"setup.js":function(require,module,exports){/**
 * This setups the Minerva skin.
 * It should run without errors even if MobileFrontend is not installed.
 *
 * @ignore
 */
const ms = require( 'mobile.startup' );
const reportIfNightModeWasDisabledOnPage = require( './reportIfNightModeWasDisabledOnPage.js' );
const addPortletLink = require( './addPortletLink.js' );
const teleportTarget = require( 'mediawiki.page.ready' ).teleportTarget;

function init() {
	const permissions = mw.config.get( 'wgMinervaPermissions' ) || {};
	// eslint-disable-next-line no-jquery/no-global-selector
	const $watch = $( '#page-actions-watch' );

	if ( permissions.watch ) {
		require( './watchstar.js' ).init( $watch );
	}

	addPortletLink.init();
	mw.hook( 'util.addPortletLink' ).add(
		addPortletLink.hookHandler
	);

	// Setup Minerva with MobileFrontend
	if ( ms && !ms.stub ) {
		require( './initMobile.js' )();
	} else {
		// MOBILEFRONTEND IS NOT INSTALLED.
		// setup search for desktop Minerva at mobile resolution without MobileFrontend.
		require( './searchSuggestReveal.js' )();
	}

	// This hot fix should be reviewed and possibly removed circa January 2021.
	// It's assumed that Apple will prioritize fixing this bug in one of its next releases.
	// See T264376.
	if ( navigator.userAgent.match( /OS 14_[0-9]/ ) ) {
		document.body.classList.add( 'hotfix-T264376' );
	}

	// Apply content styles to teleported elements
	teleportTarget.classList.add( 'content' );
	reportIfNightModeWasDisabledOnPage(
		document.documentElement, mw.user.options, mw.user.isNamed()
	);
}

if ( !window.QUnit ) {
	init();
}

module.exports = {
	// Version number allows breaking changes to be detected by other extensions
	VERSION: 1
};
},"reportIfNightModeWasDisabledOnPage.js":function(require,module,exports){/**
 * @private
 * @return {boolean}
 */
function reportDisabled() {
	mw.notify( mw.msg( 'skin-minerva-night-mode-unavailable' ) );
	return true;
}

/**
 * @ignore
 * @param {Document} doc
 * @return {boolean} whether it was reported as disabled.
 */
function reportIfNightModeWasDisabledOnPage( doc ) {
	if ( !doc.classList.contains( 'skin-night-mode-page-disabled' ) ) {
		return false;
	}
	// Cast to string.
	let userExpectedNightMode = `${ mw.user.options.get( 'minerva-theme' ) }`;
	if ( !mw.user.isNamed() ) {
		// bit more convoulated here and will break with upstream changes...
		// this is protected by an integration test in integration.test.js
		const cookieValue = mw.cookie.get( 'mwclientpreferences' ) || '';
		const match = cookieValue.match( /skin-theme-clientpref-(\S+)/ );
		if ( match ) {
			// we found something in the cookie.
			userExpectedNightMode = match[ 1 ];
		}
	}
	if ( userExpectedNightMode === 'night' ) {
		return reportDisabled();
	} else if ( userExpectedNightMode === 'os' && matchMedia( '( prefers-color-scheme: dark )' ).matches ) {
		return reportDisabled();
	} else {
		return false;
	}
}

module.exports = reportIfNightModeWasDisabledOnPage;
},"addPortletLink.js":function(require,module,exports){/**
 * @private
 * @param {jQuery} $item The added list item, or null if no element was added.
 * @return {Object} of arrays with mandatory class names for list item elements.
 */
function getClassesForItem( $item ) {
	const $parent = $item.parent();
	// eslint-disable-next-line no-jquery/no-class-state
	const isPageActionList = $parent.hasClass( 'page-actions-menu__list' );
	// eslint-disable-next-line no-jquery/no-class-state
	const isTabContainer = $parent.hasClass( 'minerva__tab-container' );
	// eslint-disable-next-line no-jquery/no-class-state
	const isToggleList = $parent.hasClass( 'toggle-list__list' );

	if ( isToggleList ) {
		return {
			li: [ 'toggle-list-item' ],
			span: [ 'toggle-list-item__label' ],
			a: [ 'toggle-list-item__anchor' ]
		};
	} else if ( isPageActionList ) {
		return {
			li: [ 'page-actions-menu__list-item' ],
			span: [],
			a: [
				'cdx-button',
				'cdx-button--size-large',
				'cdx-button--fake-button',
				'cdx-button--fake-button--enabled',
				'cdx-button--icon-only',
				'cdx-button--weight-quiet'
			]
		};
	} else if ( isTabContainer ) {
		return {
			li: [ 'minerva__tab' ],
			span: [],
			a: [ 'minerva__tab-text' ]
		};
	} else {
		return {
			li: [],
			span: [],
			a: []
		};
	}
}

/**
 * Insert icon into the portlet link.
 *
 * @private
 * @param {jQuery} $link
 * @param {string|undefined} id for icon
 */
function insertIcon( $link, id ) {
	const icon = document.createElement( 'span' );
	let classes = 'minerva-icon';
	if ( id ) {
		classes += ` minerva-icon-portletlink-${ id }`;
		// FIXME: Please remove when following URL returns zero results:
		// https://global-search.toolforge.org/?q=mw-ui-icon-portletlink&regex=1&namespaces=&title=
		classes += ` mw-ui-icon-portletlink-${ id }`;
	}
	icon.setAttribute( 'class', classes );
	$link.prepend( icon );
}

/**
 * @param {HTMLElement|null} listItem The added list item, or null if no element was added.
 * @param {Object} data
 * @ignore
 */
function hookHandler( listItem, data ) {
	if ( listItem && !listItem.dataset.minervaPortlet ) {
		const id = data.id;
		const $item = $( listItem );

		// add the corresponding classes
		const classes = getClassesForItem( $item );
		$item.addClass( classes.li );
		const $a = $item.find( 'a' );
		$a.addClass( classes.a );
		$item.find( 'a > span' ).addClass( classes.span );

		listItem.dataset.minervaPortlet = true;

		// if the list item is not itself an icon, add the corresponding icon
		// (except tabs, which do not have icons)
		if ( classes.span.indexOf( 'minerva-icon' ) === -1 &&
			classes.li.indexOf( 'minerva__tab' ) === -1 ) {
			insertIcon( $a, id );
		}
	}
}

/**
 * Init portlet link items added by gadgets prior to Minerva
 * loading.
 *
 * @ignore
 */
function init() {
	Array.prototype.forEach.call(
		document.querySelectorAll( '.mw-list-item-js' ),
		( item ) => {
			hookHandler( item, {
				id: item.getAttribute( 'id' )
			} );
		}
	);
}
module.exports = {
	init,
	hookHandler
};
},"initMobile.js":function(require,module,exports){/**
 * Initialise code that requires MobileFrontend.
 */

module.exports = function () {
	const
		ms = require( 'mobile.startup' ),
		PageHTMLParser = ms.PageHTMLParser,
		permissions = mw.config.get( 'wgMinervaPermissions' ) || {},
		notifyOnPageReload = ms.notifyOnPageReload,
		time = ms.time,
		preInit = require( './preInit.js' ),
		mobileRedirect = require( './mobileRedirect.js' ),
		search = require( './search.js' ),
		references = require( './references.js' ),
		TitleUtil = require( './TitleUtil.js' ),
		issues = require( './page-issues/index.js' ),
		Toolbar = require( './Toolbar.js' ),
		ToggleList = require( '../../includes/Skins/ToggleList/ToggleList.js' ),
		TabScroll = require( './TabScroll.js' ),
		router = require( 'mediawiki.router' ),
		ctaDrawers = require( './ctaDrawers.js' ),
		drawers = require( './drawers.js' ),
		desktopMMV = mw.loader.getState( 'mmv.bootstrap' ),
		overlayManager = ms.getOverlayManager(),
		currentPage = ms.currentPage(),
		currentPageHTMLParser = ms.currentPageHTMLParser(),
		api = new mw.Api(),
		namespaceIDs = mw.config.get( 'wgNamespaceIds' );

	/**
	 * Event handler for clicking on an image thumbnail
	 *
	 * @param {MouseEvent} ev
	 * @ignore
	 */
	function onClickImage( ev ) {
		// Do not interfere when a modifier key is pressed.
		if ( ev.altKey || ev.ctrlKey || ev.shiftKey || ev.metaKey ) {
			return;
		}

		const el = ev.target.closest( PageHTMLParser.THUMB_SELECTOR );
		if ( !el ) {
			return;
		}

		const thumb = currentPageHTMLParser.getThumbnail( $( el ) );
		if ( !thumb ) {
			return;
		}

		ev.preventDefault();
		routeThumbnail( thumb );
	}

	/**
	 * @param {jQuery.Element} thumbnail
	 * @ignore
	 */
	function routeThumbnail( thumbnail ) {
		router.navigate( '#/media/' + encodeURIComponent( thumbnail.getFileName() ) );
	}

	/**
	 * Add routes to images and handle clicks
	 *
	 * @method
	 * @ignore
	 * @param {HTMLElement} container Container to search within
	 */
	function initMediaViewer( container ) {
		// T360781 Ensure correct type before using `addEventListener`.
		if ( container instanceof HTMLElement ) {
			container.addEventListener( 'click', onClickImage );
		}
	}

	/**
	 * Hijack the Special:Languages link and replace it with a trigger to a languageOverlay
	 * that displays the same data
	 *
	 * @ignore
	 */
	function initButton() {
		// This catches language selectors in page actions and in secondary actions (e.g. Main Page)
		// eslint-disable-next-line no-jquery/no-global-selector
		const $primaryBtn = $( '.language-selector' );

		if ( $primaryBtn.length ) {
			// We only bind the click event to the first language switcher in page
			$primaryBtn.on( 'click', ( ev ) => {
				ev.preventDefault();

				if ( $primaryBtn.attr( 'href' ) || $primaryBtn.find( 'a' ).length ) {
					router.navigate( '/languages' );
				} else {
					mw.notify( mw.msg( 'mobile-frontend-languages-not-available' ), {
						tag: 'languages-not-available'
					} );
				}
			} );
		}
	}

	/**
	 * Returns a rejected promise if MultimediaViewer is available. Otherwise
	 * returns the mediaViewerOverlay
	 *
	 * @method
	 * @ignore
	 * @param {string} title the title of the image
	 * @return {void|Overlay} note must return void if the overlay should not show (see T262703)
	 *  otherwise an Overlay is expected and this can lead to e.on/off is not a function
	 */
	function makeMediaViewerOverlayIfNeeded( title ) {
		if ( mw.loader.getState( 'mmv.bootstrap' ) === 'ready' ) {
			// This means MultimediaViewer has been installed and is loaded.
			// Avoid loading it (T169622)
			return;
		}
		try {
			title = decodeURIComponent( title );
		} catch ( e ) {
			// e.g. https://ro.m.wikipedia.org/wiki/Elisabeta_I_a_Angliei#/media/Fi%C8%18ier:Elizabeth_I_Rainbow_Portrait.jpg
			return;
		}

		return ms.mediaViewer.overlay( {
			api,
			thumbnails: currentPageHTMLParser.getThumbnails(),
			title
		} );
	}

	// Routes
	overlayManager.add( /^\/media\/(.+)$/, makeMediaViewerOverlayIfNeeded );
	overlayManager.add( /^\/languages$/, () => ms.languages.languageOverlay() );
	// Register a LanguageInfo overlay which has no built-in functionality;
	// a hook is fired when a language is selected, and extensions can respond
	// to that hook. See GrowthExperiments WelcomeSurvey feature (in gerrit
	// Ib558dc7c46cc56ff667957f9126bbe0471d25b8e for example usage).
	overlayManager.add( /^\/languages\/all$/, () => ms.languages.languageInfoOverlay( api, true ) );
	overlayManager.add( /^\/languages\/all\/no-suggestions$/, () => ms.languages.languageInfoOverlay( api, false ) );

	// Setup
	$( () => {
		initButton();
	} );

	/**
	 * Initialisation function for last modified module.
	 *
	 * Enhances an element representing a time
	 * to show a human friendly date in seconds, minutes, hours, days
	 * months or years
	 *
	 * @ignore
	 * @param {jQuery} $lastModifiedLink
	 */
	function initHistoryLink( $lastModifiedLink ) {
		const ts = $lastModifiedLink.data( 'timestamp' );
		if ( ts ) {
			const username = $lastModifiedLink.data( 'user-name' ) || false;
			const gender = $lastModifiedLink.data( 'user-gender' );
			const delta = time.getTimeAgoDelta( parseInt( ts, 10 ) );
			if ( time.isRecent( delta ) ) {
				const $bar = $lastModifiedLink.closest( '.last-modified-bar' );
				$bar.addClass( 'active' );
			}

			const $msg = $( '<span>' )
				// The new element should maintain the non-js element's CSS classes.
				.attr( 'class', $lastModifiedLink.attr( 'class' ) )
				.html(
					time.getLastModifiedMessage( ts, username, gender,
						// For cached HTML
						$lastModifiedLink.attr( 'href' )
					)
				);
			$lastModifiedLink.replaceWith( $msg );
		}
	}

	/**
	 * @method
	 * @param {jQuery.Event} ev
	 */
	function amcHistoryClickHandler( ev ) {
		const self = this;
		const amcOutreach = ms.amcOutreach;
		const amcCampaign = amcOutreach.loadCampaign();
		const onDismiss = function () {
			notifyOnPageReload( mw.msg( 'mobile-frontend-amc-outreach-dismissed-message' ) );
			window.location = self.href;
		};
		const drawer = amcCampaign.showIfEligible( amcOutreach.ACTIONS.onHistoryLink, onDismiss, currentPage.title, 'action=history' );

		if ( drawer ) {
			ev.preventDefault();
			// stopPropagation is needed to prevent drawer from immediately closing
			// when shown (drawers.js adds a click event to window when drawer is
			// shown
			ev.stopPropagation();

			drawers.displayDrawer( drawer, {} );
			drawers.lockScroll();
		}
	}

	/**
	 * @method
	 * @param {jQuery} $lastModifiedLink
	 * @ignore
	 */
	function initAmcHistoryLink( $lastModifiedLink ) {
		$lastModifiedLink.one( 'click', amcHistoryClickHandler );
	}

	/**
	 * Initialisation function for last modified times
	 *
	 * Enhances .modified-enhancement element
	 * to show a human friendly date in seconds, minutes, hours, days
	 * months or years
	 *
	 * @ignore
	 */
	function initModifiedInfo() {
		// eslint-disable-next-line no-jquery/no-global-selector
		$( '.modified-enhancement' ).each( ( _i, el ) => {
			initHistoryLink( $( el ) );
		} );
		Array.prototype.forEach.call( document.querySelectorAll( '.mw-diff-timestamp' ), ( tsNode ) => {
			const ts = tsNode.dataset.timestamp;
			if ( ts ) {
				const ago = time.getTimeAgoDelta(
					parseInt(
						( new Date( ts ) ).getTime() / 1000,
						10
					)
				);
				// Supported messages:
				// * skin-minerva-time-ago-seconds
				// * skin-minerva-time-ago-minutes
				// * skin-minerva-time-ago-hours
				// * skin-minerva-time-ago-days
				// * skin-minerva-time-ago-months
				// * skin-minerva-time-ago-years
				tsNode.textContent = mw.msg(
					`skin-minerva-time-ago-${ ago.unit }`,
					mw.language.convertNumber( ago.value )
				);
			}
		} );
	}

	/**
	 * Initialisation function for user creation module.
	 *
	 * Enhances an element representing a time
	 * to show a human friendly date in seconds, minutes, hours, days
	 * months or years
	 *
	 * @ignore
	 * @param {jQuery} [$tagline]
	 */
	function initRegistrationDate( $tagline ) {
		const ts = $tagline.data( 'userpage-registration-date' );

		if ( ts ) {
			const msg = time.getRegistrationMessage( ts, $tagline.data( 'userpage-gender' ) );
			$tagline.text( msg );
		}
	}

	/**
	 * Initialisation function for registration date on user page
	 *
	 * Enhances .tagline-userpage element
	 * to show human friendly date in seconds, minutes, hours, days
	 * months or years
	 *
	 * @ignore
	 */
	function initRegistrationInfo() {
		// eslint-disable-next-line no-jquery/no-global-selector
		$( '#tagline-userpage' ).each( ( _i, el ) => {
			initRegistrationDate( $( el ) );
		} );
	}

	/**
	 * Tests a URL to determine if it links to a local User namespace page or not.
	 *
	 * Assuming the current page visited is hosted on metawiki, the following examples would return
	 * true:
	 *
	 *   https://meta.wikimedia.org/wiki/User:Foo
	 *   /wiki/User:Foo
	 *   /wiki/User:Nonexistent_user_page
	 *
	 * The following examples return false:
	 *
	 *   https://en.wikipedia.org/wiki/User:Foo
	 *   /wiki/Foo
	 *   /wiki/User_talk:Foo
	 *
	 * @param {string} url
	 * @return {boolean}
	 */
	function isUserUri( url ) {
		const title = TitleUtil.newFromUri( url );
		const namespace = title ? title.getNamespaceId() : undefined;
		return namespace === namespaceIDs.user;
	}

	/**
	 * Strip the edit action from red links to nonexistent User namespace pages.
	 *
	 * @param {jQuery} $redLinks
	 */
	function initUserRedLinks( $redLinks ) {
		$redLinks.filter(
			// Filter out non-User namespace pages.
			( _, element ) => isUserUri( element.href )
		).each( ( _, element ) => {
			const uri = new mw.Uri( element.href );
			if ( uri.query.action !== 'edit' ) {
				// Nothing to strip.
				return;
			}

			// Strip the action.
			delete uri.query.action;

			// Update the element with the new link.
			element.href = uri.toString();
		} );
	}

	/**
	 * Wires up the notification badge to Echo extension
	 */
	function setupEcho() {
		const echoBtn = document.querySelector( '.minerva-notifications .mw-echo-notification-badge-nojs' );
		if ( echoBtn ) {
			echoBtn.addEventListener( 'click', ( ev ) => {
				router.navigate( '#/notifications' );
				// prevent navigation to original Special:Notifications URL
				// DO NOT USE stopPropagation or you'll break click tracking in WikimediaEvents
				ev.preventDefault();

				// Mark as read.
				echoBtn.dataset.counterNum = 0;
				echoBtn.dataset.counterText = mw.msg( 'echo-badge-count',
					mw.language.convertNumber( 0 )
				);

			} );
		}
	}

	$( () => {
		// eslint-disable-next-line no-jquery/no-global-selector
		const $watch = $( '#page-actions-watch' );
		const toolbarElement = document.querySelector( Toolbar.selector );
		const userMenu = document.querySelector( '.minerva-user-menu' ); // See UserMenuDirector.
		const navigationDrawer = document.querySelector( '.navigation-drawer' );

		// The `minerva-animations-ready` class can be used by clients to prevent unwanted
		// CSS transitions from firing on page load in some browsers (see
		// https://bugs.chromium.org/p/chromium/issues/detail?id=332189 as well as
		// https://phabricator.wikimedia.org/T234570#5779890). Since JS adds this
		// class after the CSS transitions loads, this issue is circumvented. See
		// MainMenu.less for an example of how this is used.
		$( document.body ).addClass( 'minerva-animations-ready' );

		// eslint-disable-next-line no-jquery/no-global-selector
		$( '.mw-mf-page-center__mask' ).on( 'click', ( ev ) => {
			const path = router.getPath();
			// avoid jumping to the top of the page and polluting history by avoiding the
			// resetting of the hash unless the hash is being utilised (T237015).
			if ( !path ) {
				ev.preventDefault();
			}
		} );
		// Init:
		// - main menu closes when you click outside of it
		// - redirects show a toast.
		preInit();
		// - references
		references();
		// - search
		search();
		// - mobile redirect
		mobileRedirect( ms.amcOutreach, currentPage );

		// Enhance timestamps on last-modified bar and watchlist
		// to show relative time.
		initModifiedInfo();
		initRegistrationInfo();
		// eslint-disable-next-line no-jquery/no-global-selector
		initAmcHistoryLink( $( '.last-modified-bar__text a' ) );

		if ( toolbarElement ) {
			Toolbar.bind( window, toolbarElement );
			// Update the edit icon and add a download icon.
			Toolbar.render( window, toolbarElement );
		}
		if ( userMenu ) {
			ToggleList.bind( window, userMenu );
		}
		if ( navigationDrawer ) {
			ToggleList.bind( window, navigationDrawer );
			const navigationDrawerMask = navigationDrawer.querySelector( '.main-menu-mask' );
			// The 'for' attribute is used to close the drawer when the mask is clicked without JS
			// Since we are using JS to enhance the drawer behavior, we need to
			// remove the attribute to prevent the drawer from being toggled twice
			navigationDrawerMask.removeAttribute( 'for' );
		}
		TabScroll.initTabsScrollPosition();
		// Setup the issues banner on the page
		// Pages which dont exist (id 0) cannot have issues
		if (
			!currentPage.isMissing &&
			!currentPage.titleObj.isTalkPage()
		) {
			issues.init( overlayManager, currentPageHTMLParser );
		}

		// If MobileFrontend installed we add a table of contents icon to the table of contents.
		// This should probably be done in the parser.
		// setup toc icons
		mw.hook( 'wikipage.content' ).add( ( $container ) => {
			// If the MMV module is missing or disabled from the page, initialise our version
			if ( desktopMMV === null || desktopMMV === 'registered' ) {
				initMediaViewer( $container[ 0 ] );
			}

			// Mutate TOC.
			const $toctitle = $container.find( '.toctitle' );
			$( '<span>' ).addClass( 'toc-title-icon' ).prependTo( $toctitle );
			$( '<span>' ).addClass( 'toc-title-state-icon' ).appendTo( $toctitle );

			// Init red links.
			const $redLinks = currentPageHTMLParser.getRedLinks();
			ctaDrawers.initRedlinksCta(
				$redLinks.filter(
					// Filter out local User namespace pages.
					( _, element ) => !isUserUri( element.href )
				)
			);
			initUserRedLinks( $redLinks );
		} );

		// wire up watch icon if necessary
		if ( permissions.watchable && !permissions.watch ) {
			ctaDrawers.initWatchstarCta( $watch );
		}

		// If Echo is installed, wire it up.
		const echoState = mw.loader.getState( 'ext.echo.mobile' );
		// If Echo is installed, set it up.
		if ( echoState !== null && echoState !== 'registered' ) {
			setupEcho();
		}
	} );
};
},"searchSuggestReveal.js":function(require,module,exports){const SEARCH_CLASS = 'search-enabled';

module.exports = function () {
	// eslint-disable-next-line no-jquery/no-global-selector
	$( '#searchIcon' ).on( 'click', () => {
		// eslint-disable-next-line no-jquery/no-global-selector
		const $input = $( '#searchInput' );
		const $body = $( document.body );

		// eslint-disable-next-line no-jquery/no-sizzle
		if ( !$input.is( ':visible' ) ) {
			$body.addClass( SEARCH_CLASS );
			$input.trigger( 'focus' )
				.one( 'blur', () => {
					$body.removeClass( SEARCH_CLASS );
				} );
			return false;
		}
	} );
};
},"drawers.js":function(require,module,exports){const $drawerContainer = $( document.body );
const BODY_CLASS_SCROLL_LOCKED = 'has-drawer--with-scroll-locked';

/**
 * Discard a drawer from display on the page.
 *
 * @private
 * @param {Drawer} drawer
 */
function discardDrawer( drawer ) {
	// remove the class
	$drawerContainer.removeClass( BODY_CLASS_SCROLL_LOCKED );
	// FIXME: queue removal from DOM (using setTimeout so that any animations have time to run)
	// This works around an issue in MobileFrontend that the Drawer onBeforeHide method is
	// called /before/ the animation for closing has completed. This needs to be accounted
	// for in Drawer so this function can be synchronous.
	setTimeout( () => {
		// detach the node from the DOM. Use detach rather than remove to allow reuse without
		// losing any existing events.
		drawer.$el.detach();
	}, 100 );
}

/**
 * Lock scroll of viewport.
 *
 * @ignore
 */
function lockScroll() {
	$drawerContainer.addClass( BODY_CLASS_SCROLL_LOCKED );
}

/**
 * @param {Drawer} drawer to display
 * @param {Object} options for display
 * @param {boolean} options.hideOnScroll whether a scroll closes the drawer
 * @ignore
 */
function displayDrawer( drawer, options ) {
	$drawerContainer.append( drawer.$el );
	drawer.show();
	if ( options.hideOnScroll ) {
		$( window ).one( 'scroll.drawer', () => {
			drawer.hide();
		} );
	}
}
module.exports = {
	displayDrawer,
	lockScroll,
	discardDrawer
};
},"ctaDrawers.js":function(require,module,exports){const mobile = require( 'mobile.startup' );
const drawers = require( './drawers.js' );
const CtaDrawer = mobile.CtaDrawer;

/**
 * Initialize red links call-to-action
 *
 * Upon clicking a red link, show an interstitial CTA explaining that the page doesn't exist
 * with a button to create it, rather than directly navigate to the edit form.
 *
 * Special case T201339: following a red link to a user or user talk page should not prompt for
 * its creation. The reasoning is that user pages should be created by their owners and it's far
 * more common that non-owners follow a user's red linked user page to consider their
 * contributions, account age, or other activity.
 *
 * For example, a user adds a section to a Talk page and signs their contribution (which creates
 * a link to their user page whether exists or not). If the user page does not exist, that link
 * will be red. In both cases, another user follows this link, not to edit create a page for
 * that user but to obtain information on them.
 *
 * @private
 * @param {jQuery} $redLinks
 */
function initRedlinksCta( $redLinks ) {
	$redLinks.on( 'click', function ( ev ) {
		const drawerOptions = {
				progressiveButton: {
					progressive: true,
					label: mw.msg( 'mobile-frontend-editor-redlink-create' ),
					href: $( this ).attr( 'href' )
				},
				actionAnchor: {
					progressive: true,
					label: mw.msg( 'mobile-frontend-editor-redlink-leave' ),
					additionalClassNames: 'cancel'
				},
				onBeforeHide: drawers.discardDrawer,
				content: mw.msg( 'mobile-frontend-editor-redlink-explain' )
			},
			drawer = CtaDrawer( drawerOptions );

		// use preventDefault() and not return false to close other open
		// drawers or anything else.
		ev.preventDefault();
		ev.stopPropagation();
		drawers.displayDrawer( drawer, { hideOnScroll: true } );
	} );
}

/**
 * A CtaDrawer should show for anonymous users.
 *
 * @param {jQuery} $watchstar
 * @ignore
 */
function initWatchstarCta( $watchstar ) {
	let watchCtaDrawer;
	// show a CTA for anonymous users
	$watchstar.on( 'click', ( ev ) => {
		if ( !watchCtaDrawer ) {
			watchCtaDrawer = CtaDrawer( {
				content: mw.msg( 'minerva-watchlist-cta' ),
				queryParams: {
					notice: 'mobile-frontend-watchlist-purpose',
					campaign: 'mobile_watchPageActionCta',
					returntoquery: 'article_action=watch'
				},
				onBeforeHide: drawers.discardDrawer,
				signupQueryParams: {
					notice: 'mobile-frontend-watchlist-signup-action'
				}
			} );
		}
		// If it's already shown dont display again
		// (if user is clicking fast since we are reusing the drawer
		// this might result in the drawer opening and closing)
		if ( !watchCtaDrawer.$el[ 0 ].parentNode ) {
			drawers.displayDrawer( watchCtaDrawer, { hideOnScroll: true } );
		}
		// prevent default to stop the user
		// being navigated to Special:UserLogin
		ev.preventDefault();
		// Don't stopProgation, as we want WikimediaEvents to log clicks to this.
	} );
}

module.exports = {
	initWatchstarCta: initWatchstarCta,
	initRedlinksCta: initRedlinksCta
};
},"menu.js":function(require,module,exports){const BODY_NOTIFICATIONS_REVEAL_CLASS = 'navigation-enabled secondary-navigation-enabled';

/**
 * Wire up the main menu
 *
 * @ignore
 */
function init() {

	// See I09c27a084100b223662f84de6cbe01bebe1fe774
	// will trigger every time the Echo notification is opened or closed.
	// This controls the drawer like behaviour of notifications
	// on tablet in mobile mode.
	mw.hook( 'echo.mobile' ).add( ( isOpen ) => {
		$( document.body ).toggleClass( BODY_NOTIFICATIONS_REVEAL_CLASS, isOpen );
	} );
}

module.exports = {
	init
};
},"preInit.js":function(require,module,exports){module.exports = function () {
	const menus = require( './menu.js' );

	// setup main menu
	menus.init();

	( function ( wgRedirectedFrom ) {
		// If the user has been redirected, then show them a toast message (see
		// https://phabricator.wikimedia.org/T146596).

		if ( wgRedirectedFrom === null ) {
			return;
		}

		const redirectedFrom = mw.Title.newFromText( wgRedirectedFrom );

		if ( redirectedFrom ) {
			// mw.Title.getPrefixedText includes the human-readable namespace prefix.
			const title = redirectedFrom.getPrefixedText();
			const $msg = $( '<div>' ).html(
				mw.message( 'mobile-frontend-redirected-from', title ).parse()
			);
			$msg.find( 'a' ).attr( 'href', mw.util.getUrl( title, { redirect: 'no' } ) );
			mw.notify( $msg );
		}
	}( mw.config.get( 'wgRedirectedFrom' ) ) );

};
},"downloadPageAction.js":function(require,module,exports){const track = mw.track;
const MAX_PRINT_TIMEOUT = 3000;
let printSetTimeoutReference = 0;
const mobile = require( 'mobile.startup' );

/**
 * Helper function to detect iOs
 *
 * @ignore
 * @param {string} userAgent User Agent
 * @return {boolean}
 */
function isIos( userAgent ) {
	return /ipad|iphone|ipod/i.test( userAgent );
}

/**
 * Helper function to retrieve the Android version
 *
 * @ignore
 * @param {string} userAgent User Agent
 * @return {number|boolean} Integer version number, or false if not found
 */
function getAndroidVersion( userAgent ) {
	const match = userAgent.toLowerCase().match( /android\s(\d\.]*)/ );
	return match ? parseInt( match[ 1 ] ) : false;
}

/**
 * Helper function to retrieve the Chrome/Chromium version
 *
 * @ignore
 * @param {string} userAgent User Agent
 * @return {number|boolean} Integer version number, or false if not found
 */
function getChromeVersion( userAgent ) {
	const match = userAgent.toLowerCase().match( /chrom(e|ium)\/(\d+)\./ );
	return match ? parseInt( match[ 2 ] ) : false;
}

/**
 * Checks whether DownloadIcon is available for given user agent
 *
 * @memberof DownloadIcon
 * @instance
 * @param {Window} windowObj
 * @param {Page} page to download
 * @param {string} userAgent User agent
 * @param {number[]} supportedNamespaces where printing is possible
 * @return {boolean}
 */
function isAvailable( windowObj, page, userAgent, supportedNamespaces ) {
	const androidVersion = getAndroidVersion( userAgent );
	const chromeVersion = getChromeVersion( userAgent );

	if ( typeof window.print !== 'function' ) {
		// T309591: No window.print support
		return false;
	}

	// Download button is restricted to certain namespaces T181152.
	// Not shown on missing pages
	// Defaults to 0, in case cached JS has been served.
	if ( supportedNamespaces.indexOf( page.getNamespaceId() ) === -1 ||
		page.isMainPage() || page.isMissing ) {
		// namespace is not supported or it's a main page
		return false;
	}

	if ( isIos( userAgent ) || chromeVersion === false ||
		windowObj.chrome === undefined
	) {
		// we support only chrome/chromium on desktop/android
		return false;
	}
	if ( ( androidVersion && androidVersion < 5 ) || chromeVersion < 41 ) {
		return false;
	}
	return true;
}
/**
 * onClick handler for button that invokes print function
 *
 * @private
 * @param {HTMLElement} portletItem
 * @param {Icon} spinner
 * @param {Function} [loadAllImagesInPage]
 */
function onClick( portletItem, spinner, loadAllImagesInPage ) {
	const icon = portletItem.querySelector( '.minerva-icon--download' );
	function doPrint() {
		printSetTimeoutReference = clearTimeout( printSetTimeoutReference );
		track( 'minerva.downloadAsPDF', {
			action: 'callPrint'
		} );
		window.print();
		$( icon ).show();
		spinner.$el.hide();
	}

	function doPrintBeforeTimeout() {
		if ( printSetTimeoutReference ) {
			doPrint();
		}
	}
	// The click handler may be invoked multiple times so if a pending print is occurring
	// do nothing.
	if ( !printSetTimeoutReference ) {
		track( 'minerva.downloadAsPDF', {
			action: 'fetchImages'
		} );
		$( icon ).hide();
		spinner.$el.show();
		// If all image downloads are taking longer to load then the MAX_PRINT_TIMEOUT
		// abort the spinner and print regardless.
		printSetTimeoutReference = setTimeout( doPrint, MAX_PRINT_TIMEOUT );
		( loadAllImagesInPage || mobile.loadAllImagesInPage )()
			.then( doPrintBeforeTimeout, doPrintBeforeTimeout );
	}
}

/**
 * Generate a download icon for triggering print functionality if
 * printing is available.
 * Calling this method has side effects:
 * It calls mw.util.addPortletLink and may inject an element into the page.
 *
 * @ignore
 * @param {Page} page
 * @param {number[]} supportedNamespaces
 * @param {Window} [windowObj] window object
 * @param {boolean} [overflowList] Append to overflow list
 * @return {jQuery|null}
 */
function downloadPageAction( page, supportedNamespaces, windowObj, overflowList ) {
	const spinner = ( overflowList ) ? mobile.spinner( {
		label: '',
		isIconOnly: false
	} ) : mobile.spinner();

	if (
		isAvailable(
			windowObj, page, navigator.userAgent,
			supportedNamespaces
		)
	) {
		// FIXME: Use p-views when cache has cleared.
		const actionID = document.querySelector( '#p-views' ) ? 'p-views' : 'page-actions';
		const portletLink = mw.util.addPortletLink(
			overflowList ? 'page-actions-overflow' : actionID,
			'#',
			mw.msg( 'minerva-download' ),
			// id
			'minerva-download',
			// tooltip
			mw.msg( 'minerva-download' ),
			// access key
			'p',
			overflowList ? null : document.getElementById( 'page-actions-watch' )
		);
		if ( portletLink ) {
			portletLink.addEventListener( 'click', () => {
				onClick( portletLink, spinner, mobile.loadAllImagesInPage );
			} );
			const iconElement = portletLink.querySelector( '.minerva-icon' );
			if ( iconElement ) {
				iconElement.classList.add( 'minerva-icon--download' );
			}
			spinner.$el.hide().insertBefore(
				$( portletLink ).find( '.minerva-icon' )
			);
		}
		return portletLink;
	} else {
		return null;
	}
}

module.exports = {
	downloadPageAction,
	test: {
		isAvailable,
		onClick
	}
};
},"page-issues/parser.js":function(require,module,exports){/**
 * @typedef PageIssue
 * @ignore
 * @property {string} severity A SEVERITY_LEVEL key.
 * @property {boolean} grouped True if part of a group of multiple issues, false if singular.
 * @property {Icon} icon
 */
/**
 * @typedef {Object} IssueSummary
 * @ignore
 * @property {PageIssue} issue
 * @property {jQuery} $el where the issue was extracted from
 * @property {string} iconString a string representation of icon.
 *  This is kept for template compatibility (our views do not yet support composition).
 * @property {string} text HTML string.
 */

// Icons are matching the type selector below use a TYPE_* icon. When unmatched, the icon is
// chosen by severity. Their color is always determined by severity, too.
const ICON_NAME = {
	// Generic severity icons.
	SEVERITY: {
		DEFAULT: 'issue-generic',
		LOW: 'issue-severity-low',
		MEDIUM: 'issue-severity-medium',
		HIGH: 'issue-generic'
	},

	// Icons customized by type.
	TYPE: {
		MOVE: 'issue-type-move',
		POINT_OF_VIEW: 'issue-type-point-of-view'
	}
};
const ICON_COLOR = {
	DEFAULT: 'defaultColor',
	LOW: 'lowColor',
	MEDIUM: 'mediumColor',
	HIGH: 'highColor'
};
// How severities order and compare from least to greatest. For the multiple issues
// template, severity should be considered the maximum of all its contained issues.
const SEVERITY_LEVEL = {
	DEFAULT: 0,
	LOW: 1,
	MEDIUM: 2,
	HIGH: 3
};
// Match the template's color CSS selector to a severity level concept. Derived via the
// Ambox templates and sub-templates for the top five wikis and tested on page issues
// inventory:
// - https://people.wikimedia.org/~jdrewniak/page_issues_inventory
// - https://en.wikipedia.org/wiki/Template:Ambox
// - https://es.wikipedia.org/wiki/Plantilla:Metaplantilla_de_avisos
// - https://ja.wikipedia.org/wiki/Template:Ambox
// - https://ru.wikipedia.org/wiki/Шаблон:Ambox
// - https://it.wikipedia.org/wiki/Template:Avviso
// Severity is the class associated with the color. The ResourceLoader config mimics the
// idea by using severity for color variants. Severity is determined independently of icons.
// These selectors should be migrated to their templates.
const SEVERITY_REGEX = {
	// recommended (T206177), en, it
	LOW: /mobile-issue-severity-low|ambox-style|avviso-stile/,
	// recommended, en, it
	MEDIUM: /mobile-issue-severity-medium|ambox-content|avviso-contenuto/,
	// recommended, en, en, es / ru, it
	HIGH: /mobile-issue-severity-high|ambox-speedy|ambox-delete|ambox-serious|avviso-importante/
	// ..And everything else that doesn't match should be considered DEFAULT.
};
// As above but used to identify specific templates requiring icon customization.
const TYPE_REGEX = {
	// recommended (opt-in) / en, es / ru, it (long term only recommended should be used)
	MOVE: /mobile-issue-move|ambox-converted|ambox-move|ambox-merge|avviso-struttura/,

	POINT_OF_VIEW: new RegExp( [
		// recommended (opt-in)
		'mobile-issue-pov',
		// FIXME: en classes: plan to remove these provided can get adoption of recommended
		'ambox-Advert',
		'ambox-autobiography',
		'ambox-believerpov',
		'ambox-COI',
		'ambox-coverage',
		'ambox-criticism',
		'ambox-fanpov',
		'ambox-fringe-theories',
		'ambox-geographical-imbalance',
		'ambox-globalize',
		'ambox-npov-language',
		'ambox-POV',
		'ambox-pseudo',
		'ambox-systemic-bias',
		'ambox-unbalanced',
		'ambox-usgovtpov'
	].join( '|' ) )
	// ..And everything else that doesn't match is mapped to a "SEVERITY" type.
};
const GROUPED_PARENT_REGEX = /mw-collapsible-content/;
// Variants supported by specific types. The "severity icon" supports all severities but the
// type icons only support one each by ResourceLoader.
const TYPE_SEVERITY = {
	MOVE: 'DEFAULT',
	POINT_OF_VIEW: 'MEDIUM'
};

/**
 * @param {Element} box
 * @return {string} An SEVERITY_SELECTOR key.
 * @private
 */
function parseSeverity( box ) {
	let severity;
	const identified = Object.keys( SEVERITY_REGEX ).some( ( key ) => {
		const regex = SEVERITY_REGEX[ key ];
		severity = key;
		return regex.test( box.className );
	} );
	return identified ? severity : 'DEFAULT';
}

/**
 * @param {Element} box
 * @param {string} severity An SEVERITY_LEVEL key.
 * @return {{name: string, severity: string}} An ICON_NAME.
 * @private
 */
function parseType( box, severity ) {
	let identifiedType;
	const identified = Object.keys( TYPE_REGEX ).some( ( type ) => {
		const regex = TYPE_REGEX[ type ];
		identifiedType = type;
		return regex.test( box.className );
	} );
	return {
		name: identified ? ICON_NAME.TYPE[ identifiedType ] : ICON_NAME.SEVERITY[ severity ],
		severity: identified ? TYPE_SEVERITY[ identifiedType ] : severity
	};
}

/**
 * @param {Element} box
 * @return {boolean} True if part of a group of multiple issues, false if singular.
 * @private
 */
function parseGroup( box ) {
	return !!box.parentNode && GROUPED_PARENT_REGEX.test( box.parentNode.className );
}

/**
 * @ignore
 * @param {Element} box
 * @param {string} severity An SEVERITY_LEVEL key.
 * @return {string} A severity or type ISSUE_ICON.
 */
function iconName( box, severity ) {
	const nameSeverity = parseType( box, severity );
	// The icon with color variant as expected by ResourceLoader,
	// {iconName}-{severityColorVariant}.
	return nameSeverity.name + '-' + ICON_COLOR[ nameSeverity.severity ];
}

/**
 * @ignore
 * @param {string[]} severityLevels an array of SEVERITY_KEY values.
 * @return {string} The greatest SEVERITY_LEVEL key.
 */
function maxSeverity( severityLevels ) {
	return severityLevels.reduce( ( max, severity ) => SEVERITY_LEVEL[ max ] > SEVERITY_LEVEL[ severity ] ? max : severity, 'DEFAULT' );
}

/**
 * @ignore
 * @param {Element} box
 * @return {PageIssue}
 */
function parse( box ) {
	const severity = parseSeverity( box );
	const iconElement = document.createElement( 'div' );
	iconElement.classList.add( `minerva-icon--${ iconName( box, severity ) }`, 'minerva-ambox-icon' );
	return {
		severity,
		grouped: parseGroup( box ),
		iconElement
	};
}

/**
 * Extract a summary message from a cleanup template generated element that is
 * friendly for mobile display.
 *
 * @ignore
 * @param {Object} $box element to extract the message from
 * @return {IssueSummary}
 */
function extract( $box ) {
	const SELECTOR = '.mbox-text, .ambox-text';
	const $container = $( '<div>' );

	$box.find( SELECTOR ).each( ( _i, el ) => {
		const $el = $( el );
		// Clean up talk page boxes
		$el.find( 'table, .noprint' ).remove();
		const contents = $el.html();

		if ( contents ) {
			$( '<p>' ).html( contents ).appendTo( $container );
		}
	} );

	const pageIssue = parse( $box.get( 0 ) );

	return {
		issue: pageIssue,
		$el: $box,
		text: $container.html()
	};
}

module.exports = {
	extract,
	parse,
	maxSeverity,
	iconName,
	test: {
		parseSeverity,
		parseType,
		parseGroup
	}
};
},"AB.js":function(require,module,exports){const mwExperiments = mw.experiments;
/*
* Bucketing wrapper for creating AB-tests.
*
* Given a test name, sampling rate, and session ID, provides a class that buckets a user into
* a predefined bucket ("unsampled", "control", or "treatment") and starts an AB-test.
*/
const bucket = {
	UNSAMPLED: 'unsampled', // Old treatment: not sampled and not instrumented.
	CONTROL: 'control', // Old treatment: sampled and instrumented.
	TREATMENT: 'treatment' // New treatment: sampled and instrumented.
};

/**
 * Buckets users based on params and exposes an `isSampled` and `getBucket` method.
 *
 * @ignore
 * @param {Object} config Configuration object for AB test.
 * @param {string} config.testName
 * @param {number} config.samplingRate Sampling rate for the AB-test.
 * @param {number} config.sessionId Session ID for user bucketing.
 * @constructor
 */
function AB( config ) {
	const testName = config.testName;
	const samplingRate = config.samplingRate;
	const sessionId = config.sessionId;
	const test = {
		name: testName,
		enabled: !!samplingRate,
		buckets: {
			unsampled: 1 - samplingRate,
			control: samplingRate / 2,
			treatment: samplingRate / 2
		}
	};

	/**
	 * Gets the users AB-test bucket.
	 *
	 * A boolean instead of an enum is usually a code smell. However, the nature of A/B testing
	 * is to compare an A group's performance to a B group's so a boolean seems natural, even
	 * in the long term, and preferable to showing bucketing encoding ("unsampled", "control",
	 * "treatment") to callers which is necessary if getBucket(). The downside is that now two
	 * functions exist where one would suffice.
	 *
	 * @private
	 * @return {string} AB-test bucket, `bucket.UNSAMPLED` by default, `bucket.CONTROL` or
	 *                  `bucket.TREATMENT` buckets otherwise.
	 */
	function getBucket() {
		return mwExperiments.getBucket( test, sessionId );
	}

	function isControl() {
		return getBucket() === bucket.CONTROL;
	}

	function isTreatment() {
		return getBucket() === bucket.TREATMENT;
	}

	/**
	 * Checks whether or not a user is in the AB-test,
	 *
	 * @private
	 * @return {boolean}
	 */
	function isSampled() {
		return getBucket() !== bucket.UNSAMPLED; // I.e., `isControl() || isTreatment()`
	}

	return {
		isControl: isControl,
		isTreatment: isTreatment,
		isSampled: isSampled
	};
}

module.exports = AB;
},"page-issues/overlay/IssueNotice.js":function(require,module,exports){const
	mobile = require( 'mobile.startup' ),
	View = mobile.View;

/**
 * IssueNotice
 *
 * @class
 * @ignore
 * @extends View
 *
 * @param {IssueSummary} props
 */
function IssueNotice( props ) {
	View.call( this, props );
}
OO.inheritClass( IssueNotice, View );
IssueNotice.prototype.tagName = 'li';
IssueNotice.prototype.template = mw.template.get( 'skins.minerva.scripts', 'IssueNotice.mustache' );
IssueNotice.prototype.postRender = function () {
	View.prototype.postRender.apply( this, arguments );
	this.$el.find( '.issue-notice' ).prepend( this.options.issue.iconElement );
};
module.exports = IssueNotice;
},"page-issues/overlay/IssueList.js":function(require,module,exports){const
	mobile = require( 'mobile.startup' ),
	View = mobile.View,
	IssueNotice = require( './IssueNotice.js' );

/**
 * IssueList
 *
 * @class
 * @ignore
 * @extends View
 *
 * @param {IssueSummary} issues
 */
function IssueList( issues ) {
	this.issues = issues;
	View.call( this, { className: 'cleanup' } );
}
OO.inheritClass( IssueList, View );
IssueList.prototype.tagName = 'ul';
IssueList.prototype.postRender = function () {
	View.prototype.postRender.apply( this, arguments );
	this.append(
		( this.issues || [] ).map( ( issue ) => new IssueNotice( issue ).$el )
	);
};
module.exports = IssueList;
},"page-issues/overlay/pageIssuesOverlay.js":function(require,module,exports){const Overlay = require( 'mobile.startup' ).Overlay;
const IssueList = require( './IssueList.js' );
const KEYWORD_ALL_SECTIONS = 'all';
const namespaceIds = mw.config.get( 'wgNamespaceIds' );
const NS_MAIN = namespaceIds[ '' ];
const NS_CATEGORY = namespaceIds.category;

/**
 * Overlay for displaying page issues
 *
 * @ignore
 * @param {IssueSummary[]} issues List of page issue
 *  summaries for display.
 * @param {string} section
 * @param {number} namespaceID
 * @return {Overlay}
 */
function pageIssuesOverlay( issues, section, namespaceID ) {
	// Note only the main namespace is expected to make use of section issues, so the
	// heading will always be minerva-meta-data-issues-section-header regardless of
	// namespace.
	const headingText = section === '0' || section === KEYWORD_ALL_SECTIONS ?
		getNamespaceHeadingText( namespaceID ) :
		mw.msg( 'minerva-meta-data-issues-section-header' );

	const overlay = new Overlay( {
		className: 'overlay overlay-issues',
		heading: '<strong>' + headingText + '</strong>'
	} );

	overlay.$el.find( '.overlay-content' ).append(
		new IssueList( issues ).$el
	);
	return overlay;
}

/**
 * Obtain a suitable heading for the issues overlay based on the namespace
 *
 * @private
 * @param {number} namespaceID is the namespace to generate heading for
 * @return {string} heading for overlay
 */
function getNamespaceHeadingText( namespaceID ) {
	switch ( namespaceID ) {
		case NS_CATEGORY:
			return mw.msg( 'mobile-frontend-meta-data-issues-categories' );
		case NS_MAIN:
			return mw.msg( 'mobile-frontend-meta-data-issues' );
		default:
			return '';
	}
}

module.exports = pageIssuesOverlay;
},"page-issues/page/PageIssueLearnMoreLink.js":function(require,module,exports){( function () {
	/**
	 * Creates a "read more" button with given text.
	 *
	 * @param {string} msg
	 * @return {jQuery}
	 */
	function newPageIssueLearnMoreLink( msg ) {
		return $( '<span>' )
			.addClass( 'ambox-learn-more' )
			.text( msg );
	}

	module.exports = newPageIssueLearnMoreLink;
}() );
},"page-issues/page/PageIssueLink.js":function(require,module,exports){( function () {
	/**
	 * Create a link element that opens the issues overlay.
	 *
	 * @param {string} labelText The text value of the element
	 * @return {jQuery}
	 */
	function newPageIssueLink( labelText ) {
		return $( '<a>' ).addClass( 'cleanup mw-mf-cleanup' ).text( labelText );
	}

	module.exports = newPageIssueLink;
}() );
},"page-issues/page/pageIssueFormatter.js":function(require,module,exports){( function () {
	const newPageIssueLink = require( './PageIssueLink.js' );
	const newPageIssueLearnMoreLink = require( './PageIssueLearnMoreLink.js' );

	/**
	 * Modifies the `issue` DOM to create a banner designed for single / multiple issue templates,
	 * and handles event-binding for that issues overlay.
	 *
	 * @param {IssueSummary} issue
	 * @param {string} msg
	 * @param {string} overlayUrl
	 * @param {Object} overlayManager
	 * @param {boolean} [multiple]
	 */
	function insertPageIssueBanner( issue, msg, overlayUrl, overlayManager, multiple ) {
		const $learnMoreEl = newPageIssueLearnMoreLink( msg );
		const $issueContainer = multiple ?
			issue.$el.parents( '.mbox-text-span, .mbox-text-div' ) :
			issue.$el.find( '.mbox-text' );
		const $clickContainer = multiple ? issue.$el.parents( '.mbox-text' ) : issue.$el;

		$issueContainer.prepend( issue.issue.iconElement );
		$issueContainer.prepend( $learnMoreEl );

		$clickContainer.on( 'click', () => {
			overlayManager.router.navigate( overlayUrl );
			return false;
		} );
	}

	/**
	 * Modifies the page DOM to insert a page-issue notice below the title of the page,
	 * containing a link with a message like "this page has issues".
	 * Used on category namespaces, or when page-issue banners have been disabled.
	 *
	 * @param {string} labelText
	 * @param {string} section
	 */
	function insertPageIssueNotice( labelText, section ) {
		const $link = newPageIssueLink( labelText );
		$link.attr( 'href', '#/issues/' + section );
		// eslint-disable-next-line no-jquery/no-global-selector
		$link.insertAfter( $( 'h1.mw-first-heading' ) );
	}

	module.exports = {
		insertPageIssueBanner,
		insertPageIssueNotice
	};
}() );
},"page-issues/index.js":function(require,module,exports){/**
 * @typedef {Object.<string, IssueSummary[]>} IssueSummaryMap
 * @ignore
 */

const PageHTMLParser = require( 'mobile.startup' ).PageHTMLParser;
const KEYWORD_ALL_SECTIONS = 'all';
const namespaceIds = mw.config.get( 'wgNamespaceIds' );
const NS_MAIN = namespaceIds[ '' ];
const NS_CATEGORY = namespaceIds.category;
const CURRENT_NS = mw.config.get( 'wgNamespaceNumber' );
const features = mw.config.get( 'wgMinervaFeatures', {} );
const pageIssuesParser = require( './parser.js' );
const pageIssuesOverlay = require( './overlay/pageIssuesOverlay.js' );
const pageIssueFormatter = require( './page/pageIssueFormatter.js' );
// When the query string flag is set force on new treatment.
// When wgMinervaPageIssuesNewTreatment is the default this line can be removed.
const QUERY_STRING_FLAG = mw.util.getParamValue( 'minerva-issues' );
const newTreatmentEnabled = features.pageIssues || QUERY_STRING_FLAG;

/**
 * Render a banner in a containing element.
 * if in group B, a learn more link will be append to any amboxes inside $container
 * if in group A or control, any amboxes in container will be removed and a link "page issues"
 * will be rendered above the heading.
 * This function comes with side effects. It will populate a global "allIssues" object which
 * will link section numbers to issues.
 *
 * @param {PageHTMLParser} pageHTMLParser parser to search for page issues
 * @param {string} labelText what the label of the page issues banner should say
 * @param {string} section that the banner and its issues belong to.
 *  If string KEYWORD_ALL_SECTIONS banner should apply to entire page.
 * @param {boolean} inline - if true the first ambox in the section will become the entry point
 *                           for the issues overlay
 *  and if false, a link will be rendered under the heading.
 * @param {OverlayManager} overlayManager
 * @ignore
 *
 * @return {{ambox: jQuery, issueSummaries: IssueSummary[]}}
 */
function insertBannersOrNotice( pageHTMLParser, labelText, section, inline, overlayManager ) {
	const issueUrl = section === KEYWORD_ALL_SECTIONS ? '#/issues/' + KEYWORD_ALL_SECTIONS : '#/issues/' + section;
	const selector = [ '.ambox', '.tmbox', '.cmbox', '.fmbox' ].join( ',' );
	const issueSummaries = [];

	const $metadata = section === KEYWORD_ALL_SECTIONS ?
		pageHTMLParser.$el.find( selector ) :
		// find heading associated with the section
		pageHTMLParser.findChildInSectionLead( parseInt( section, 10 ), selector );
	// clean it up a little
	$metadata.find( '.NavFrame' ).remove();
	$metadata.each( ( _i, el ) => {
		const $el = $( el );

		if ( $el.find( selector ).length === 0 ) {
			const issueSummary = pageIssuesParser.extract( $el );
			// Some issues after "extract" has been run will have no text.
			// For example in Template:Talk header the table will be removed and no issue found.
			// These should not be rendered.
			if ( issueSummary.text ) {
				issueSummaries.push( issueSummary );
			}
		}
	} );

	if ( inline ) {
		issueSummaries.forEach( ( issueSummary, i ) => {
			const isGrouped = issueSummary.issue.grouped;
			const lastIssueIsGrouped = issueSummaries[ i - 1 ] &&
				issueSummaries[ i - 1 ].issue.grouped;
			const multiple = isGrouped && !lastIssueIsGrouped;
			// only render the first grouped issue of each group
			pageIssueFormatter.insertPageIssueBanner(
				issueSummary,
				mw.msg( 'skin-minerva-issue-learn-more' ),
				issueUrl,
				overlayManager,
				multiple
			);
		} );
	} else if ( issueSummaries.length ) {
		pageIssueFormatter.insertPageIssueNotice( labelText, section );
	}

	return {
		ambox: $metadata,
		issueSummaries: issueSummaries
	};
}

/**
 * Obtains the list of issues for the current page and provided section
 *
 * @ignore
 * @param {IssueSummaryMap} allIssues Mapping section {number}
 *  to {IssueSummary}
 * @param {number|string} section either KEYWORD_ALL_SECTIONS or a number relating to the
 *                                section the issues belong to
 * @return {jQuery[]} array of all issues.
 */
function getIssues( allIssues, section ) {
	if ( section !== KEYWORD_ALL_SECTIONS ) {
		return allIssues[ section ] || [];
	}
	// Note section.all may not exist, depending on the structure of the HTML page.
	// It will only exist when Minerva has been run in desktop mode.
	// If it's absent, we'll reduce all the other lists into one.
	return allIssues[ KEYWORD_ALL_SECTIONS ] || Object.keys( allIssues ).reduce(
		( all, key ) => all.concat( allIssues[ key ] ),
		[]
	);
}

/**
 * Scan an element for any known cleanup templates and replace them with a button
 * that opens them in a mobile friendly overlay.
 *
 * @ignore
 * @param {OverlayManager} overlayManager
 * @param {PageHTMLParser} pageHTMLParser
 */
function initPageIssues( overlayManager, pageHTMLParser ) {
	let section;
	let issueSummaries = [];
	const allIssues = {};
	const $lead = pageHTMLParser.getLeadSectionElement();
	const issueOverlayShowAll = CURRENT_NS === NS_CATEGORY || !$lead;
	const inline = newTreatmentEnabled && CURRENT_NS === NS_MAIN;

	// set A-B test class.
	// When wgMinervaPageIssuesNewTreatment is the default this can be removed.
	if ( newTreatmentEnabled ) {
		$( document.documentElement ).addClass( 'issues-group-B' );
	}

	if ( CURRENT_NS === NS_CATEGORY ) {
		section = KEYWORD_ALL_SECTIONS;
		// e.g. Template:English variant category; Template:WikiProject
		issueSummaries = insertBannersOrNotice( pageHTMLParser, mw.msg( 'mobile-frontend-meta-data-issues-header' ),
			section, inline, overlayManager ).issueSummaries;
		allIssues[ section ] = issueSummaries;
	} else if ( CURRENT_NS === NS_MAIN ) {
		const label = mw.msg( 'mobile-frontend-meta-data-issues-header' );
		if ( issueOverlayShowAll ) {
			section = KEYWORD_ALL_SECTIONS;
			issueSummaries = insertBannersOrNotice(
				pageHTMLParser, label, section, inline, overlayManager
			).issueSummaries;
			allIssues[ section ] = issueSummaries;
		} else {
			// parse lead
			section = '0';
			issueSummaries = insertBannersOrNotice(
				pageHTMLParser, label, section, inline, overlayManager
			).issueSummaries;
			allIssues[ section ] = issueSummaries;
			if ( newTreatmentEnabled ) {
				// parse other sections but only in group B. In treatment A no issues are shown
				// for sections.
				pageHTMLParser.$el.find( PageHTMLParser.HEADING_SELECTOR ).each(
					( i, headingEl ) => {
						const $headingEl = $( headingEl );
						// section number is absent on protected pages, when this is the case
						// use i, otherwise icon will not show (T340910)
						const sectionNum = $headingEl.find( '.edit-page' ).data( 'section' ) || i;

						// Note certain headings matched using
						// PageHTMLParser.HEADING_SELECTOR may not be headings and will
						// not have a edit link. E.g. table of contents.
						if ( sectionNum ) {
							// Render banner for sectionNum associated with headingEl inside
							// Page
							section = sectionNum.toString();
							issueSummaries = insertBannersOrNotice(
								pageHTMLParser, label, section, inline, overlayManager
							).issueSummaries;
							allIssues[ section ] = issueSummaries;
						}
					}
				);
			}
		}
	}

	// Setup the overlay route.
	overlayManager.add( new RegExp( '^/issues/(\\d+|' + KEYWORD_ALL_SECTIONS + ')$' ), ( s ) => pageIssuesOverlay(
		getIssues( allIssues, s ), s, CURRENT_NS
	) );
}

module.exports = {
	init: initPageIssues,
	test: {
		insertBannersOrNotice: insertBannersOrNotice
	}
};
},"UriUtil.js":function(require,module,exports){/**
 * Compares the default Uri host, usually `window.location.host`, and `mw.Uri.host`. Equivalence
 * tests internal linkage, a mismatch may indicate an external link. Interwiki links are
 * considered external.
 *
 * This function only indicates internal in the sense of being on the same host or not. It has
 * no knowledge of [[Link]] vs [Link] links.
 *
 * On https://meta.wikimedia.org/wiki/Foo, the following links would be considered *internal*
 * and return `true`:
 *
 *     https://meta.wikimedia.org/
 *     https://meta.wikimedia.org/wiki/Bar
 *     https://meta.wikimedia.org/w/index.php?title=Bar
 *
 * Similarly, the following links would be considered *not* internal and return `false`:
 *
 *     https://archive.org/
 *     https://foo.wikimedia.org/
 *     https://en.wikipedia.org/
 *     https://en.wikipedia.org/wiki/Bar
 *
 * @ignore
 * @param {mw.Uri} uri
 * @return {boolean}
 */
function isInternal( uri ) {
	try {
		// mw.Uri can throw exceptions (T264914, T66884)
		return uri.host === mw.Uri().host;
	} catch ( e ) {
		return false;
	}
}

module.exports = {
	isInternal
};
},"TitleUtil.js":function(require,module,exports){// Someone has to maintain this wherever it lives. If it live in Core, it becomes a public API.
// If it lives in some client-side target of mediawiki-title that accepts a MediaWiki config instead
// of a SiteInfo, it still becomes a public API. If it lives where used, it becomes a copy and paste
// implementation where each copy can deviate but deletion is easy. See additional discussion in
// T218358 and I95b08e77eece5cd4dae62f6f237d492d6b0fe42b.
const UriUtil = require( './UriUtil.js' );

/**
 * Returns the decoded wiki page title referenced by the passed link as a string when parsable.
 * The title query parameter is returned, if present. Otherwise, a heuristic is used to attempt
 * to extract the title from the path.
 *
 * The API is the source of truth for page titles. This function should only be used in
 * circumstances where the API cannot be consulted.
 *
 * Assuming the current page is on metawiki, consider the following example links and
 * `newFromUri()` outputs:
 *
 *     https://meta.wikimedia.org/wiki/Foo → Foo (path title)
 *     http://meta.wikimedia.org/wiki/Foo → Foo (mismatching protocol)
 *     /wiki/Foo → Foo (relative URI)
 *     /w/index.php?title=Foo → Foo (title query parameter)
 *     /wiki/Talk:Foo → Talk:Foo (non-main namespace URI)
 *     /wiki/Foo bar → Foo_bar (name with spaces)
 *     /wiki/Foo%20bar → Foo_bar (name with percent encoded spaces)
 *     /wiki/Foo+bar → Foo+bar (name with +)
 *     /w/index.php?title=Foo%2bbar → Foo+bar (query parameter with +)
 *     / → null (mismatching article path)
 *     /wiki/index.php?title=Foo → null (mismatching script path)
 *     https://archive.org/ → null (mismatching host)
 *     https://foo.wikimedia.org/ → null (mismatching host)
 *     https://en.wikipedia.org/wiki/Bar → null (mismatching host)
 *
 * This function invokes `Uri.isInternal()` to validate that this link is assuredly a local
 * wiki link and that the internal usage of both the title query parameter and value of
 * wgArticlePath are relevant.
 *
 * This function doesn't throw. `null` is returned for any unparseable input.
 *
 * @ignore
 * @param {mw.Uri|Object|string} [uri] Passed to Uri.
 * @param {Object|boolean} [options] Passed to Uri.
 * @param {Object|boolean} [options.validateReadOnlyLink] If true, only links that would show a
 *     page for reading are considered. E.g., `/wiki/Foo` and `/w/index.php?title=Foo` would
 *     validate but `/w/index.php?title=Foo&action=bar` would not.
 * @return {mw.Title|null} A Title or `null`.
 */
function newFromUri( uri, options ) {
	let mwUri;
	let title;

	try {
		// uri may or may not be a Uri but the Uri constructor accepts a Uri parameter.
		mwUri = new mw.Uri( uri, options );
	} catch ( e ) {
		return null;
	}

	if ( !UriUtil.isInternal( mwUri ) ) {
		return null;
	}

	if ( ( options || {} ).validateReadOnlyLink && !isReadOnlyUri( mwUri ) ) {
		// An unknown query parameter is used. This may not be a read-only link.
		return null;
	}

	if ( mwUri.query.title ) {
		// True if input starts with wgScriptPath.

		const regExp = new RegExp( '^' + mw.util.escapeRegExp( mw.config.get( 'wgScriptPath' ) ) + '/' );

		// URL has a nonempty `title` query parameter like `/w/index.php?title=Foo`. The script
		// path should match.
		const matches = regExp.test( mwUri.path );
		if ( !matches ) {
			return null;
		}

		// The parameter was already decoded at Uri construction.
		title = mwUri.query.title;
	} else {
		// True if input starts with wgArticlePath and ends with a nonempty page title. The
		// first matching group (index 1) is the page title.

		const regExp = new RegExp( '^' + mw.util.escapeRegExp( mw.config.get( 'wgArticlePath' ) ).replace( '\\$1', '(.+)' ) );

		// No title query parameter is present so the URL may be "pretty" like `/wiki/Foo`.
		// `Uri.path` should not contain query parameters or a fragment, as is assumed in
		// `Uri.getRelativePath()`. Try to isolate the title.
		const matches = regExp.exec( mwUri.path );
		if ( !matches || !matches[ 1 ] ) {
			return null;
		}

		try {
			// `Uri.path` was not previously decoded, as is assumed in `Uri.getRelativePath()`,
			// and decoding may now fail. Do not use `Uri.decode()` which is designed to be
			// paired with `Uri.encode()` and replaces `+` characters with spaces.
			title = decodeURIComponent( matches[ 1 ] );
		} catch ( e ) {
			return null;
		}
	}

	// Append the fragment, if present.
	title += mwUri.fragment ? '#' + mwUri.fragment : '';

	return mw.Title.newFromText( title );
}

/**
 * Validates that the passed link is for reading.
 *
 * The following links return true:
 *     /wiki/Foo
 *     /w/index.php?title=Foo
 *     /w/index.php?oldid=123
 *
 * The following links return false:
 *     /w/index.php?title=Foo&action=bar
 *
 * @private
 * @static
 * @method isReadOnlyUri
 * @param {mw.Uri} uri A Uri to an internal wiki page.
 * @return {boolean} True if uri has no query parameters or only known parameters for reading.
 */
function isReadOnlyUri( uri ) {
	const length = Object.keys( uri.query ).length;
	return length === ( ( 'oldid' in uri.query ? 1 : 0 ) + ( 'title' in uri.query ? 1 : 0 ) );
}

module.exports = {
	newFromUri
};
},"../../includes/Skins/ToggleList/ToggleList.js":function(require,module,exports){( function () {
	const
		checkboxHack = require( ( 'mediawiki.page.ready' ) ).checkboxHack,
		CHECKBOX_HACK_CONTAINER_SELECTOR = '.toggle-list',
		CHECKBOX_HACK_CHECKBOX_SELECTOR = '.toggle-list__checkbox',
		CHECKBOX_HACK_BUTTON_SELECTOR = '.toggle-list__toggle',
		CHECKBOX_HACK_TARGET_SELECTOR = '.toggle-list__list';

	/**
	 * Automatically dismiss the list when clicking or focusing elsewhere and update the
	 * aria-expanded attribute based on list visibility.
	 *
	 * @param {Window} window
	 * @param {HTMLElement} component
	 */
	function bind( window, component ) {
		const
			checkbox = /** @type {HTMLInputElement} */ (
				component.querySelector( CHECKBOX_HACK_CHECKBOX_SELECTOR )
			),
			button = component.querySelector( CHECKBOX_HACK_BUTTON_SELECTOR ),
			target = component.querySelector( CHECKBOX_HACK_TARGET_SELECTOR ).parentNode;

		if ( !( checkbox && button && target ) ) {
			return;
		}
		checkboxHack.bind( window, checkbox, button, target );
	}

	module.exports = Object.freeze( {
		selector: CHECKBOX_HACK_CONTAINER_SELECTOR,
		bind
	} );
}() );
},"TabScroll.js":function(require,module,exports){let scrollLeftStyle = null;

function testScrollLeftStyle() {
	if ( scrollLeftStyle !== null ) {
		return scrollLeftStyle;
	}
	// Detect which scrollLeft style the browser uses
	// Adapted from <https://github.com/othree/jquery.rtl-scroll-type>.
	// Original code copyright 2012 Wei-Ko Kao, licensed under the MIT License.
	// Adaptation copied from OO.ui.Element.static.getScrollLeft
	const $definer = $( '<div>' ).attr( {
		dir: 'rtl',
		style: 'font-size: 14px; width: 4px; height: 1px; position: absolute; top: -1000px; overflow: scroll;'
	} ).text( 'ABCD' );
	$definer.appendTo( document.body );
	const definer = $definer[ 0 ];
	if ( definer.scrollLeft > 0 ) {
		// Safari, Chrome
		scrollLeftStyle = 'default';
	} else {
		definer.scrollLeft = 1;
		if ( definer.scrollLeft === 0 ) {
			// Firefox, old Opera
			scrollLeftStyle = 'negative';
		} else {
			// Internet Explorer, Edge
			scrollLeftStyle = 'reverse';
		}
	}
	$definer.remove();
	return scrollLeftStyle;
}

/**
 * When tabs are present and one is selected, scroll the selected tab into view.
 *
 * @ignore
 */
function initTabsScrollPosition() {
	// eslint-disable-next-line no-jquery/no-global-selector
	const $selectedTab = $( '.minerva__tab.selected' );
	if ( $selectedTab.length !== 1 ) {
		return;
	}
	const selectedTab = $selectedTab.get( 0 );
	const $tabContainer = $selectedTab.closest( '.minerva__tab-container' );
	const tabContainer = $tabContainer.get( 0 );
	const maxScrollLeft = tabContainer.scrollWidth - tabContainer.clientWidth;
	const dir = $tabContainer.css( 'direction' ) || 'ltr';

	/**
	 * Set tabContainer.scrollLeft, with adjustments for browser inconsistencies in RTL
	 *
	 * @param {number} sl New .scrollLeft value, in 'default' (WebKit) style
	 */
	function setScrollLeft( sl ) {
		if ( dir === 'ltr' ) {
			tabContainer.scrollLeft = sl;
			return;
		}

		if ( testScrollLeftStyle() === 'reverse' ) {
			sl = maxScrollLeft - sl;
		} else if ( testScrollLeftStyle() === 'negative' ) {
			sl = -( maxScrollLeft - sl );
		}
		tabContainer.scrollLeft = sl;
	}

	const leftMostChild = dir === 'ltr' ? tabContainer.firstElementChild : tabContainer.lastElementChild;
	const rightMostChild = dir === 'ltr' ? tabContainer.lastElementChild : tabContainer.firstElementChild;
	// If the tab is wider than the container (doesn't fit), this value will be negative
	const widthDiff = tabContainer.clientWidth - selectedTab.clientWidth;

	if ( selectedTab === leftMostChild ) {
		// The left-most tab is selected. If the tab fits, scroll all the way to the left.
		// If the tab doesn't fit, align its start edge with the container's start edge.
		if ( dir === 'ltr' || widthDiff >= 0 ) {
			setScrollLeft( 0 );
		} else {
			setScrollLeft( -widthDiff );
		}
	} else if ( selectedTab === rightMostChild ) {
		// The right-most tab is selected. If the tab fits, scroll all the way to the right.
		// If the tab doesn't fit, align its start edge with the container's start edge.
		if ( dir === 'rtl' || widthDiff >= 0 ) {
			setScrollLeft( maxScrollLeft );
		} else {
			setScrollLeft( maxScrollLeft + widthDiff );
		}
	} else {
		// The selected tab is not the left-most or right-most, it's somewhere in the middle
		const tabPosition = $selectedTab.position();
		const containerPosition = $tabContainer.position();
		// Position of the left edge of $selectedTab relative to the left edge of $tabContainer
		const left = tabPosition.left - containerPosition.left;
		// Because the calculations above use the existing .scrollLeft from the browser,
		// we should not use setScrollLeft() here. Instead, we rely on the fact that scrollLeft
		// increases to the left in the 'default' and 'negative' modes, and to the right in
		// the 'reverse' mode, so we can add/subtract a delta to/from scrollLeft accordingly.
		let increaseScrollLeft;
		if ( widthDiff >= 0 ) {
			// The tab fits, center it
			increaseScrollLeft = left - widthDiff / 2;
		} else if ( dir === 'ltr' ) {
			// The tab doesn't fit (LTR), align its left edge with the container's left edge
			increaseScrollLeft = left;
		} else {
			// The tab doesn't fit (RTL), align its right edge with the container's right edge
			increaseScrollLeft = left - widthDiff;
		}
		tabContainer.scrollLeft += increaseScrollLeft *
			( testScrollLeftStyle() === 'reverse' ? -1 : 1 );
	}
}

module.exports = {
	initTabsScrollPosition: initTabsScrollPosition
};
},"Toolbar.js":function(require,module,exports){const
	mobile = require( 'mobile.startup' ),
	ToggleList = require( '../../includes/Skins/ToggleList/ToggleList.js' ),
	page = mobile.currentPage(),
	// The top level menu.
	selector = '.page-actions-menu',
	// The secondary overflow submenu component container.
	overflowSubmenuSelector = '#page-actions-overflow',
	overflowListSelector = '.toggle-list__list';

/**
 * @param {Window} window
 * @param {Element} toolbar
 * @ignore
 */
function bind( window, toolbar ) {
	const overflowSubmenu = toolbar.querySelector( overflowSubmenuSelector );
	if ( overflowSubmenu ) {
		ToggleList.bind( window, overflowSubmenu );
	}
}

/**
 * @param {Window} window
 * @param {Element} toolbar
 * @ignore
 */
function render( window, toolbar ) {
	const overflowList = toolbar.querySelector( overflowListSelector );
	checkForReadOnlyMode();
	renderDownloadButton( window, overflowList );
}

/**
 * Initialize page edit action link (#ca-edit) for read only mode.
 * (e.g. when $wgReadOnly is set in LocalSettings.php)
 *
 * Mark the edit link as disabled if the user is not actually able to edit the page for some
 * reason (e.g. page is protected or user is blocked).
 *
 * Note that the link is still clickable, but clicking it will probably open a view-source
 * form or display an error message, rather than open an edit form.
 *
 * This check occurs in JavaScript as anonymous page views are cached
 * in Varnish.
 *
 * @ignore
 */
function checkForReadOnlyMode() {
	if ( mw.config.get( 'wgMinervaReadOnly' ) ) {
		document.body.classList.add( 'minerva-read-only' );
	}
}

/**
 * Initialize and inject the download button
 *
 * There are many restrictions when we can show the download button, this function should handle
 * all device/os/operating system related checks and if device supports printing it will inject
 * the Download icon
 *
 * @ignore
 * @param {Window} window
 * @param {Element|null} overflowList
 */
function renderDownloadButton( window, overflowList ) {
	const downloadPageAction = require( './downloadPageAction.js' ).downloadPageAction,
		$downloadAction = downloadPageAction( page,
			mw.config.get( 'wgMinervaDownloadNamespaces', [] ), window, !!overflowList );

	if ( $downloadAction ) {
		mw.track( 'minerva.downloadAsPDF', {
			action: 'buttonVisible'
		} );
	}
}

module.exports = {
	selector,
	bind,
	render
};
},"mobileRedirect.js":function(require,module,exports){const drawers = require( './drawers.js' );

/*
 * Warn people if they're trying to switch to desktop but have cookies disabled.
 */
module.exports = function ( amcOutreach, currentPage ) {
	/**
	 * Checks whether cookies are enabled
	 *
	 * @method
	 * @ignore
	 * @return {boolean} Whether cookies are enabled
	 */
	function cookiesEnabled() {
		// If session cookie already set, return true
		if ( mw.cookie.get( 'mf_testcookie' ) === 'test_value' ) {
			return true;
			// Otherwise try to set mf_testcookie and return true if it was set
		} else {
			mw.cookie.set( 'mf_testcookie', 'test_value', {
				path: '/'
			} );
			return mw.cookie.get( 'mf_testcookie' ) === 'test_value';
		}
	}

	/**
	 * An event handler for the toggle to desktop link.
	 * If cookies are enabled it will redirect you to desktop site as described in
	 * the link href associated with the handler.
	 * If cookies are not enabled, show a toast and die.
	 *
	 * @method
	 * @ignore
	 * @return {boolean|undefined}
	 */
	function desktopViewClick() {
		if ( !cookiesEnabled() ) {
			mw.notify(
				mw.msg( 'mobile-frontend-cookies-required' ),
				{ type: 'error' }
			);
			// Prevent default action
			return false;
		}
	}

	/**
	 * @method
	 * @ignore
	 * @param {jQuery.Event} ev
	 * @return {boolean|undefined}
	 */
	function amcDesktopClickHandler( ev ) {
		const self = this;
		const executeWrappedEvent = function () {
			if ( desktopViewClick() === false ) {
				return false;
			}

			window.location = self.href;
		};
		const amcCampaign = amcOutreach.loadCampaign();
		const onDismiss = function () {
			executeWrappedEvent();
		};
		const drawer = amcCampaign.showIfEligible(
			amcOutreach.ACTIONS.onDesktopLink,
			onDismiss,
			currentPage.title
		);

		if ( drawer ) {
			ev.preventDefault();
			// stopPropagation is needed to prevent drawer from immediately closing
			// when shown (drawers.js adds a click event to window when drawer is
			// shown
			ev.stopPropagation();

			drawers.displayDrawer( drawer, {} );
			drawers.lockScroll();

			return;
		}

		return executeWrappedEvent();
	}

	// eslint-disable-next-line no-jquery/no-global-selector
	$( '#mw-mf-display-toggle' ).on( 'click', amcDesktopClickHandler );
};
},"search.js":function(require,module,exports){module.exports = function () {
	const mobile = require( 'mobile.startup' );
	const SearchOverlay = mobile.search.SearchOverlay;
	const SearchGateway = mobile.search.SearchGateway;
	const overlayManager = mobile.getOverlayManager();
	// eslint-disable-next-line no-jquery/no-global-selector
	const $searchInput = $( '#searchInput' );
	const placeholder = $searchInput.attr( 'placeholder' );
	const defaultSearchPage = $searchInput.siblings( 'input[name=title]' ).val();
	// eslint-disable-next-line no-jquery/no-global-selector
	const $searchBar = $( '#searchInput, #searchIcon, .skin-minerva-search-trigger' );
	const searchRoute = new RegExp( /\/search/ );
	let searchOverlayInstance;

	// Only continue on mobile devices as it breaks desktop search
	// See https://phabricator.wikimedia.org/T108432
	if ( mw.config.get( 'skin' ) !== 'minerva' ) {
		return;
	}

	/**
	 * Hide the search overlay on pageload before the search route
	 * is registered with the overlayManager.
	 * Allows the usage of history.back() to close searchOverlay by
	 * preventing the situation described in https://phabricator.wikimedia.org/T102946
	 */
	function removeSearchOnPageLoad() {
		if ( searchRoute.test( overlayManager.router.getPath() ) ) {
			// TODO: replace when router supports replaceState https://phabricator.wikimedia.org/T189173
			history.replaceState( '', document.title, window.location.pathname );
		}
	}

	function getSearchOverlay() {
		if ( !searchOverlayInstance ) {
			searchOverlayInstance = new SearchOverlay( {
				router: overlayManager.router,
				gatewayClass: SearchGateway,
				api: new mw.Api(),
				autocapitalize: $searchInput.attr( 'autocapitalize' ),
				searchTerm: $searchInput.val(),
				placeholderMsg: placeholder,
				defaultSearchPage: defaultSearchPage
			} );
		}
		return searchOverlayInstance;
	}

	removeSearchOnPageLoad();
	overlayManager.add( searchRoute, getSearchOverlay );

	// Apparently needed for main menu to work correctly.
	$searchBar.prop( 'readonly', true );

	/**
	 * Trigger overlay on touchstart so that the on-screen keyboard on iOS
	 * can be triggered immidiately after on touchend. The keyboard can't be
	 * triggered unless the element is already visible.
	 * Touchstart makes the overlay visible, touchend brings up the keyboard afterwards.
	 */
	$searchBar.on( 'touchstart click', ( ev ) => {
		ev.preventDefault();
		overlayManager.router.navigate( '/search' );
	} );

	$searchBar.on( 'touchend', ( ev ) => {
		ev.preventDefault();
		/**
		 * Manually triggering focus event because on-screen keyboard only
		 * opens when `focus()` is called from a "user context event",
		 * Calling it from the route callback above (which calls SearchOverlay#show)
		 * doesn't work.
		 * http://stackoverflow.com/questions/6837543/show-virtual-keyboard-on-mobile-phones-in-javascript
		 */
		getSearchOverlay().showKeyboard();
	} );

};
},"references.js":function(require,module,exports){const drawers = require( './drawers.js' );

module.exports = function () {

	const mobile = require( 'mobile.startup' );
	const references = mobile.references;
	const currentPage = mobile.currentPage();
	const currentPageHTMLParser = mobile.currentPageHTMLParser();
	const ReferencesHtmlScraperGateway = mobile.references.ReferencesHtmlScraperGateway;
	const gateway = new ReferencesHtmlScraperGateway( new mw.Api() );

	/**
	 * Event handler to show reference when a reference link is clicked
	 *
	 * @ignore
	 * @param {jQuery.Event} ev Click event of the reference element
	 */
	function showReference( ev ) {
		const $dest = $( ev.currentTarget );
		let href = $dest.attr( 'href' );

		ev.preventDefault();

		// If necessary strip the URL portion of the href so we are left with the
		// fragment
		const i = href.indexOf( '#' );
		if ( i > 0 ) {
			href = href.slice( i );
		}

		references.showReference( href, currentPage, $dest.text(),
			currentPageHTMLParser, gateway, {
				onShow: function () {
					drawers.lockScroll();
				},
				onShowNestedReference: true,
				onBeforeHide: drawers.discardDrawer
			},
			( oldDrawer, newDrawer ) => {
				oldDrawer.hide();
				drawers.displayDrawer( newDrawer, {} );
			}
		).then( ( drawer ) => {
			drawers.displayDrawer( drawer, {} );
		} );
	}

	/**
	 * Event handler to show reference when a reference link is clicked.
	 * Delegates to `showReference` once the references drawer is ready.
	 *
	 * @ignore
	 * @param {jQuery.Event} ev Click event of the reference element
	 */
	function onClickReference( ev ) {
		showReference( ev );
	}

	function init() {
		// Make references clickable and show a drawer when clicked on.
		$( document ).on( 'click', 'sup.reference a', onClickReference );
	}

	init();
};
},"watchstar.js":function(require,module,exports){const watchstar = require( 'mediawiki.page.watch.ajax' ).watchstar;
const WATCHED_ICON_CLASS = 'minerva-icon--unStar';
const TEMP_WATCHED_ICON_CLASS = 'minerva-icon--halfStar';
const UNWATCHED_ICON_CLASS = 'minerva-icon--star';

/**
 * Tweaks the global watchstar handler in core to use the correct classes for Minerva.
 *
 * @param {jQuery} $icon
 * @ignore
 */
function init( $icon ) {
	const $watchlink = $icon.find( 'a' );
	watchstar( $watchlink, mw.config.get( 'wgRelevantPageName' ), toggleClasses );
}

/**
 * @param {jQuery} $link
 * @param {boolean} isWatched
 * @param {string} expiry
 * @private
 */
function toggleClasses( $link, isWatched, expiry ) {
	const $icon = $link.find( '.minerva-icon' );
	$icon.removeClass( [ WATCHED_ICON_CLASS, UNWATCHED_ICON_CLASS, TEMP_WATCHED_ICON_CLASS ] )
		.addClass( () => {
			let classes = UNWATCHED_ICON_CLASS;
			if ( isWatched ) {
				if ( expiry !== null && expiry !== undefined && expiry !== 'infinity' ) {
					classes = TEMP_WATCHED_ICON_CLASS;
				} else {
					classes = WATCHED_ICON_CLASS;
				}
			}
			return classes;
		} );
}

module.exports = {
	init: init,
	test: {
		toggleClasses,
		TEMP_WATCHED_ICON_CLASS,
		WATCHED_ICON_CLASS,
		UNWATCHED_ICON_CLASS
	}
};
}}}];});
/*
MediaWiki:Gadget-rsw-util.js
*/
(function ($, mw, rs) {

    'use strict';
	
	function createOOUIWindowManager() {
		if (window.OOUIWindowManager == undefined) {
	        window.OOUIWindowManager = new OO.ui.WindowManager();
	    	$( 'body' ).append( window.OOUIWindowManager.$element );
		}
    	return window.OOUIWindowManager;
	}

    /**
     * Reusable functions
     *
     * These are available under the `rswiki` global variable.
     * @example `rswiki.addCommas`
     * The alias `rs` is also available in place of `rswiki`.
     */
    var util = {
        /**
         * Formats a number string with commas.
         *
         * @todo fully replace this with Number.protoype.toLocaleString
         *       > 123456.78.toLocaleString('en')
         *
         * @example 123456.78 -> 123,456.78
         *
         * @param num {Number|String} The number to format.
         * @return {String} The formated number.
         */
        addCommas: function (num) {
            if (typeof num === 'number') {
                return num.toLocaleString('en');
            }

            // @todo chuck this into parseFloat first and then to toLocaleString?
            num += '';

            var x = num.split('.'),
                x1 = x[0],
                x2 = x.length > 1 ?
                    '.' + x[1] :
                    '',
                rgx = /(\d+)(\d{3})/;

            while (rgx.test(x1)) {
                x1 = x1.replace(rgx, '$1,$2');
            }

            return x1 + x2;
        },

        /**
         * Extracts parameter-argument pairs from templates.
         *
         * @todo Fix for multiple templates
         *
         * @param tpl {String} Template to extract data from.
         * @param text {String} Text to look for template in.
         * @return {Object} Object containing parameter-argument pairs
         */
        parseTemplate: function (tpl, text) {
            var rgx = new RegExp(
                    '\\{\\{(template:)?' + tpl.replace(/[ _]/g, '[ _]') + '\\s*(\\||\\}\\})',
                    'i'
                ),
                exec = rgx.exec(text),
                // splits template into |arg=param or |param
                paramRgx = /\|(.*?(\{\{.+?\}\})?)(?=\s*\||$)/g,
                args = {},
                params,
                i,
                j;

            // happens if the template is not found in the text
            if (exec === null) {
                return false;
            }

            text = text.substring(exec.index + 2);

            // used to account for nested templates
            j = 0;

            // this purposefully doesn't use regex
            // as it became very difficult to make it work properly
            for (i = 0; i < text.length; i += 1) {
                if (text[i] === '{') {
                    j += 1;
                } else if (text[i] === '}') {
                    if (j > 0) {
                        j -= 1;
                    } else {
                        break;
                    }
                }
            }

            // cut off where the template ends
            text = text.substring(0, i);
            // remove template name as we're not interested in it past this point
            text = text.substring(text.indexOf('|')).trim();
            // separate params and args into an array
            params = text.match(paramRgx);

            // handle no params/args
            if (params !== null) {
                // used as an index for unnamed params
                i = 1;

                params.forEach(function (el) {
                    var str = el.trim().substring(1),
                        eq = str.indexOf('='),
                        tpl = str.indexOf('{{'),
                        param,
                        val;

                    // checks if the equals is after opening a template
                    // to catch unnamed args that have templates with named args as params
                    if (eq > -1 && (tpl === -1 || eq < tpl)) {
                        param = str.substring(0, eq).trim().toLowerCase();
                        val = str.substring(eq + 1).trim();
                    } else {
                        param = i;
                        val = str.trim();
                        i += 1;
                    }

                    args[param] = val;
                });
            }

            return args;
        },

        /**
         * Alternate version of `parseTemplate` for parsing exchange module data.
         *
         * @notes Only works for key-value pairs
         *
         * @param text {String} Text to parse.
         * @return {Object} Object containing parameter-argument pairs.
         */
        parseExchangeModule: function (text) {

                // strip down to just key-value pairs
            var str = text
                    .replace(/return\s*\{/, '')
                    .replace(/\}\s*$/, '')
                    .trim(),
                rgx = /\s*(.*?\s*=\s*(?:\{[\s\S]*?\}|.*?))(?=,?\n|$)/g,
                args = {},
                params = str.match(rgx);

            if (params !== null) {
                params.forEach(function (elem) {
                    var str = elem.trim(),
                        eq = str.indexOf('='),
                        param = str.substring(0, eq).trim().toLowerCase(),
                        val = str.substring(eq + 1).trim();

                    args[param] = val;
                });
            }

            return args;
        },

        /**
         * Helper for making cross domain requests to RuneScape's APIs.
         * If the APIs ever enable CORS, we can ditch this and do the lookup directly.
         *
         * @param url {string} The URL to look up
         * @param via {string} One of 'anyorigin', 'whateverorigin' or 'crossorigin'. Defaults to 'anyorigin'.
         *
         * @return {string} The URLto use to make the API request.
         */
        crossDomain: function (url, via) {
            switch (via) {
            case 'crossorigin':
                url = 'http://crossorigin.me/' + url;
                break;

            case 'whateverorigin':
                url = 'http://whateverorigin.org/get?url=' + encodeURIComponent( url ) + '&callback=?';
                break;

            case 'anyorigin':
            default:
                url = 'http://anyorigin.com/go/?url=' + encodeURIComponent( url ) + '&callback=?';
                break;
            }

            return url;
        },
        /**
         * Returns the OOUI window manager as a Promise. Will load OOUI (core and windows) and create the manager, if necessary.
         * 
         * @return {jQuery.Deferred} A jQuery Promise where window.OOUIWindowManager is will be defined
         * Chaining a .then will pass OOUIWindowManager to the function argument
         */
        withOOUIWindowManager: function() {
        	return mw.loader.using(['oojs-ui-core','oojs-ui-windows']).then(createOOUIWindowManager);
        },
        
        /**
         * Helper for creating and initializing a new OOUI Dialog object
         * After init, the window is added to the global Window Manager.
         * 
         * Will automatically load OOUI (core and windows) and create the window manager, if necessary. window.OOUIWindowManager will be defined within this.
         * 
         * @author JaydenKieran
         * 
         * @param name {string} The symbolic name of the window
         * @param title {string} The title of the window
         * @param winconfig {object} Object containing params for the OO.ui.Dialog obj
         * @param init {function} Function to be called to initialise the object
         * @param openNow {boolean} Whether the window should be opened instantly
         * @param autoClose {boolean} Autoclose when the user clicks outside of the modal
         *
         * @return {jquery.Deferred} The jQuery Promise returned by mw.loader.using
         * Chaining a .then will pass the created {OO.ui.Dialog} object as the function argument
         */
        createOOUIWindow: function(name, title, winconfig, init, openNow, autoClose) {
        	return mw.loader.using(['oojs-ui-core','oojs-ui-windows']).then(function(){
		    	createOOUIWindowManager();
		    	winconfig = winconfig || {};
		    	
				function myModal( config ) {
					myModal.super.call( this, config );
				}
				OO.inheritClass( myModal, OO.ui.Dialog ); 
				
				myModal.static.name = name;
				myModal.static.title = title;
				
				myModal.prototype.initialize = function () {
					myModal.super.prototype.initialize.call( this );
					init(this);
				}
				
				var modal = new myModal(winconfig);
				
				console.debug('Adding ' + myModal.static.name + ' to WindowManager');
				window.OOUIWindowManager.addWindows( [ modal ] );
				
				if (openNow) {
					window.OOUIWindowManager.openWindow(name);
				}
				
				if (autoClose) {
					$(document).on('click', function (e) {
						if (modal && modal.isVisible() && e.target.classList.contains('oo-ui-window-active')) {
							modal.close();
						};
					});
				}
				
				return modal;
        	});
        },
        
        /**
         * Helper for checking if the user's browser supports desktop notifications
         * @author JaydenKieran
         */
        canSendBrowserNotifs: function () {
		    if (!("Notification" in window)) {
		        console.warn("This browser does not support desktop notifications");
		        return false;
		    } else {
		        return true;
		    }
        },
        
        /**
         * Send a desktop/browser notification to a user, requires the page to be open
         * @author JaydenKieran
         * 
         * @param https://developer.mozilla.org/en-US/docs/Web/API/Notification/Notification
         * 
         * @return Notification object or null
         */
        sendBrowserNotif: function (title, opts) {
        	if (rs.canSendBrowserNotifs == false) {
        		return null;
        	}
			Notification.requestPermission().then(function(result) {
			    if (result === "granted") {
			    	console.debug('Firing desktop notification');
			    	var notif = new Notification(title, opts);
			    	notif.onclick = function(e) {
			    		window.focus();
			    	}
			    	return notif;
			    } else {
			        return null;
			    }
			});
        },
        
        /**
         * Check if the browser has support for localStorage
         * @author JaydenKieran
         * 
         * @return boolean
         **/
        hasLocalStorage: function() {
		    try {
		      localStorage.setItem('test', 'test')
		      localStorage.removeItem('test')
		      return true
		    } catch (e) {
		      return false
		    }
        },
        
        /**
         * Check if user is using dark mode
         * @author JaydenKieran
         * 
         * @return boolean
         **/
        isUsingDarkmode: function() {
        	if (typeof $.cookie('darkmode') === 'undefined') {
        		return false
        	} else {
        		return $.cookie('darkmode') === 'true'
        	}
        },
        
        /**
         * Gets a query string parameter from given URL or current href
         * @author JaydenKieran
         * 
         * @return string or null
         **/
         qsp: function(name, url) {
		    if (!url) url = window.location.href;
		    name = name.replace(/[\[\]]/g, '\\$&');
		    var regex = new RegExp('[?&]' + name + '(=([^&#]*)|&|#|$)'),
		        results = regex.exec(url);
		    if (!results) return null;
		    if (!results[2]) return '';
		    return decodeURIComponent(results[2].replace(/\+/g, ' '));
    	},

        /**
         * Get the URL for a file on the wiki, aganst the endpoint that is actually cached and fast.
         * Should probably not be used for images we expect to change frequently.
         * @author cookmeplox
         * 
         * @return string
         **/
        getFileURLCached: function(filename) {
            var base = window.location.origin;
            filename = filename.replace(/ /g,"_");
            filename = filename.replace(/\(/g, '%28').replace(/\)/g, '%29');
            var cb = '48781';
            return base + '/images/' + filename + '?' + cb;
        },
    	
    	isUsingStickyHeader: function() {
    		return ($('body').hasClass('wgl-stickyheader'))
    	}
    };

    function init() {
        $.extend(rs, util, {});
        // add rs as a global alias
        window.rs = rs;
    }

	init();

}(this.jQuery, this.mediaWiki, this.rswiki = this.rswiki || {}));
/*
MediaWiki:Gadget-switch-infobox.js
*/
/* switch infobox code for infoboxes
 * contains switching code for both:
 * * originalInfoboxes:
 *		older infobox switching, such as [[Template:Infobox Bonuses]]
 *		which works my generating complete infoboxes for each version
 * * moduleInfoboxes:
 *		newer switching, as implemented by [[Module:Infobox]]
 *		which generates one infobox and a resources pool for switching
 * * synced switches
 *		as generated by [[Module:Synced switch]] and its template
 * 
 * The script also facilitates synchronising infoboxes, so that if a button of one is pressed
 *	and another switchfobox on the same page also has that button, it will 'press' itself
 * This only activates if there are matching version parameters in the infoboxes (i.e. the button text is the same)
 * - thus it works best if the version parameters are all identical
 * 
 * TODO: OOUI? (probably not, its a little clunky and large for this. It'd need so much styling it isn't worthwhile)
 */
$(function () {
	var SWITCH_REF_REGEX = /^\$(\d+)/,
		CAN_LOCAL_STORAGE = true;
	function getGenderFromLS() {
		if (CAN_LOCAL_STORAGE) {
			var x = window.localStorage.getItem('gender-render');
			if (['m', 'f'].indexOf(x) > -1) {
				return x;
			}
		}
		return 'm';
	}
	/**
	 * Switch infobox psuedo-interface
	 * 
	 * Switch infoboxes are given several similar functions so that they can be called similarly
	 * This is essentially like an interface or class structure, except I'm too lazy to implement that
	 * 
	 * 		switchfo.beginSwitchEvent(event)
	 * 			the reactionary event to buttons being clicked/selects being selected/etc
	 * 			tells SwitchEventManager to switch all the boxes
	 * 			should extract an index and anchor from the currentTarget and pass that to the SwitchEventManager.trigger function
	 * 			event		the jQuery event fired from $.click/$.change/etc
	 * 
	 * 		switchfo.switch(index, anchor)
	 * 			do all the actual switching of the infobox to the infobox specified by the anchor and index
	 * 			prefer using the anchor if there is a conflict
	 * 
	 * 		switchfo.defaultVer()
	 * 			called during script init
	 * 			returns either an anchor for the default version, if manually specified, or false if there is no default specified
	 * 			the page will automatically switch to the default version, or to version 1, when loaded.
	 * 
	 */
	/** 
	 * Switch Infoboxes based on [[Module:Infobox]]
	 * 
	 * - the preferred way to do switch infoboxes
	 * - generates one table and a resources table, swaps resources into the table as required
	 * - with enough buttons, becomes a dropdown <select>
	 * 
	 * parameters
	 *	  $box	jQuery object representing the infobox itself (.infobox-switch)
	 *	  index   index of this infobox, from $.each
	 */
	function SwitchInfobox($box, index, version_index_offset) {
		var self = this;
		this.index = index;
		this.version_index_offset = version_index_offset;
		this.$infobox = $box;
		this.$infobox.data('SwitchInfobox', self);
		this.$resources = self.$infobox.next();
		this.$buttons = self.$infobox.find('div.infobox-buttons');
		this.version_count = this.$buttons.find('span.button').length;
		this.isSelect = self.$buttons.hasClass('infobox-buttons-select');
		this.$select = null;
		this.originalClasses = {};

		/* click/change event - triggers switch event manager */
		this.beginSwitchEvent = function(e) {
			var $tgt = $(e.currentTarget);
			mw.log('beginSwitchEvent triggered in module infobox, id '+self.index);
			if (self.isSelect) {
				window.switchEventManager.trigger($tgt.val(), $tgt.find(' > option[data-switch-index='+$tgt.val()+']').attr('data-switch-anchor'), self);
			} else {
				window.switchEventManager.trigger($tgt.attr('data-switch-index'), $tgt.attr('data-switch-anchor'), self);
			}
		};

		/* switch event, triggered by manager */
		this.switchInfobox = function(index, text) {
			if (text === '@init@') {
				text = self.$buttons.find('[data-switch-index="1"]').attr('data-switch-anchor');
			}
			var ind, txt, $thisButton = self.$buttons.find('[data-switch-anchor="'+text+'"]');
			mw.log('switching module infobox, id '+self.index);
			// prefer text
			if ($thisButton.length) {
				txt = text;
				ind = $thisButton.attr('data-switch-index');
			} 
			if (ind === undefined) {
				return;
				/*ind = index;
				$thisButton = self.$buttons.find('[data-switch-index="'+ind+'"]');
				if ($thisButton.length) {
					txt = $thisButton.attr('data-switch-anchor');
				}*/
			}
			if (txt === undefined) {
				return;
			}
			if (self.isSelect) {
				self.$select.val(ind);
			} else {
				self.$buttons.find('span.button').removeClass('button-selected');
				$thisButton.addClass('button-selected');
			}
			
			self.$infobox.find('[data-attr-param][data-attr-param!=""]').each(function(i,e) {
				var $e = $(e),
					param = $e.attr('data-attr-param'),
					$switches = self.$resources.find('span[data-attr-param="'+param+'"]'),
					m,
					$val,
					$classTgt;
				
				// check if we found some switch data
				if (!$switches.length) return;

				// find value
				$val = $switches.find('span[data-attr-index="'+ind+'"]');
				if (!$val.length) {
					// didn't find it, use default value
					$val = $switches.find('span[data-attr-index="0"]');
					if (!$val.length) return;
				}
				// switch references support - $2 -> use the value for index 2
				m = SWITCH_REF_REGEX.exec($val.html());
				if (m) { // m is null if no matches
					$val = $switches.find('span[data-attr-index="'+m[1]+'"]'); // m is [ entire match, capture ]
					if (!$val.length) {
						$val = $switches.find('span[data-attr-index="0"]'); // fallback again
						if (!$val.length) return;
					}
				}
				$val = $val.clone(true,true);
				$e.empty().append($val.contents());

				// class switching
				// find the thing we're switching classes for
				if ($e.is('td, th')) {
					$classTgt = $e.parent('tr');
				} else {
					$classTgt = $e;
				}

				// reset classes
				if (self.originalClasses.hasOwnProperty(param)) {
					$classTgt.attr('class', self.originalClasses[param]);
				} else {
					$classTgt.removeAttr('class');
				}

				// change classes if needed
				if ($val.attr('data-addclass') !== undefined) {
					$classTgt.addClass($val.attr('data-addclass'));
				}
			});
			// trigger complete event for inter-script functions
			self.$buttons.trigger('switchinfoboxComplete', {txt:txt, num:ind});
			//re-initialise quantity boxes, if any
			if (window.rswiki && typeof(rswiki.initQtyBox) == 'function') {
				rswiki.initQtyBox(self.$infobox)
			}
			//console.log(this);
		};
		
		/* default version, return the anchor of the switchable if it exists */
		this.defaultVer = function () {
			var defver = self.$buttons.attr('data-default-version');
			if (defver !== undefined) {
				return { idx: defver, txt: self.$buttons.find('[data-switch-index="'+defver+'"]').attr('data-switch-anchor') };
			}
			return false;
		};
		
		this.isParentOf = function ($triggerer) {
			return self.$infobox.find($triggerer).length > 0;
		};
		
		this.currentlyShowing = function(){
			if (self.isSelect) {
				var sel = self.$select.val();
				return {index: sel, text: self.$select.find('option[value="'+sel+'"]').attr('data-switch-anchor')}
			} else {
				var buttn = self.$buttons.find('.button-selected');
				return {index: buttn.attr('data-switch-index'), text: buttn.attr('data-switch-anchor')}
			}
		}

		/* init */
		mw.log('setting up module infobox, id '+self.index);
		// setup original classes
		this.$infobox.find('[data-attr-param][data-attr-param!=""]').each(function(i,e){
			var $e = $(e), $classElem = $e, clas;
			if ($e.is('td, th')) {
				$classElem = $e.parent('tr');
			}
			clas = $classElem.attr('class');
			if (typeof clas === 'string') {
				self.originalClasses[$e.attr('data-attr-param')] = clas;
			}
		});

		// setup select/buttons and events
		if (self.isSelect) {
			self.$select = $('<select>')
				.attr({
					id: 'infobox-select-' + self.index,
					name: 'infobox-select-' + self.index,
				});
			self.$buttons.find('span.button').each(function(i, e){
				var $e = $(e);
				self.$select.append(
					$('<option>').attr({
						value: $e.attr('data-switch-index'),
						'data-switch-index': $e.attr('data-switch-index'),
						'data-switch-anchor': $e.attr('data-switch-anchor')
					}).text($e.text())
				);
			});
			self.$buttons.empty().append(self.$select);
			self.$select.change(self.beginSwitchEvent);
		} else {
			self.$buttons
				.attr({
					id: 'infobox-buttons-'+self.index
				})
				.find('span').each(function(i,e) {
					$(e).click(self.beginSwitchEvent);
				});
		}

		self.$buttons.css('display', 'flex');
		self.switchInfobox(1, '@init@');

		window.switchEventManager.addSwitchInfobox(this);
		if (this.$infobox.find('.infobox-bonuses-image.render-m').length === 1 && this.$infobox.find('.infobox-bonuses-image.render-f').length === 1) {
			this.genderswitch = new GenderRenderSwitcher(this.$infobox, this.index);
		}
	}
	
	/**
	 * Special support for gender render switching in infobox bonuses (& synced switch)
	 * Currently specifically only supports male & female
	 * potential TODO: generalise?
	 * 
	 * parameters
	 *	  $box	jQuery object representing the infobox itself (.infobox-switch)
	 */
	function GenderRenderSwitcher($box, index, version_index_offset) {
		var self = this;
		this.$box = $box;
		this.$box.data('SwitchInfobox', self);
		this.index = index;
		this.version_index_offset = version_index_offset;
		this.version_count = 2;
		this.$buttons = $('<div>').addClass('infobox-buttons').css('display', 'flex');
		this.button = {
			m: $('<span>').addClass('button').attr('data-gender-render', 'm').text('Male'),
			f: $('<span>').addClass('button').attr('data-gender-render', 'f').text('Female')
		};
		this.$td = $('<td>');
		this.$td_inner = $('<div class="gender-render-inner">');
		this.visible_gender = '';
		
		// from interface, we can just get the SyncedSwitches to switch
		this.beginSwitchEvent = function(event){
			var $e = $(event.currentTarget);
			var gen = $e.attr('data-gender-render');
			mw.log('beginSwitchEvent for genderswitcher '+self.index+' - switching to '+gen);
			window.switchEventManager.triggerGenderRenderSwitch(gen);
			if (CAN_LOCAL_STORAGE) {
				window.localStorage.setItem('gender-render', gen);
			}
		};
		// do the actual switching
		this.genderSwitch = function(gender) {
			mw.log('switching gender for genderswitcher for '+self.index+' to '+gender);
			self.$buttons.find('.button-selected').removeClass('button-selected');
			self.button[gender].addClass('button-selected');

			var x = self.$box.find('.infobox-bonuses-image.render-'+gender+'');
			self.$td_inner.empty().append(x.find('>*').clone());
			self.visible_gender = gender;
		};
		this.refreshImage = function(index,anchor) {
			// for when a main infobox switch happens
			// this is a post-switch function so the new images are in the original cells
			// we just gotta clone them into the visible cell again
			self.genderSwitch(self.visible_gender);
			mw.log('refreshed image for genderswitcher '+self.index);
		};
		this.currentlyShowing = function(){
			return {index: -1, text: self.visible_gender}
		}
		
		// other 'interface' methods just so stuff doesn't break, just in case
		this.switchInfobox = function(ind,anchor){/* do nothing */};
		this.defaultVer = function(){ return false; };

		mw.log('Initialising genderswitcher for '+self.index);
		var $c_m = this.$box.find('.infobox-bonuses-image.render-m'), $c_f=this.$box.find('.infobox-bonuses-image.render-f');
		this.$td.addClass('gender-render').attr({
			'style': $c_m.attr('style'),
			'rowspan': $c_m.attr('rowspan')
		}).append(this.$td_inner);
		$c_m.parent().append(this.$td);
		this.$buttons.append(this.button.m, this.button.f);
		this.$td.append(this.$buttons);
		this.$buttons.find('span.button').on('click', this.beginSwitchEvent);

		$c_m.addClass('gender-render-hidden').attr('data-gender-render', 'm');
		$c_f.addClass('gender-render-hidden').attr('data-gender-render', 'f');
		window.switchEventManager.addGenderRenderSwitch(self);
		window.switchEventManager.addPostSwitchEvent(this.refreshImage);
		this.genderSwitch(getGenderFromLS());
	}

	/**
	 * Legacy switch infoboxes, as generated by [[Template:Switch infobox]]
	 * 
	 * 
	 * parameters
	 *	  $box	jQuery object representing the infobox itself (.switch-infobox)
	 *	  index   index of this infobox, from $.each
	 */
	function LegacySwitchInfobox($box, index, version_index_offset) {
		var self = this;
		this.$infobox = $box;
		this.$infobox.data('SwitchInfobox', self);
		this.$parent = $box;
		this.index = index;
		this.version_index_offset = version_index_offset;
		this.$originalButtons = self.$parent.find('.switch-infobox-triggers');
		this.$items = self.$parent.find('.item');
		this.version_count = self.$originalButtons.find('span.trigger.button').length;

		/* click/change event - triggers switch event manager */
		this.beginSwitchEvent = function(e) {
			var $tgt = $(e.currentTarget);
			mw.log('beginSwitchEvent triggered in legacy infobox, id '+self.index);
			window.switchEventManager.trigger($tgt.attr('data-id'), $tgt.attr('data-anchor'), self);
		};

		/* click/change event - triggers switch event manager */
		this.switchInfobox = function(index, text){
			if (text === '@init@') {
				text = self.$buttons.find('[data-id="1"]').attr('data-anchor');
			}
			var ind, txt, $thisButton = self.$buttons.find('[data-anchor="'+text+'"]').first();
			mw.log('switching legacy infobox, id '+self.index);
			if ($thisButton.length) {
				txt = text;
				ind = $thisButton.attr('data-id');
			} else {
				return;
				/*ind = index;
				$thisButton = self.$buttons.find('[data-id="'+ind+'"]');
				if ($thisButton.length) {
					txt = $thisButton.attr('data-anchor');
				}*/
			}
			if (txt === undefined) {
				return;
			}
			self.$buttons.find('.trigger').removeClass('button-selected');
			self.$buttons.find('.trigger[data-id="'+ind+'"]').addClass('button-selected');
			
			self.$items.filter('.showing').removeClass('showing');
			self.$items.filter('[data-id="'+ind+'"]').addClass('showing');
		};
		
		/* default version - not supported by legacy, always false */
		this.defaultVer = function () { return false; };
		
		this.isParentOf = function ($triggerer) {
			return self.$parent.find($triggerer).length > 0;
		};
		this.currentlyShowing = function(){
			var buttn = self.$buttons.find('.button-selected');
			return {index: buttn.attr('data-id'), text: buttn.attr('data-anchor')}
		}

		/* init */
		mw.log('setting up legacy infobox, id '+self.index);
		// add anchor text
		self.$originalButtons.find('span.trigger.button').each(function(i,e){
			var $e = $(e);
			var anchorText = $e.text().split(' ').join('_');
			$e.attr('data-anchor', '#'+anchorText);
		});

		// append triggers to every item
		// if contents has a infobox, add to a caption of that
		// else just put at top
		self.$items.each(function(i,e){
			var $item = $(e);
			if ($item.find('table.infobox').length > 0) {
				if ($item.find('table.infobox caption').length < 1) {
					$item.find('table.infobox').prepend('<caption>');
				}
				$item.find('table.infobox caption').first().prepend(self.$originalButtons.clone());
			} else {
				$item.prepend(self.$originalButtons.clone());
			}
		});
		// remove buttons from current location
		self.$originalButtons.remove();

		// update selection
		this.$buttons = self.$parent.find('.switch-infobox-triggers');
		self.$buttons.find('.trigger').each(function (i,e) {
			$(e).click(self.beginSwitchEvent);
		});
		self.switchInfobox(1, '@init@');
		
		window.switchEventManager.addSwitchInfobox(this);
		self.$parent.removeClass('loading').find('span.loading-button').remove();
	}

	/**
	 * Synced switches, as generated by [[Template:Synced switch]]
	 * 
	 * 
	 * parameters
	 *	  $box	jQuery object representing the synced switch itself (.rsw-synced-switch)
	 *	  index   index of this infobox, from $.each
	 */
	function SyncedSwitch($box, index, version_index_offset) {
		var self = this;
		this.index = index;
		this.version_index_offset = version_index_offset; //not actually used
		this.version_count = 0; // we don't increment from this
		this.$syncedswitch = $box;
		this.$syncedswitch.data('SwitchInfobox', self);
		this.attachedLabels = false;
		this.is_synced_switch = true;

		/* filling in interface - synced switch has no buttons to press so cannot trigger an event by itself */
		this.beginSwitchEvent = function (){};

		this.switchInfobox = function(index, text){
			mw.log('switching synced switch, id '+self.index+", looking for "+index+' - '+text);
			if (text === '@init@') {
				text = self.$syncedswitch.find('[data-item="1"]').attr('data-item-text');
			}
			var $toShow = self.$syncedswitch.find('[data-item-text="'+text+'"]');
			if (!(self.attachedLabels && $toShow.length)) {
				//return;
				$toShow = self.$syncedswitch.find('[data-item="'+index+'"]');
			}
			if (!$toShow.length) {
				// show default instead
				self.$syncedswitch.find('.rsw-synced-switch-item').removeClass('showing');
				self.$syncedswitch.find('[data-item="0"]').addClass('showing');
			} else {
				self.$syncedswitch.find('.rsw-synced-switch-item').removeClass('showing');
				$toShow.addClass('showing');
			}
		};

		this.genderSwitch = function(gender){
			var $gens = self.$syncedswitch.find('.render-m, .render-f');
			var srch = '.render-'+gender;
			if ($gens.length) {
				$gens.each(function(i,e){
					var $e = $(e);
					if ($e.is(srch)) {
						$e.removeClass('gender-render-hidden').addClass('gender-render-showing');
					} else {
						$e.removeClass('gender-render-showing').addClass('gender-render-hidden');
					}
				});
			}
		};
		
		/* default version - not supported by synced switches, always false */
		this.defaultVer = function () { return false; };
		
		this.isParentOf = function ($triggerer) {
			return self.$syncedswitch.find($triggerer).length > 0;
		};
		this.currentlyShowing = function(){
			var buttn = self.$syncedswitch.find('.rsw-synced-switch-item.showing');
			return {index: buttn.attr('data-item'), text: buttn.attr('data-item-text')}
		}
		
		/* init */
		mw.log('setting up synced switch, id '+self.index);
		// attempt to apply some button text from a SwitchInfobox
		if ($('.infobox.infobox-switch').length && !$('.multi-infobox').length) {
			self.attachedLabels = true;
			var $linkedButtonTextInfobox = $('.infobox.infobox-switch').first();
			self.$syncedswitch.find('.rsw-synced-switch-item').each(function(i,e){
				var $e = $(e);
				if ($e.attr('data-item-text') === undefined) {
					$e.attr('data-item-text', $linkedButtonTextInfobox.find('[data-switch-index="'+i+'"]').attr('data-switch-anchor'));
				}
			});
		}
		self.switchInfobox(1, '@init@');
		window.switchEventManager.addSwitchInfobox(this);
		if (self.$syncedswitch.find('.render-m, .render-f').length) {
			window.switchEventManager.addGenderRenderSwitch(self);
			this.genderSwitch(getGenderFromLS());
		}
	}
	
	/** 
	 * An infobox that doesn't switch
	 * used to make sure MultiInfoboxes interact with SyncedSwitches correctly
	 * 
	 */
	function NonSwitchingInfobox($box, index, version_index_offset){
		var self = this;
		this.$infobox = $box;
		this.index = index;
		this.version_index_offset = version_index_offset;
		this.$infobox.data('SwitchInfobox', self);
		this.version_count = 1;
		
		this.beginSwitchEvent = function (){}; //do nothing
		this.switchInfobox = function(index, text){return}; //do nothing
		this.defaultVer = function () {return true;};
		this.isParentOf = function ($triggerer) {return false;};
		this.currentlyShowing = function(){
			return {text:null, index: 1};
		};
	}

	/**
	 * Event manager
	 * Observer pattern
	 * Globally available as window.switchEventManager
	 * 
	 * Methods
	 *	  addSwitchInfobox(l)
	 *		  adds switch infobox (of any type) to the list of switch infoboxes listening to trigger events
	 *		  l	   switch infobox
	 * 
	 * 		addPreSwitchEvent(f)
	 * 			adds the function to a list of functions that runs when the switch event is triggered but before any other action is taken
	 * 			the function is passed the index and anchor (in that order) that was passed to the trigger function
	 * 			returning the boolean true from the function will cancel the switch event
	 * 			trying to add a non-function is a noop
	 * 			e		function to run
	 * 
	 * 		addPostSwitchEvent(f)
	 * 			adds the function to a list of functions that runs when the switch event is completed, after all of the switching is completed (including the hash change)
	 * 			the function is passed the index and anchor (in that order) that was passed to the trigger function
	 * 			the return value is ignored
	 * 			trying to add a non-function is a noop
	 * 			e		function to run
	 * 
	 *	  trigger(i, a)
	 *		  triggers the switch event on all listeners
	 *		  will prefer switching to the anchor if available
	 *		  i	   index to switch to
	 *		  a	   anchor to switch to
	 * 
	 * 		makeSwitchInfobox($box)
	 * 			creates the correct object for the passed switch infobox, based on the classes of the infobox
	 * 			is a noop if it does not match any of the selectors
	 * 			infobox is given an index based on the internal counter for the switch
	 * 			$box		jQuery object for the switch infobox (the jQuery object passed to the above functions, see above for selectors checked)
	 * 
	 * 		addIndex(i)
	 * 			updates the internal counter by adding i to it
	 * 			if i is not a number or is negative, is a noop
	 * 			used for manually setting up infoboxes (init) or creating a new type to plugin
	 * 			i	number to add
	 */

	function SwitchEventManager() {
		var self = this, switchInfoboxes = [], syncedSwitches=[], genderRenderSwitchers = [], preSwitchEvents = [], postSwitchEvents = [], index = 0, version_offset = 0;
		window.switchEventManager = this;
		
		// actual switch infoboxes to change
		this.addSwitchInfobox = function(l) {
			switchInfoboxes.push(l);
			if (l.is_synced_switch) {
				syncedSwitches.push(l);
			}
		};

		this.addGenderRenderSwitch = function(gs) {
			gs.version_index_offset = version_offset;
			genderRenderSwitchers.push(gs);
			version_offset += gs.version_count;
		};
		
		// things to do when switch button is clicked but before any switching
		this.addPreSwitchEvent = function(e) {
			if (typeof(e) === 'function') {
				preSwitchEvents.push(e);
			}
		};
		this.addPostSwitchEvent = function(e) {
			if (typeof(e) === 'function') {
				postSwitchEvents.push(e);
			}
		};

		this.trigger = function(index, anchor, triggerer) {
			mw.log('Triggering switch event for index '+index+'; text '+anchor);
			// using a real for loop so we can use return to exit the trigger function
			for (var i=0; i < preSwitchEvents.length; i++){
				var ret = preSwitchEvents[i](index,anchor);
				if (typeof(ret) === 'boolean') {
					if (ret) {
						mw.log('switching was cancelled');
						return;
					}
				}
			}

			// close all tooltips on the page
			$('.js-tooltip-wrapper').trigger('js-tooltip-close');

			// trigger switching on listeners
			switchInfoboxes.forEach(function (e) {
				if (triggerer === null || !e.isParentOf(triggerer.$infobox)) {
					if (e.is_synced_switch && triggerer !== null) {
						e.switchInfobox(parseInt(index)+triggerer.version_index_offset, anchor);
					} else {
						e.switchInfobox(index, anchor);
					}
				}
			});

			// update hash
			if (typeof anchor === 'string') {
				var _anchor = anchor;
				if (_anchor === '@init@') {
					_anchor = '';
				}
				
				if (window.history && window.history.replaceState) {
					if (window.location.hash !== '') {
						window.history.replaceState({}, '', window.location.href.replace(window.location.hash, _anchor));
					} else {
						window.history.replaceState({}, '', window.location.href + _anchor);
					}
				} else {
					// replaceState not supported, I guess we just change the hash normally?
					window.location.hash = _anchor;
				}
			}

			postSwitchEvents.forEach(function(e){
				e(index, anchor);
			});
		};

		this.triggerGenderRenderSwitch = function(gender){
			mw.log(genderRenderSwitchers);
			for (var i = 0; i<genderRenderSwitchers.length; i++) {
				genderRenderSwitchers[i].genderSwitch(gender);
			}
		};
		
		this.triggerMultiInfoboxTabChange = function($multiInfobox) {
			mw.log('switching syncedswitches from tabber click', $multiInfobox)
			setTimeout(function(){
				var $tabcontents = $multiInfobox.find('div.tabber > div.tabbertab[style=""]');
				var $infobox = $tabcontents.find('.infobox').first();
				var swinfo = $infobox.data('SwitchInfobox');
				mw.log('switchingdata', $tabcontents, $infobox, swinfo);
				if (swinfo !== null && swinfo !== undefined) {
					var cs = swinfo.currentlyShowing();
					var ind = parseInt(cs.index) + swinfo.version_index_offset;
					mw.log('inside if', cs, ind)
					syncedSwitches.forEach(function (e) {
						mw.log('inside foreach', e);
						e.switchInfobox(ind, '');
					});
				} else {mw.log('swinfo is undefnull');}
			}, 20);
		};
		
		/* attempts to detect what type of switch infobox this is and applies the relevant type */
		// mostly for external access
		this.makeSwitchInfobox = function($e) {
			if ($e.is('.infobox-switch')) {
				return new SwitchInfobox($e, index++, version_offset);
			}
			if ($e.hasClass('switch-infobox')) {
				return new LegacySwitchInfobox($e, index++, version_offset);
			}
			if ($e.hasClass('rsw-synced-switch')) {
				return new SyncedSwitch($e, index++, version_offset);
			}
			if ($e.hasClass('infobox')) {
				return new NonSwitchingInfobox($e, index++, version_offset);
			}
			console.log('Invalid element sent to SwitchEventManager.makeSwitchInfobox:', $e)
		};
		this.addIndex = function(i) {
			if (typeof(i) === 'number') {
				 i += Math.max(Math.floor(i), 0);
			}
		};
		this.applyDefaultVersion = function() {
			if (window.location.hash !== '') {
				self.trigger(1, window.location.hash, null);
				return;
			} else {
			// real for loop so we can return out of the function
				for (var i = 0; i<switchInfoboxes.length; i++) {
					var defver = switchInfoboxes[i].defaultVer();
					if (typeof(defver) === 'object') {
						self.trigger(defver.idx, defver.txt, null);
						return;
					}
				}
			}
			self.trigger(1, '@init@', null);
		};
		
		// init
		this.init = function(){
			$('.infobox, .switch-infobox, .rsw-synced-switch').each(function(i,e){
				var obj = self.makeSwitchInfobox($(e));
				version_offset += obj.version_count;
			});
			
			
			// for {{Multi Infobox}}
			// there isn't a hook for tabber being ready, so we just gotta check until it is
			function initMultiInfobox(){
				if ($('#mw-content-text .multi-infobox .tabber.tabberlive').length) { // class tabberlive is added when it is ready
					$('#mw-content-text .multi-infobox').each(function(i,e){
						$(e).find('.tabber > ul.tabbernav > li').click(function(ev){
							self.triggerMultiInfoboxTabChange($(ev.currentTarget).parents('.multi-infobox'));
						});
					});
					$('#mw-content-text .multi-infobox .tabber.tabberlive ul.tabbernav li.tabberactive').click(); //trigger event once now
				} else {
					window.setTimeout(initMultiInfobox, 20);
				}
			}
			if ($('#mw-content-text .multi-infobox').length) {
				initMultiInfobox();
			}
			
			self.applyDefaultVersion();
		}
		this.init();
	}

	mw.hook('wikipage.content').add(function init( $content ) {
		if (!($content.find('.switch-infobox, .infobox-buttons, .multi-infobox').length)) {
			return;
		}
		// mirror rsw-util
		try {
			localStorage.setItem('test', 'test');
			localStorage.removeItem('test');
			CAN_LOCAL_STORAGE = true;
		} catch (e) {
			CAN_LOCAL_STORAGE = false;
		}
		window.switchEventManager = new SwitchEventManager();

		// reinitialize any kartographer map frames added due to a switch
		if ($content.find('.infobox-switch .mw-kartographer-map').length
		|| $content.find('.infobox-switch-resources .mw-kartographer-map').length
		|| $content.find('.switch-infobox .mw-kartographer-map').length
		|| $content.find('.rsw-synced-switch .mw-kartographer-map').length) {
			window.switchEventManager.addPostSwitchEvent(function() {
				mw.hook('wikipage.content').fire($content.find('a.mw-kartographer-map').parent());
			});
		}
	});
})
/*
MediaWiki:Gadget-exchangePages.js
*/
if (mw.config.get('wgCanonicalNamespace') == 'Exchange') {
	mw.loader.load( 'ext.gadget.exchangePages-core' );
}
/*
MediaWiki:Gadget-GECharts.js
*/
$(function () {
	if ($( '.GEdatachart' ).length) {
		mw.loader.load( 'ext.gadget.GECharts-core' );
	}
})
/*
MediaWiki:Gadget-highlightTable.js
*/
$(function () {
	if ($("table.lighttable").length) {
		mw.loader.load( 'ext.gadget.highlightTable-core' );
	}
})
/*
MediaWiki:Gadget-titleparenthesis.js
*/
$(function () {
    var conf = mw.config.get([
       'wgNamespaceNumber',
        'wgTitle'
    ]);

	if (conf.wgNamespaceNumber !== 0 || conf.wgTitle.lastIndexOf('(') < 0 ||
		$('.no-parenthesis-style').length) {
		return;
	} 
	
	// use the title in the DOM so this respects DISPLAYTITLE
	var title = mw.html.escape($('h1#firstHeading').text()),
		start = title.lastIndexOf('('),
		end = title.substring(start, title.length).lastIndexOf(')');

	// add offset here
	end += start + 1;
	
	$('h1#firstHeading')
		.empty()
		.append(
			title.substring(0, start),
			$('<span>')
				.addClass('title-parenthesis')
				.html(title.substring(start, end)),
			title.substring(end, title.length)
		);
});
/*
MediaWiki:Gadget-tooltips.js
*/
/* JavaScript tooltips 
	usage: 
	
		recommended usage: see [[Template:Tooltip]] and [[Template:Tooltip text]], or [[Module:Tooltip]] for module interface
	
	
	raw usage:
	
	Place this where you want the button to appear: 
	<span class="hidden js-tooltip-click" style="display:none;" data-tooltip-name="test">clickable</span>
	
	place this elsewhere to define the content of the tooltip:
<div class="hidden js-tooltip-wrapper" style="display:none;" data-tooltip-for="test" data-tooltip-arrow="yes" data-tooltip-arrow-size="10" data-tooltip-style="custom style"><div class="js-tooltip-text">Content</div></div>

	
	span.js-tooltip-click - required
		attribute: data-tooltip-name - links to the corresponding divl; can have many with the same name
		content: the clickable thing, defaults to ?
	
	div.js-tooltip-wrapper - required
		attributes:
			data-tooltip-for - required; links this to spans with the data-tooltip-name equal to this
			data-tooltip-arrow - optional; yes for arrow, no/default for no arrow
			data-tooltip-arrow-size - optional; yes for arrow, no/default for no arrow
			data-tooltip-style - optional; the width of the arrow (height=2width) in px; also defines the gap between the tooltip and the span. defaults to 10
			
		content: div.js-tooltip-text

	div.js-tooltip-text - required
		contains: text/html to display inside tooltip

*/
$(function () {
	if (!($('.js-tooltip-wrapper').length && $('.js-tooltip-click').length)) {
		return;
	} 
	
	// every tooltip wrapper on the page considered separately
	
	// remove excess tooltip wrappers for the same name - can cause issues
	(function(){
		var forarr = {}, forarrv, key, first;
		$('.js-tooltip-wrapper').each(function(){
			forarr[$(this).attr('data-tooltip-for')] = true;
		});
		for (key in forarr) {
			first = $('.js-tooltip-wrapper[data-tooltip-for="'+key+'"]').first();
			$('.js-tooltip-wrapper[data-tooltip-for="'+key+'"]').not(first).remove();
		}
	})();
	
	$('.js-tooltip-wrapper').each(function () {
		var $span,
		$text,
		$arrow,
		$wrapper,
		$close,
		resizeEvent,
		hasArrow = true,
		arrpos,
		style,
		styles,
		parsed_styles,
		name,
		size,
		limitwidth = false,
		$currspan = $(null);
		
		// setup vars
		$wrapper = $(this);
		name = $wrapper.attr('data-tooltip-for');
		
		if ($wrapper.attr('data-tooltip-arrow')) {
			hasArrow = $wrapper.attr('data-tooltip-arrow').toLowerCase() == 'yes';
		}
		if ($wrapper.attr('data-tooltip-limit-width')) {
			limitwidth = $wrapper.attr('data-tooltip-limit-width').toLowerCase() == 'yes';
		}
		style = $wrapper.attr('data-tooltip-style');
		size = parseInt($wrapper.attr('data-tooltip-arrow-size'), 10);
		if (typeof size !== 'number' || isNaN(size)) {
			size = 10;
		}
		
		$text = $wrapper.find('.js-tooltip-text');
		
		// setup wrapper css for movement
		$wrapper.removeClass('hidden')
			.on('js-tooltip-close', function () {
				$wrapper.hide();
				$currspan.removeAttr('data-is-currspan');
				$currspan = $(null);
			});
		
		// setup span css
		$span = $('span.js-tooltip-click[data-tooltip-name="' + name + '"]');
		$span.removeClass('hidden')
			.attr('title', 'Click for explanation, click again to close');
		if ($span.html() === '') {
			$span.text('?');
		}
		
		// setup arrow
		$arrow = $('<div>');
		$arrow.addClass('js-tooltip-arrow')
			.css({
				top: ($wrapper.outerHeight() * 0.3) + 'px',
				left: ('-' + (size+2) + 'px'), // width of arrow + width of text div border
				'margin-top': ('-' + (size/2) + 'px'),
				'border-width': size + 'px', //actual width of the arrow
			});
		arrpos = '-' + (size+2) + 'px';
		
		// easiest way to deal with arrow is to just not add it if it isn't specified
		if (hasArrow) {
			$wrapper.prepend($arrow);
		}
		
		// setup close button
		$close = $('<button>');
		$close.html('<img src="/images/Close-x-white.svg?1ccac" />')
			.addClass('close js-tooltip-close')
			.click(function(){
				$wrapper.trigger('js-tooltip-close');
			});
		$text.prepend($close);
		
		// setup resize event for repositioning tooltips
		resizeEvent = function () {
			if ($currspan.length === 0) {
				return;
			}
			var offset, position, width, $body, $mwtext;
			offset = $currspan.offset();
			position = $currspan.position();
			width = $currspan.outerWidth();
			$body = $('body');
			$mwtext = $('#mw-content-text');
			
			
			$wrapper.css({
				top: (offset.top - $wrapper.outerHeight()*0.3) + 'px',
			});
			$arrow.css({
				top: ($wrapper.outerHeight() * 0.3) + 'px',
			});
			
			if ((!limitwidth && offset.left > 0.5 * $body.width())
				|| (limitwidth && position.left > 0.5 * $mwtext.width())) {
				$wrapper.css({
					right: (($body.width() - offset.left) - 5 + size) + 'px',
					left: '', // remove other pos to prevent overspecification
				});
				$arrow.removeClass('js-tooltip-arrow-pointleft').addClass('js-tooltip-arrow-pointright').css({
					left: '', // remove other pos to prevent overspecification
					right: arrpos,
					'border-left-width': size + 'px',
					'border-right-width': 0,
				});
				if (limitwidth) {
					$wrapper.css({
						'max-width': '500px',
					});
				}
			} else {
				$wrapper.css({
					left: (offset.left + width - 5 + size) + 'px',
					right: '', // remove other pos to prevent overspecification
				});
				$arrow.removeClass('js-tooltip-arrow-pointright').addClass('js-tooltip-arrow-pointleft').css({
					right: '', // remove other pos to prevent overspecification
					left: arrpos,
					'border-right-width': size + 'px',
					'border-left-width': 0,
				});
				if (limitwidth) {
					$wrapper.css({
						'max-width': '500px',
					});
				}
			}
		};
		
		// attach resize event
		$(window).resize(resizeEvent);
		
		// attach click event to span
		$span.click(function (event) {
			//no bubbles
			event.preventDefault();
			event.stopPropagation();
			$this = $(event.currentTarget);
			if ($this.attr('data-is-currspan') == 'true') {
			// if the current span is clicked while the popup is open, close the popup
				$this.removeAttr('data-is-currspan');
				$currspan = $(null);
				$wrapper.trigger('js-tooltip-close');
			} else {
				// else move and show the currently open popup
				$currspan = $this;
				$('.js-tooltip-wrapper').not($wrapper).trigger('js-tooltip-close');
				$this.attr('data-is-currspan', true);
				$wrapper.show();
				resizeEvent();
			}
		});
		
		// add custom style
		if (typeof style === 'string' && style !== '') {
			styles = style.split(';');
			styles_parsed = {};
			styles.forEach(function(v) {
				if (typeof v === 'string') {
					var arr = v.split(':');
					if (typeof arr[1] === 'string' && arr[1].trim() !== '') {
						styles_parsed[arr[0].trim()] = arr[1].trim();
					}
				}
			});
			$wrapper.css(styles_parsed);
		}

		// finish up
		$wrapper.hide();
		$span.show();
		$wrapper.appendTo($('body'));
	});
	
	// close tooltip if clicked outside of
	$(document).click(function (event) {
		if ($('.js-tooltip-wrapper:visible').length && !$(event.target).closest('.js-tooltip-wrapper, .js-tooltip-click').length) {
			$('.js-tooltip-wrapper').trigger('js-tooltip-close');
		}
	});
})
/*
MediaWiki:Gadget-Username.js
*/
/** 
 * Script for {{USERNAME}}
 */
if (mw.config.get("wgUserName")) $(function(){ $('.insertusername').text(mw.config.get("wgUserName")) });
/*
MediaWiki:Gadget-countdown.js
*/
/**
 * Countdown
 *
 * @version 2.1
 *
 * @author Pecoes <https://c.wikia.com/wiki/User:Pecoes>
 * @author Asaba <https://dev.wikia.com/wiki/User:Asaba>
 *
 * Version 1 authors:
 * - Splarka <https://c.wikia.com/wiki/User:Splarka>
 * - Eladkse <https://c.wikia.com/wiki/User:Eladkse>
 *
 * documentation and examples at:
 * <https://dev.wikia.com/wiki/Countdown>
 */

/*jshint jquery:true, browser:true, devel:true, camelcase:true, curly:false, undef:true, bitwise:true, eqeqeq:true, forin:true, immed:true, latedef:true, newcap:true, noarg:true, unused:true, regexp:true, strict:true, trailing:false */
/*global mediaWiki:true*/

;(function (module, mw, $, undefined) {

	'use strict';

	var translations = $.extend(true, {
		// English (English)
		en: {
			and: 'and',
			second: 'second',
			seconds: 'seconds',
			minute: 'minute',
			minutes: 'minutes',
			hour: 'hour',
			hours: 'hours',
			day: 'day',
			days: 'days'
		},
	}, module.translations || {}),
	i18n = translations[
		mw.config.get('wgContentLanguage')
	] || translations.en;

	var countdowns = [];

	var NO_LEADING_ZEROS = 1,
	SHORT_FORMAT = 2,
	NO_ZEROS = 4;

	function output (i, diff) {
		/*jshint bitwise:false*/
		var delta, result, parts = [];
		delta = diff % 60;
		result = ' ' + i18n[delta === 1 ? 'second' : 'seconds'];
		if (countdowns[i].opts & SHORT_FORMAT) result = result.charAt(1);
		parts.unshift(delta + result);
		diff = Math.floor(diff / 60);
		delta = diff % 60;
		result = ' ' + i18n[delta === 1 ? 'minute' : 'minutes'];
		if (countdowns[i].opts & SHORT_FORMAT) result = result.charAt(1);
		parts.unshift(delta + result);
		diff = Math.floor(diff / 60);
		delta = diff % 24;
		result = ' ' + i18n[delta === 1 ? 'hour'   : 'hours'  ];
		if (countdowns[i].opts & SHORT_FORMAT) result = result.charAt(1);
		parts.unshift(delta + result);
		diff = Math.floor(diff / 24);
		result = ' ' + i18n[diff  === 1 ? 'day'    : 'days'   ];
		if (countdowns[i].opts & SHORT_FORMAT) result = result.charAt(1);
		parts.unshift(diff  + result);
		result = parts.pop();
		if (countdowns[i].opts & NO_LEADING_ZEROS) {
			while (parts.length && parts[0][0] === '0') {
				parts.shift();
			}
		}
		if (countdowns[i].opts & NO_ZEROS) {
			parts = parts.filter(function(part) {
				return part[0] !== '0';
			});
		}
		if (parts.length) {
			if (countdowns[i].opts & SHORT_FORMAT) {
				result = parts.join(' ') + ' ' + result;
			} else {
				result = parts.join(', ') + ' ' + i18n.and + ' ' + result;
			}
		}
		countdowns[i].node.text(result);
	}

	function end(i) {
		var c = countdowns[i].node.parent();
		switch (c.attr('data-end')) {
		case 'remove':
			c.remove();
			return true;
		case 'stop':
			output(i, 0);
			return true;
		case 'toggle':
			var toggle = c.attr('data-toggle');
			if (toggle && toggle == 'next') {
				c.next().css('display', 'inline');
				c.css('display', 'none');
				return true;
			}
			if (toggle && $(toggle).length) {
				$(toggle).css('display', 'inline');
				c.css('display', 'none');
				return true;
			}
			break;
		case 'callback':
			var callback = c.attr('data-callback');
			if (callback && $.isFunction(module[callback])) {
				output(i, 0);
				module[callback].call(c);
				return true;
			}
			break;
		}
		countdowns[i].countup = true;
		output(i, 0);
		return false;
	}

	function update () {
		var now = Date.now();
		var countdownsToRemove = [];
		$.each(countdowns.slice(0), function (i, countdown) {
			var diff = Math.floor((countdown.date - now) / 1000);
			if (diff <= 0 && !countdown.countup) {
				if (end(i)) countdownsToRemove.push(i);
			} else {
				output(i, Math.abs(diff));
			}
		});
		var x;
		while((x = countdownsToRemove.pop()) !== undefined) {
			countdowns.splice(x, 1);
		}
		if (countdowns.length) {
			window.setTimeout(function () {
				update();
			}, 1000);
		}
	}

	function getOptions (node) {
		/*jshint bitwise:false*/
		var text = node.parent().attr('data-options'),
			opts = 0;
		if (text) {
			if (/no-leading-zeros/.test(text)) {
				opts |= NO_LEADING_ZEROS;
			}
			if (/short-format/.test(text)) {
				opts |= SHORT_FORMAT;
			}
			if (/no-zeros/.test(text)) {
				opts |= NO_ZEROS;
			}
		}
		return opts;
	}

	function init() {
		var countdown = $('.countdown:not(.handled)');
		if (!countdown.length) return;
		$('.nocountdown').css('display', 'none');
		countdown
		.css('display', 'inline')
		.find('.countdowndate')
		.each(function () {
			var $this = $(this),
				date = (new Date($this.text())).valueOf();
			if (isNaN(date)) {
				$this.text('BAD DATE');
				return;
			}
			countdowns.push({
				node: $this,
				opts: getOptions($this),
				date: date,
			});
		});
		countdown.addClass('handled');
		if (countdowns.length) {
			update();
		}
	}

	mw.hook('wikipage.content').add(init);

}(window.countdownTimer = window.countdownTimer || {}, mediaWiki, jQuery));
/*
MediaWiki:Gadget-checkboxList.js
*/
$(function () {
	if ($("ul.checklist, div.checklist > ul").length) {
		mw.loader.load( 'ext.gadget.checkboxList-core' );
	}
})
/*
MediaWiki:Gadget-Charts.js
*/
$(function () {
	if ($( '.rsw-chartjs-config' ).length) {
		mw.loader.load( 'ext.gadget.Charts-core' );
	}
})
/*
MediaWiki:Gadget-navbox-tracking.js
*/
;(function($, mw){
	if ($('.navbox').length <= 0) return;
	var LOADING = false;
	function trackNavboxClick(event) {
		var $e = $(event.currentTarget),
		    pagename = mw.config.get('wgPageName'),
		    href,
		    navbox,
		    link_type = ['link'],
		    click_type,
		    data;
		href = $e.attr('href');
		navbox = $e.parents('.navbox[data-navbox-name]');
		if (navbox.length<1) {
			// missing name, template not propagated - skip
			return;
		}
		navbox = navbox.attr('data-navbox-name');
		if ($e.find('img').length>0) {
			link_type.push('image');
			if ($e.parent().is('span.inventory-image')) {
				link_type.push('inventory');
			}
			if ($e.parent().is('span.chathead-link')) {
				link_type.push('chathead');
			}
		}
		if ($e.parents('th.navbox-title').length>0) {
			link_type.push('navboxtitle');
		}
		if ($e.parent().is('td.navbox-group-title')) {
			link_type.push('navboxgrouptitle');
			link_type.push('navboxgroup-'+$e.parents('tr.navbox-group').length)
		}
		if ($e.parents('div.navbar').length>0) {
			link_type.push('navbar');
		}
		if ($e.parents('sup').length>0) {
			link_type.push('sup');
		}
		if ($e.parents('sub').length>0) {
			link_type.push('sub');
		}
		switch (event.which) {
			case 1:
				click_type = 'left';
				if (!(event.altKey || event.ctrlKey || event.altKey || event.metaKey)) {
					$e.attr({'x-href': href, 'x-leftclicked':'1'}).removeAttr('href');
				}
				break;
			case 2:
				click_type = 'middle';
				break;
			case 3:
				click_type = 'right';
				break;
			default:
				click_type = 'other: '+event.which;
		}
		if (event.shiftKey) {
			click_type += '-shift';
		}
		if (event.ctrlKey) {
			click_type += '-control';
		}
		if (event.altKey) {
			click_type += '-alt';
		}
		if (event.metaKey) {
			click_type += '-meta';
		}
		data = {
				page: pagename,
				link: href,
				navbox: navbox,
				'type': link_type.join(' '),
				click: click_type,
				wiki: mw.config.get('wgDBname')
		};
		console.log('Sending navbox click data:', data);
		var req = $.ajax('https://chisel.weirdgloop.org/gazproj/track/navbox', {
			method: 'POST',
			data: data
		});
		req.done(function(d, s, xhr){
			console.log('Data (success): ', d, s, xhr);
			if (click_type === 'left' && $e.attr('x-leftclicked') === '1') {
				$e.attr({'href':$e.attr('x-href'), 'x-leftclicked':'0'});
				$e.get(0).click();
			}
		});
		req.fail(function(d, s, xhr){
			console.log('Data (fail): ', d, s, xhr);
			if (click_type === 'left' && $e.attr('x-leftclicked') === '1') {
				$e.attr({'href':$e.attr('x-href'), 'x-leftclicked':'0'});
				$e.get(0).click();
			}
    	});
	}
	function init(){
		$('.navbox a[href]').on('mousedown', trackNavboxClick);
	}
	$(init);
})(jQuery, mw);
/*
MediaWiki:Gadget-wikisync.js
*/
$(function () {
	if ($('.qc-active').length) {
		mw.loader.load( 'ext.gadget.wikisync-core' );
	}
})
/*
MediaWiki:Gadget-smwlistsfull.js
*/
if ($('#smw-list-full').length) {
	mw.loader.load('ext.gadget.smwlistsfull-core');
}
/*
MediaWiki:Gadget-jsonDoc.js
*/
if (mw.config.get('wgPageContentModel') === 'json' && !$('.json-contentmodel-documentation').length && mw.config.get('wgArticleId')!==0) {
  var raw_url = mw.config.get('wgServer')+mw.util.getUrl(null, {action:'raw', ctype:'application/json'});
  $('#mw-content-text').prepend($(
  	'<div class="documentation json-contentmodel-documentation">'+
  		'<div class="documentation-header">'+
  			'<span class="documentation-title">JSON module documentation</span>'+
  		'</div>'+
  		'<div class="documentation-subheader">'+
  			'<span class="documentation-documentation">'+
  				'This documentation is generated by <a href="/w/MediaWiki:Gadget-jsonDoc.js" title="MediaWiki:Gadget-jsonDoc.js">MediaWiki:Gadget-jsonDoc.js</a>.'+
  			'</span>'+
  		'</div>'+
  		'<div class="documentation-content">'+
  			'<p>This page is set to the JSON content model. Below is a parsed version of the data, as a table. To see the raw data, you can <a href="'+mw.util.getUrl(null, {action:'edit'})+'">edit the page</a>.</p>'+
  			'<p>To load this data in an on-wiki scribunto module, use <code>mw.loadJsonData("'+mw.config.get('wgPageName')+'")</code> (<a href="https://www.mediawiki.org/wiki/Extension:Scribunto/Lua_reference_manual#mw.loadJsonData">documentation</a>).</p>'+
  			'<p>To load this data externally, it is recommended to send a GET request to <a href="'+raw_url+'">'+raw_url+'</a></p>'+
  		'</div>'+
  	'</div>'
  ));
}
/*
MediaWiki:Gadget-articlefeedback.js
*/
// <nowiki>
// Article selector should be reflected in [[MediaWiki:Gadget-articlefeedback-styles.css]] as well
if ([0, 116, 120].includes(mw.config.get('wgNamespaceNumber')) && mw.config.get('wgAction') === 'view' && mw.config.get('wgArticleId') > 0) {
	mw.loader.load( 'ext.gadget.articlefeedback-core' );
}

if (mw.config.get('wgUserGroups').includes('autoconfirmed') && $('.gloop-feedback-wrapper').length > 0) {
	mw.loader.load( 'ext.gadget.articlefeedback-tools' );
}
if ($('.gloop-feedback-wrapper').length > 0) {
	mw.loader.using(['ext.gadget.tooltip'], function(){
		$('.gloop-feedback-category').each(function(i,e){
			let $e = $(e);
			new window.Tooltip($e, {placement:'top', title:$e.attr('title')});
			$e.removeAttr('title');
		})
	})
}

// </nowiki>
/*
MediaWiki:Gadget-calc.js
*/
$(function () {
	if ($('.jcConfig').length) {
		mw.loader.load( 'ext.gadget.calc-core' );
	}
})
/*
MediaWiki:Gadget-calculatorNS.js
*/
/**
 * Adds a link to the main calculators directory to every calculator namespace page
 *		in the same place as other subpage links (creates the element if required)
 *
 * @author Gaz Lloyd
 */
$(function () {
	if (mw.config.get('wgNamespaceNumber') !== 116) {
		return;
	}
	
	function init() {
		// duplication prevention
		if ($('#mw-content-subtitle .subpages .calculatorDirectoryLink').length) return;
		var link = $('<a>')
					.attr({
						href: mw.util.getUrl('Calculators'),
						title: 'Calculator directory',
					})
					.addClass('calculatorDirectoryLink')
					.text('All calculators'),
			linkwrapper = $('<div>')
					.addClass('subpages')
					.append('< ', link);
		
		if ($('#mw-content-subtitle .subpages').length) {
			$('#mw-content-subtitle .subpages a').first().before(link, ' | ');
		} else {
			mw.util.addSubtitle(linkwrapper[0]);
		}
	}
	
	init();
});
/*
MediaWiki:Gadget-dropDisplay.js
*/
$(function () {
	if ($('table.item-drops.filterable').length) {
		mw.loader.load( 'ext.gadget.dropDisplay-core' );
	}
})
/*
MediaWiki:Gadget-mmgkc.js
*/
$(function () {
	if ($('.mmg-table.mmg-isperkill').length) {
	    mw.loader.load( 'ext.gadget.mmgkc-core' );
	}
})
/*
MediaWiki:Gadget-fightcaverotations.js
*/
$(function () {
	if ( $('#rotation-table').length ) {
		mw.loader.load( 'ext.gadget.fightcaverotations-core' );
	}
})
/*
MediaWiki:Gadget-livePricesMMG.js
*/
$(function () {
	if ($('.mmg-list-table').length) {
		mw.loader.load( 'ext.gadget.livePricesMMG-core' );
	}
})
/*
MediaWiki:Gadget-skinTogglesMobile.js
*/
/**
 * Toggles for skin cookies on mobile
 * 
 * @author JaydenKieran
 * 
 */

const DARK_COOKIE = 'darkmode';
var currentDark = $.cookie('theme') === 'dark' || ($.cookie('theme') == null && $.cookie(DARK_COOKIE) === 'true'),
	darkPortletLink;

var self = {
	init: function () {
		darkPortletLink = mw.util.addPortletLink(
			'p-personal',
			'#',
			(currentDark ? 'Light' : 'Dark') + ' mode',
			'wgl-darkmode-toggle',
			'Toggle ' + (currentDark ? 'light' : 'dark') + ' mode',
			null,
			$('a.menu__item--logout').closest('li')
		);
		
		$('meta[name="theme-color"]').attr('content', currentDark ? '#071022' : '#c0a886');

		$.cookie('theme', currentDark ? 'dark' : 'light', {expires: 365, path: '/'});
		
		$(darkPortletLink).click(function (e) {
			e.preventDefault();
			currentDark = !currentDark;
			$('#wgl-darkmode-toggle .toggle-list-item__label').text((currentDark ? 'Light' : 'Dark') + ' mode');
			$.cookie('theme', currentDark ? 'dark' : 'light', {expires: 365, path: '/'});
			$.cookie(DARK_COOKIE, currentDark, {expires: 365, path: '/'});
			$('meta[name="theme-color"]').attr('content', currentDark ? '#071022' : '#c0a886');
			
			if (currentDark) {
				mw.loader.using(['wgl.theme.dark']).then(function() {
					$('body').addClass('wgl-theme-dark').removeClass('wgl-theme-light')
				});
			} else {
				$('body').addClass('wgl-theme-light').removeClass('wgl-theme-dark')
			}
			mw.notify( 'Switched to ' + (currentDark ? 'dark' : 'light') + ' mode!', { tag: 'wg-darkmode-notification' } );
		});
	},
}

$(self.init);
/*
MediaWiki:Gadget-relativetime.js
*/
// Don't load CommentsInLocalTime for namespaces it is disabled for.
if ( [-1, 0, 8].indexOf(mw.config.get("wgNamespaceNumber")) === -1 ) {
	// [[w:en:User:Mxn/CommentsInLocalTime]]
	// en.wikipedia.org/wiki/User:Mxn/CommentsInLocalTime.js
	
	/**
	 * Comments in local time
	 * [[User:Mxn/CommentsInLocalTime]]
	 * 
	 * Adjust timestamps in comment signatures to use easy-to-understand, relative
	 * local time instead of absolute UTC time.
	 * 
	 * Inspired by [[Wikipedia:Comments in Local Time]].
	 * 
	 * @author [[User:Mxn]]
	 */
	
	/**
	 * Default settings for this gadget.
	 */
	window.LocalComments = $.extend({
		// USER OPTIONS ////////////////////////////////////////////////////////////
		
		/**
		 * When false, this gadget does nothing.
		 */
		enabled: true,
		
		/**
		 * Formats to display inline for each timestamp, keyed by a few common
		 * cases.
		 * 
		 * If a property of this object is set to a string, the timestamp is
		 * formatted according to the documentation at
		 * <http://momentjs.com/docs/#/displaying/format/>.
		 * 
		 * If a property of this object is set to a function, it is called to
		 * retrieve the formatted timestamp string. See
		 * <http://momentjs.com/docs/#/displaying/> for the various things you can
		 * do with the passed-in moment object.
		 */
		formats: {
			/**
			 * Within a day, show a relative time that’s easy to relate to.
			 */
			day: function (then) { return then.fromNow(); },
			
			/**
			 * Within a week, show a relative date and specific time, still helpful
			 * if the user doesn’t remember today’s date. Don’t show just a relative
			 * time, because a discussion may need more context than “Last Friday”
			 * on every comment.
			 */
			week: function (then) { return then.calendar(); },
			
			/**
			 * The calendar() method uses an ambiguous “MM/DD/YYYY” format for
			 * faraway dates; spell things out for this international audience.
			 */
			other: "LLL",
		},
		
		/**
		 * Formats to display in each timestamp’s tooltip, one per line.
		 * 
		 * If an element of this array is a string, the timestamp is formatted
		 * according to the documentation at
		 * <http://momentjs.com/docs/#/displaying/format/>.
		 * 
		 * If an element of this array is a function, it is called to retrieve the
		 * formatted timestamp string. See <http://momentjs.com/docs/#/displaying/>
		 * for the various things you can do with the passed-in moment object.
		 */
		tooltipFormats: [
			function (then) { return then.fromNow(); },
			"LLLL",
			"YYYY-MM-DDTHH:mmZ",
		],
		
		/**
		 * When true, this gadget refreshes timestamps periodically.
		 */
		dynamic: true,
	}, {
		// SITE OPTIONS ////////////////////////////////////////////////////////////
		
		/**
		 * Numbers of namespaces to completely ignore. See [[Wikipedia:Namespace]].
		 */
		excludeNamespaces: [-1, 0, 8, 100, 108, 118],
		
		/**
		 * Names of tags that often directly contain timestamps.
		 * 
		 * This is merely a performance optimization. This gadget will look at text
		 * nodes in any tag other than the codeTags, but adding a tag here ensures
		 * that it gets processed the most efficient way possible.
		 */
		proseTags: ["dd", "li", "p", "td"],
		
		/**
		 * Names of tags that don’t contain timestamps either directly or
		 * indirectly.
		 */
		codeTags: ["code", "input", "pre", "textarea"],
		
		/**
		 * Expected format or formats of the timestamps in existing wikitext. If
		 * very different formats have been used over the course of the wiki’s
		 * history, specify an array of formats.
		 * 
		 * This option expects parsing format strings
		 * <http://momentjs.com/docs/#/parsing/string-format/>.
		 */
		parseFormat: "H:m, D MMM YYYY",
		
		/**
		 * Regular expression matching all the timestamps inserted by this MediaWiki
		 * installation over the years. This regular expression should more or less
		 * agree with the parseFormat option.
		 * 
		 * Until 2005:
		 * 	18:16, 23 Dec 2004 (UTC)
		 * 2005–present:
		 * 	08:51, 23 November 2015 (UTC)
		 */
		parseRegExp: /\d\d:\d\d, \d\d? (?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w* \d{4} \(UTC\)/,
		
		/**
		 * UTC offset of the wiki's default local timezone. See
		 * [[mw:Manual:Timezone]].
		 */
		utcOffset: 0,
	}, window.LocalComments);
	
	$(function () {
		if (!LocalComments.enabled
			|| LocalComments.excludeNamespaces.indexOf(mw.config.get("wgNamespaceNumber")) !== -1
			|| ["view", "submit"].indexOf(mw.config.get("wgAction")) === -1
			|| mw.util.getParamValue("disable") === "loco")
		{
			return;
		}
		
		var proseTags = LocalComments.proseTags.join("\n").toUpperCase().split("\n");
		// Exclude <time> to avoid an infinite loop when iterating over text nodes.
		var codeTags = $.merge(LocalComments.codeTags, ["time"]).join(", ");
		
		// Look in the content body for DOM text nodes that may contain timestamps.
		// The wiki software has already localized other parts of the page.
		var root = $("#wikiPreview, #mw-content-text")[0];
		if (!root || !("createNodeIterator" in document)) return;
		var iter = document.createNodeIterator(root, NodeFilter.SHOW_TEXT, {
			acceptNode: function (node) {
				// We can’t just check the node’s direct parent, because templates
				// like [[Template:Talkback]] and [[Template:Resolved]] may place a
				// signature inside a nondescript <span>.
				var isInProse = proseTags.indexOf(node.parentElement.nodeName) !== -1
					|| !$(node).parents(codeTags).length;
				var isDateNode = isInProse && LocalComments.parseRegExp.test(node.data);
				return isDateNode ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
			},
		});
		
		// Mark up each timestamp found.
		function wrapTimestamps() {
			var prefixNode;
			const editorNode = $("div.wikiEditor-ui").get(0);
			while ((prefixNode = iter.nextNode())) {
				if (editorNode && editorNode.contains(prefixNode)) continue;
				var result = LocalComments.parseRegExp.exec(prefixNode.data);
				if (!result) continue;
				
				// Split out the timestamp into a separate text node.
				var dateNode = prefixNode.splitText(result.index);
				var suffixNode = dateNode.splitText(result[0].length);
				
				// Determine the represented time.
				var then = moment.utc(result[0], LocalComments.parseFormat);
				if (!then.isValid()) {
					// Many Wikipedias started out with English as the default
					// localization, so fall back to English.
					then = moment.utc(result[0], "H:m, D MMM YYYY", "en");
				}
				if (!then.isValid()) continue;
				then.utcOffset(-LocalComments.utcOffset);
				
				// Wrap the timestamp inside a <time> element for findability.
				var timeElt = $("<time />");
				// MediaWiki core styles .explain[title] the same way as
				// abbr[title], guiding the user to the tooltip.
				timeElt.addClass("localcomments explain");
				timeElt.attr("datetime", then.toISOString());
				$(dateNode).wrap(timeElt);
			}
		}
		
		/**
		 * Returns a formatted string for the given moment object.
		 * 
		 * @param {Moment} then The moment object to format.
		 * @param {String} fmt A format string or function.
		 * @returns {String} A formatted string.
		 */
		function formatMoment(then, fmt) {
			return (fmt instanceof Function) ? fmt(then) : then.format(fmt);
		}
		
		/**
		 * Reformats a timestamp marked up with the <time> element.
		 * 
		 * @param {Number} idx Unused.
		 * @param {Element} elt The <time> element.
		 */
		function formatTimestamp(idx, elt) {
			var iso = $(elt).attr("datetime");
			var then = moment(iso, moment.ISO_8601);
			var now = moment();
			var withinHours = Math.abs(then.diff(now, "hours", true))
				<= moment.relativeTimeThreshold("h");
			var formats = LocalComments.formats;
			var text;
			if (withinHours) {
				text = formatMoment(then, formats.day || formats.other);
			}
			else {
				var dayDiff = then.diff(moment().startOf("day"), "days", true);
				if (dayDiff > -6 && dayDiff < 7) {
					text = formatMoment(then, formats.week || formats.other);
				}
				else text = formatMoment(then, formats.other);
			}
			$(elt).text(text);
			
			// Add a tooltip with multiple formats.
			elt.title = $.map(LocalComments.tooltipFormats, function (fmt, idx) {
				return formatMoment(then, fmt);
			}).join("\n");
			
			// Register for periodic updates.
			var withinMinutes = withinHours
				&& Math.abs(then.diff(now, "minutes", true))
					<= moment.relativeTimeThreshold("m");
			var withinSeconds = withinMinutes
				&& Math.abs(then.diff(now, "seconds", true))
					<= moment.relativeTimeThreshold("s");
			var unit = withinSeconds ? "seconds" :
				(withinMinutes ? "minutes" :
					(withinHours ? "hours" : "days"));
			$(elt).attr("data-localcomments-unit", unit);
		}
		
		/**
		 * Reformat all marked-up timestamps and start updating timestamps on an
		 * interval as necessary.
		 */
		function formatTimestamps() {
			wrapTimestamps();
			$(".localcomments").each(function (idx, elt) {
				// Update every timestamp at least this once.
				formatTimestamp(idx, elt);
				
				if (!LocalComments.dynamic) return;
				
				// Update this minute’s timestamps every second.
				if ($("[data-localcomments-unit='seconds']").length) {
					setInterval(function () {
						$("[data-localcomments-unit='seconds']").each(formatTimestamp);
					}, 1000 /* ms */);
				}
				// Update this hour’s timestamps every minute.
				setInterval(function () {
					$("[data-localcomments-unit='minutes']").each(formatTimestamp);
				}, 60 /* s */ * 1000 /* ms */);
				// Update today’s timestamps every hour.
				setInterval(function () {
					$("[data-localcomments-unit='hours']").each(formatTimestamp);
				}, 60 /* min */ * 60 /* s */ * 1000 /* ms */);
			});
		}
		
		mw.loader.using("moment", function () {
			wrapTimestamps();
			formatTimestamps();
		});
	});
}
/*
MediaWiki:Gadget-navboxToggle.js
*/
$(function () {
	'use strict';
	var navToggle = function () {
		if ($('.navbox.mw-collapsible').length) {
			var $arrow = $('<span>')
				.addClass('mf-icon mf-icon-expand mf-icon--small indicator');
			var $navigationText = $('<span>')
				.addClass('mw-headline')
				.attr('tabindex', '0')
				.attr('role', 'button')
				.text('Navigation');
			var $toggleBar = $('<h2>')
				.attr('id', 'navbox-fake-collapsible-heading')
				.addClass('section-heading collapsible-heading')
				.append($arrow)
				.append($navigationText);
	
			$toggleBar.on('click', function () {
				// flip arrow
				$('#navbox-fake-collapsible-heading > .mf-icon').toggleClass('mf-icon-rotate-flip');
				// collapse navboxes
				$('.navbox.mw-collapsible').toggle();
			});
	
			// pull out navboxes so they don't get collapsed by the previous section
			var $navboxes = $('.navbox.mw-collapsible').detach();
			// default to hidden
			$navboxes.toggle();
			// append everything to the end of the content section
			$('.mw-parser-output').first().append($toggleBar).append($navboxes);
		}
	};
	
	function init() {
		var tOut = setTimeout(clearInterval, 30000, checkSections);
		var checkSections = setInterval(function () {
			if ($('.mw-parser-output .collapsible-heading span[aria-expanded]').length) {
				navToggle();
				clearTimeout(tOut);
				clearInterval(checkSections);
			}
		}, 500);
	}
	
	init();
});
/*
MediaWiki:Gadget-audioplayer.js
*/
$(function () {
	if ($( 'a[href^="/w/File:"][href$=".ogg"]' ).length) {
		mw.loader.load( 'ext.gadget.audioplayer-core' );
	}
})
/*
MediaWiki:Gadget-musicMap.js
*/
$(function () {
	if ($("#musicMap").length) {
		mw.loader.load( 'ext.gadget.musicmap-core' );
	}
})
/*
MediaWiki:Gadget-equipment.js
*/
// Make buttons for Items Kept on Death and Equipment Stats on Template:Equipment clickable,
// if equipment stats and buttons are shown.

$(function() {
	$('.equipment-statsbutton, .equipment-ikodbutton').click(function() {
		var ikod = $(this).parents('.equipment').find('.equipment-ikod'),
			stats = $(this).parents('.equipment').find('.equipment-stats');
		if ($(this).is('.equipment-statsbutton')) {
			ikod.hide();
			stats.show();
		} else {
			stats.hide();
			ikod.show();
		}
	});
});
/*
MediaWiki:Gadget-fileDownload.js
*/
/**
 * Adds a download link to file pages
 * 
 * @author Gaz Lloyd
 */
$(function(){
	if (!(mw.config.get('wgNamespaceNumber') === 6  && $('.fullMedia, .filehistory').length > 0)) {
		return;
	}
	function addLinks() {
		// underneath image - also replace filename with page title
		$('.fullMedia a.internal').after(
			' (',
			$('<a>')
				.text('download')
				.addClass('fileDownload')
				.attr({
					href: $('.fullMedia a.internal').attr('href'),
					download: mw.config.get('wgTitle').replace('_', ' '),
					title: 'Download this file'
				}),
			')'
		);
		
		// file history - leave numbers in file name
		$('.filehistory tr td[style]').each(function() {
			var $this = $(this);
			$this.append(
				$('<br />'),
				$('<a>')
					.text('Download')
					.addClass('fileDownload')
					.attr({
						download: '',
						href: $this.find('a').attr('href'),
						title: 'Download this version of this file'
					})
			);
		});
	}
	addLinks()
})
/*
MediaWiki:Gadget-oswf.js
*/
$(function () {
	if ( $('.oswf-guidance').length ) {
		mw.loader.load( 'ext.gadget.oswf-core' );
	}
})
/*
MediaWiki:Gadget-tilemarkers.js
*/
$(function () {
	if ($( '.tilemarker-div' ).length) {
		mw.loader.load( 'ext.gadget.tilemarkers-core' );
	}
})
/*
MediaWiki:Gadget-loadout.js
*/
$(function () {
	if ($( '.loadout-code' ).length) {
		mw.loader.load( 'ext.gadget.loadout-core' );
	}
})
/*
MediaWiki:Gadget-leaguefilter.js
*/
$(function () {
	if ($( '.league-area-filter' ).length) {
		mw.loader.load( 'ext.gadget.leaguefilter-core' );
	}
})
(function () {
	mw.hook( 'wikipage.content' ).add( () => {
		document.querySelectorAll('[data-service="local-embed"] .embedvideo-wrapper').forEach(function (div) {
			const clickListener = function () {
				video.controls = true;
				video.play();
				consentDiv.removeEventListener('click', clickListener);
				consentDiv.parentElement.removeChild(consentDiv);
			};

			const consentDiv = div.querySelector('.embedvideo-consent');
			const video = div.querySelector('video');
			const fakeButton = div.querySelector('.embedvideo-loader__fakeButton');
			fakeButton.innerHTML = mw.message('embedvideo-play').escaped();

			if (consentDiv === null || video === null) {
				return;
			}

			video.controls = false;

			consentDiv.addEventListener('click', clickListener);
		})
	} );
})();
(self.webpackChunkmfModules=self.webpackChunkmfModules||[]).push([[243],{"./src/mobile.init/editor.js":(e,t,i)=>{var o=i("./src/mobile.startup/moduleLoaderSingleton.js"),n=i("./src/mobile.startup/util.js"),a=i("./src/mobile.init/editorLoadingOverlay.js"),r=i("./src/mobile.startup/OverlayManager.js"),s=$("#ca-edit, #ca-editsource, #ca-viewsource, #ca-ve-edit, #ca-ve-create, #ca-createsource"),l=s.length>1,c=".mw-editsection a, .edit-link",d=mw.user,u=i("./src/mobile.startup/CtaDrawer.js"),m=mw.config.get("wgVisualEditorConfig"),f=/^\/editor\/(\d+|T-\d+|all)$/,g=null;function p(e,t,i){var o;o=0===$(c).length?"all":mw.util.getParamValue("section",e.href)||"all",mw.config.get("wgPageName")===mw.util.getParamValue("title",e.href)&&(l&&("ca-ve-edit"===e.id||"ca-ve-create"===e.id?g="VisualEditor":"ca-editsource"!==e.id&&"ca-createsource"!==e.id||(g="SourceEditor")),i.navigate("#/editor/"+o),t.preventDefault())}function w(){if(g)return g;var e=mw.user.options.get("mobile-editor")||mw.storage.get("preferredEditor");if(e)return e;switch(mw.config.get("wgMFDefaultEditor")){case"source":return"SourceEditor";case"visual":return"VisualEditor";case"preference":return mw.user.options.get("visualeditor-hidebetawelcome")||mw.user.options.get("visualeditor-hideusered")?"visualeditor"===mw.user.options.get("visualeditor-editor")?"VisualEditor":"SourceEditor":"visual"===mw.config.get("wgMFFallbackEditor")?"VisualEditor":"SourceEditor"}return"SourceEditor"}function h(e,t){s.on("click",(function(t){mw.notify(e),t.preventDefault()})),mw.hook("wikipage.content").add((function(t){t.find(c).on("click",(function(t){mw.notify(e),t.preventDefault()}))})),t.addRoute(f,(function(){mw.notify(e)})),t.checkRoute()}e.exports=function(e,t,i){var l=require("mediawiki.router");e.inNamespace("file")&&0===e.id?h(mw.msg("mobile-frontend-editor-uploadenable"),l):function(e,t,i,l){var b,v=mw.config.get("wgMinervaReadOnly");if(!v&&mw.config.get("wgIsProbablyEditable"))!function(e,t,i,l){var u=r.getSingleton(),h=0===e.id;if(s.add(".edit-link").on("click.mfeditlink",(function(e){p(this,e,u.router)})),mw.hook("wikipage.content").add((function(e){e.find(c).off("click.mfeditlink").on("click.mfeditlink",(function(e){p(this,e,u.router)}))})),u.add(f,(function(r){var s,l,c=window.pageYOffset,f=$("#mw-content-text"),p=new URL(location.href),b={overlayManager:u,currentPageHTMLParser:i,fakeScroll:0,api:new mw.Api,licenseMsg:t.getLicenseMsg(),title:e.title,titleObj:e.titleObj,isAnon:d.isAnon(),isNewPage:h,oldId:mw.util.getParamValue("oldid"),contentLang:f.attr("lang"),contentDir:f.attr("dir"),preload:p.searchParams.get("preload"),preloadparams:mw.util.getArrayParam("preloadparams",p.searchParams),editintro:p.searchParams.get("editintro")},v=$.Deferred(),y=n.Deferred(),k=mw.util.getParamValue("redlink")?"new":"click";function x(e){mw.track("editAttemptStep",{action:"init",type:"section",mechanism:k,integration:"page",editor_interface:e})}function E(){var t=w();return e.isVESourceAvailable()||e.isVEVisualAvailable()&&"VisualEditor"===t}function C(){return x("wikitext"),mw.hook("mobileFrontend.editorOpening").fire(),mw.loader.using("mobile.editor.overlay").then((function(){return new(o.require("mobile.editor.overlay/SourceEditorOverlay"))(b)}))}"all"!==r&&(b.sectionId=e.isWikiText()?r:void 0);var S=a((function(){var e,t,i;$(document.body).addClass("ve-loading");var o=$("#mw-mf-page-center"),n=$("#content");"0"===r||"all"===r?e=$("#bodyContent"):(e=$('a[href$="section='+r+'"],a[href*="section='+r+'&"]').closest(".mw-heading, h1, h2, h3, h4, h5, h6")).length||(e=$("#bodyContent")),o.prop("scrollTop",c),t=e[0].getBoundingClientRect().top,t-=48,E()?(i=!0===m.enableVisualSectionEditing||"mobile"===m.enableVisualSectionEditing,("0"===r||"all"===r||i)&&(t-=16)):"0"!==r&&"all"!==r||(t-=16),n.css({transform:"translate( 0, "+-t+"px )","padding-bottom":"+="+t,"margin-bottom":"-="+t}),b.fakeScroll=t,setTimeout(y.resolve,500)}),(function(){s&&s.abort&&s.abort(),$("#content").css({transform:"","padding-bottom":"","margin-bottom":""}),$(document.body).removeClass("ve-loading")}),E()?function(){k="tooslow",v.reject(),s&&s.abort&&s.abort()}:null);return l=E()?function(){x("visualeditor"),mw.hook("mobileFrontend.editorOpening").fire(),b.mode=mw.config.get("wgMFEnableVEWikitextEditor")&&"SourceEditor"===w()?"source":"visual",b.dataPromise=mw.loader.using("ext.visualEditor.targetLoader").then((function(){return s=mw.libs.ve.targetLoader.requestPageData(b.mode,b.titleObj.getPrefixedDb(),{sessionStore:!0,section:void 0===b.sectionId?null:b.sectionId,oldId:b.oldId||void 0,preload:b.preload,preloadparams:b.preloadparams,editintro:b.editintro,targetName:"mobile"})}));var e=mw.loader.using("ext.visualEditor.targetLoader").then((function(){return mw.loader.using("mobile.editor.overlay").then((function(){return mw.libs.ve.targetLoader.addPlugin("ext.visualEditor.mobileArticleTarget"),mw.config.get("wgMFEnableVEWikitextEditor")&&mw.libs.ve.targetLoader.addPlugin("ext.visualEditor.mwwikitext"),mw.libs.ve.targetLoader.loadModules(b.mode)}))})),t=$.Deferred();return e.then(t.resolve,t.reject),v.then(t.reject,t.reject),t.then((function(){var e=o.require("mobile.editor.overlay/VisualEditorOverlay"),t=o.require("mobile.editor.overlay/SourceEditorOverlay");return b.SourceEditorOverlay=t,new e(b)}),(function(){return C()}))}():C(),n.Promise.all([l,y]).then((function(e){e.getLoadingPromise().catch((function(t){return"rejected"===v.state()?C().then((function(t){return(e=t).getLoadingPromise()})):$.Deferred().reject(t).promise()})).then((function(){var t=u.stack[0];t&&t.overlay===S&&u.replaceCurrent(e)}),(function(e,t){u.router.back(),e.show?(document.body.appendChild(e.$el[0]),e.show()):t?mw.notify(b.api.getErrorMessage(t)):mw.notify(mw.msg("mobile-frontend-editor-error-loading"))}))})),g=null,S})),$("#ca-edit a, a#ca-edit, #ca-editsource a, a#ca-editsource").prop("href",(function(e,t){var i=new URL(t,location.href);return i.searchParams.set("section","0"),i.toString()})),!l.getPath()&&(mw.util.getParamValue("veaction")||"edit"===mw.config.get("wgAction"))){"edit"===mw.util.getParamValue("veaction")?g="VisualEditor":"editsource"===mw.util.getParamValue("veaction")&&(g="SourceEditor");var b="#/editor/"+(mw.util.getParamValue("section")||("edit"===mw.config.get("wgAction")?"all":"0"));if(window.history&&history.pushState){var v=new URL(location.href);v.searchParams.delete("action"),v.searchParams.delete("veaction"),v.searchParams.delete("section"),history.replaceState(null,document.title,v)}n.docReady((function(){l.navigate(b)}))}}(e,i,t,l);else if(function(e){e.$el.find(".mw-editsection").hide()}(t),b=mw.config.get("wgRestrictionEdit"),mw.user.isAnon()&&Array.isArray(b)&&!b.length)!function(e){var t;function i(){t||(t=new u({content:mw.msg("mobile-frontend-editor-disabled-anon"),signupQueryParams:{warning:"mobile-frontend-watchlist-signup-action"}}),document.body.appendChild(t.$el[0])),t.show()}s.on("click",(function(e){i(),e.preventDefault()})),mw.hook("wikipage.content").add((function(e){e.find(c).on("click",(function(e){i(),e.preventDefault()}))})),e.addRoute(f,(function(){i()})),e.checkRoute()}(l);else{var y=$("<a>").attr("href",mw.util.getUrl(mw.config.get("wgPageName"),{action:"edit"}));h(v?mw.msg("apierror-readonly"):mw.message("mobile-frontend-editor-disabled",y).parseDom(),l)}}(e,t,i,l)}},"./src/mobile.init/editorLoadingOverlay.js":(e,t,i)=>{var o=i("./src/mobile.init/fakeToolbar.js"),n=i("./src/mobile.startup/IconButton.js"),a=i("./src/mobile.startup/Overlay.js");e.exports=function(e,t,i){var r,s=o(),l=$("<div>").addClass("ve-loadbasiceditor"),c=new n({label:mw.msg("mobile-frontend-editor-loadbasiceditor"),action:"progressive",weight:"normal",size:"medium",isIconOnly:!1,icon:null}),d=new a({className:"overlay overlay-loading",noHeader:!0,isBorderBox:!1,onBeforeExit:function(e){e(),t(),r&&clearTimeout(r)}}),u=function(e,t){mw.track("visualEditorFeatureUse",{feature:e,action:t,editor_interface:"visualeditor"})};return d.show=function(){a.prototype.show.call(this),e()},d.$el.find(".overlay-content").append(s),i&&(d.$el.find(".overlay-content").append(l.append($("<p>").text(mw.msg("mobile-frontend-editor-loadingtooslow")),c.$el)),r=setTimeout((function(){l.addClass("ve-loadbasiceditor-shown"),u("mobileVisualFallback","context-show")}),3e3),c.$el.on("click",(function(){l.removeClass("ve-loadbasiceditor-shown"),u("mobileVisualFallback","fallback-confirm"),i()}))),s.addClass("toolbar-hidden"),setTimeout((function(){s.addClass("toolbar-shown"),setTimeout((function(){s.addClass("toolbar-shown-done")}),250)})),d}},"./src/mobile.init/lazyLoadedImages.js":(e,t,i)=>{var o=i("./src/mobile.startup/lazyImages/lazyImageLoader.js");function n(e){if(e[0]instanceof HTMLElement){var t=o.queryPlaceholders(e[0]);if(window.addEventListener("beforeprint",(function(){o.loadImages(t)})),mw.config.get("wgMFLazyLoadImages")){var i=new IntersectionObserver((function(e){e.forEach((function(e){var t=e.target;e.isIntersecting&&(o.loadImage(t),i.unobserve(t))}))}),{rootMargin:"0px 0px 50% 0px",threshold:0});t.forEach((function(e){i.observe(e)}))}}}mw.hook("mobileFrontend.loadLazyImages").add((function(e){var t=o.queryPlaceholders(e[0]);o.loadImages(t)})),e.exports=function(){mw.hook("wikipage.content").add(n)}},"./src/mobile.init/mobile.init.js":(e,t,i)=>{var o,n=i("./src/mobile.init/toggling.js"),a="mf-font-size",r="mf-expand-sections",s=mw.storage,l=new mw.Api,c=i("./src/mobile.init/lazyLoadedImages.js"),d=i("./src/mobile.init/editor.js"),u=i("./src/mobile.startup/currentPage.js")(),m=i("./src/mobile.startup/currentPageHTMLParser.js")(),f=i("./src/mobile.startup/util.js").getWindow(),g=i("./src/mobile.startup/Skin.js"),p=i("./src/mobile.startup/eventBusSingleton.js"),w=g.getSingleton();function h(e,t){return function(){e.apply(this,arguments),t.apply(this,arguments)}}f.on("resize",h(mw.util.debounce((function(){p.emit("resize")}),100),mw.util.throttle((function(){p.emit("resize:throttled")}),200))).on("scroll",h(mw.util.debounce((function(){p.emit("scroll")}),100),mw.util.throttle((function(){p.emit("scroll:throttled")}),200))),window.history&&history.pushState&&((o=new URL(window.location.href)).searchParams.has("venotify")||o.searchParams.has("mfnotify"))&&(o.searchParams.delete("venotify"),o.searchParams.delete("mfnotify"),window.history.replaceState(null,document.title,o.toString())),window.console&&window.console.log&&window.console.log.apply&&mw.config.get("wgMFEnableJSConsoleRecruitment")&&console.log(mw.msg("mobile-frontend-console-recruit")),mw.config.get("wgMFIsSupportedEditRequest")&&d(u,m,w),document.documentElement.classList.contains("mf-font-size-clientpref-xlarge")&&(mw.user.isAnon()?mw.user.clientPrefs.set(a,"large"):l.saveOption(a,"large")),mw.storage.get("expandSections")&&(mw.user.isAnon()?mw.user.clientPrefs.set(r,"1"):l.saveOption(r,"1"),s.remove("expandSections")),n(),c()},"./src/mobile.init/toggling.js":(e,t,i)=>{e.exports=function(){var e=i("./src/mobile.startup/currentPage.js")(),t=i("./src/mobile.startup/Toggler.js"),o=i("./src/mobile.startup/sectionCollapsing.js"),n=i("./src/mobile.startup/eventBusSingleton.js");e.inNamespace("special")||"view"!==mw.config.get("wgAction")&&"edit"!==mw.config.get("wgAction")||mw.hook("wikipage.content").add((function(i){var a=i.find(".mw-parser-output");0===a.length&&(a=i),function(e,i,a){document.querySelector(".mw-parser-output[data-mw-parsoid-version]")?o.init(e[0]):(e.find(".section-heading").removeAttr("onclick"),void 0!==window.mfTempOpenSection&&delete window.mfTempOpenSection,new t({$container:e,prefix:"content-",page:a,eventBus:n}))}(a,0,e)}))}},"./src/mobile.startup/Toggler.js":(e,t,i)=>{var o=i("./src/mobile.startup/util.js"),n=o.escapeSelector,a={icon:"expand",isSmall:!0,additionalClassNames:"indicator"},r=i("./src/mobile.startup/Icon.js"),s=i("./src/mobile.startup/isCollapsedByDefault.js");function l(e){this.eventBus=e.eventBus,this.$container=e.$container,this.prefix=e.prefix,this.page=e.page,this._enable()}function c(e){var t=mw.storage.session.getObject("expandedSections")||{};return t[e.title]=t[e.title]||{},t}function d(e,t,i){var o=c(i);t.find(".section-heading span").each((function(){var n=t.find(this),a=n.parents(".section-heading");o[i.title][n.attr("id")]&&!a.hasClass("open-block")&&e.toggle(a,!0)}))}l.prototype.isCollapsedByDefault=function(){if(void 0===this._isCollapsedByDefault){var e=this.$container.closest(".collapsible-headings-collapsed, .collapsible-headings-expanded");e.length?this._isCollapsedByDefault=e.hasClass("collapsible-headings-collapsed"):this._isCollapsedByDefault=s()}return this._isCollapsedByDefault},l.prototype.toggle=function(e,t){if(!t&&e.hasClass("collapsible-heading-disabled"))return!1;var i=this,o=e.is(".open-block");e.toggleClass("open-block"),a.rotation=o?0:180;var n=new r(a),s=e.data("indicator");s&&(s.replaceWith(n.$el),e.data("indicator",n.$el)),e.find(".mw-headline").attr("aria-expanded",!o);var l=e.next();return l.hasClass("open-block")?(l.removeClass("open-block"),l.get(0).setAttribute("hidden","until-found")):(l.addClass("open-block"),l.removeAttr("hidden")),mw.requestIdleCallback((function(){i.eventBus.emit("section-toggled",{expanded:o,$heading:e}),mw.hook("mobileFrontend.section-toggled").fire({expanded:o,$heading:e})})),this.isCollapsedByDefault()&&function(e,t){var i=e.find(".mw-headline").attr("id"),o=c(t);i&&o[t.title]&&(e.hasClass("open-block")?o[t.title][i]=!0:delete o[t.title][i],function(e){mw.storage.session.setObject("expandedSections",e)}(o))}(e,this.page),!0},l.prototype.reveal=function(e){var t;try{t=this.$container.find("#"+n(e))}catch(e){}if(!t||!t.length)return!1;var i=t.parents(".collapsible-heading");return i.length||(i=t.parents(".collapsible-block").prev(".collapsible-heading")),i.length&&!i.hasClass("open-block")&&this.toggle(i),i.length&&window.scrollTo(0,t.offset().top),!0},l.prototype._enable=function(){var e,t,i=this;function n(){var e=window.location.hash;if(0===e.indexOf("#")&&(e=e.slice(1),!i.reveal(e))){var t=mw.util.percentDecodeFragment(e);t&&i.reveal(t)}}this.$container.children(".section-heading").each((function(e){var t=i.$container.find(this),o=t.find(".mw-headline"),n=t.find(".indicator"),s=i.prefix+"collapsible-block-"+e;if(t.next().is("section")){var l=t.next("section");t.addClass("collapsible-heading ").data("section-number",e).on("click",(function(e){var o=e.target.closest("a");o&&o.href||(e.preventDefault(),i.toggle(t))})),o.attr({tabindex:0,role:"button","aria-controls":s,"aria-expanded":"false"}),a.rotation=i.isCollapsedByDefault()?0:180;var c=new r(a);n.length?n.replaceWith(c.$el):c.prependTo(t),t.data("indicator",c.$el),l.addClass("collapsible-block").eq(0).attr({id:s}).on("beforematch",(function(){return i.toggle(t)})).addClass("collapsible-block-js").get(0).setAttribute("hidden","until-found"),function(e,t){t.on("keypress",(function(i){13!==i.which&&32!==i.which||e.toggle(t)})).find("a").on("keypress mouseup",(function(e){return e.stopPropagation()}))}(i,t),i.isCollapsedByDefault()||i.toggle(t)}})),(t=!!(e=mw.config.get("wgInternalRedirectTargetUrl"))&&e.split("#")[1])&&(window.location.hash=t),n(),o.getWindow().on("hashchange",(function(){return n()})),this.isCollapsedByDefault()&&this.page&&d(this,this.$container,this.page)},l._getExpandedSections=c,l._expandStoredSections=d,e.exports=l},"./src/mobile.startup/isCollapsedByDefault.js":(e,t,i)=>{var o=i("./src/mobile.startup/Browser.js").getSingleton();e.exports=function(){return mw.config.get("wgMFCollapseSectionsByDefault")&&!o.isWideScreen()&&!document.documentElement.classList.contains("mf-expand-sections-clientpref-1")}},"./src/mobile.startup/sectionCollapsing.js":(e,t,i)=>{var o=i("./src/mobile.startup/isCollapsedByDefault.js");function n(e,t,i,o){e.hidden=!!o&&"until-found",o?(t.setAttribute("aria-expanded","true"),i.classList.add("mf-icon-expand"),i.classList.remove("mf-icon-collapse")):(t.setAttribute("aria-expanded","false"),i.classList.add("mf-icon-collapse"),i.classList.remove("mf-icon-expand"))}e.exports={init:function(e){var t=o();Array.from(e.querySelectorAll(".mw-parser-output > section > .mw-heading")).forEach((function(e){e.classList.add("mf-collapsible-heading");var i=e.firstElementChild,o=e.nextElementSibling;o.classList.add("mf-collapsible-content");var a=document.createElement("span");a.textContent=i.textContent,a.setAttribute("tabindex","0"),a.setAttribute("role","button"),a.setAttribute("aria-controls",o.id);var r=document.createElement("span");r.classList.add("mf-icon","mf-icon--small","mf-collapsible-icon"),r.setAttribute("aria-hidden",!0),n(o,a,r,t),i.innerHTML="",i.append(r),i.append(a),i.addEventListener("click",(function(){return function(e,t,i){n(e,t,i,!e.hidden)}(o,a,r)}))}))}}}},e=>{e.O(0,[569],(()=>e(e.s="./src/mobile.init/mobile.init.js")));var t=e.O();(this.mfModules=this.mfModules||{})["mobile.init"]=t}]);
//# sourceMappingURL=mobile.init.js.map.json
mw.loader.impl(function(){return["ext.checkUser.clientHints@",{"main":"index.js","files":{"index.js":function(require,module,exports){( function () {
	/**
	 * Set up the listener for the postEdit hook, if client hints are supported by the browser.
	 *
	 * @param {Navigator|Object} navigatorData
	 * @return {boolean} true if client hints integration has been set up on postEdit hook,
	 *   false otherwise.
	 */
	function init( navigatorData ) {
		const hasHighEntropyValuesMethod = navigatorData.userAgentData &&
			navigatorData.userAgentData.getHighEntropyValues;
		if ( !hasHighEntropyValuesMethod ) {
			// The browser doesn't support navigator.userAgentData.getHighEntropyValues. Used
			// for tests.
			return false;
		}

		const wgCheckUserClientHintsHeadersJsApi = mw.config.get( 'wgCheckUserClientHintsHeadersJsApi' );

		/**
		 * POST an object with user-agent client hint data to a CheckUser REST endpoint.
		 *
		 * @param {Object} clientHintData Data structured returned by
		 *  navigator.userAgentData.getHighEntropyValues()
		 * @param {boolean} retryOnTokenMismatch Whether to retry the POST if the CSRF token is a
		 *  mismatch. A mismatch can happen if the token has expired.
		 * @return {jQuery.Promise} A promise that resolves after the POST is complete.
		 */
		function postClientHintData( clientHintData, retryOnTokenMismatch ) {
			const restApi = new mw.Rest();
			const api = new mw.Api();
			const deferred = $.Deferred();
			api.getToken( 'csrf' ).then( ( token ) => {
				clientHintData.token = token;
				restApi.post(
					'/checkuser/v0/useragent-clienthints/revision/' + mw.config.get( 'wgCurRevisionId' ),
					clientHintData
				).then(
					( data ) => {
						deferred.resolve( data );
					}
				).fail( ( err, errObject ) => {
					mw.log.error( errObject );
					let errMessage = errObject.exception;
					if (
						errObject.xhr &&
						errObject.xhr.responseJSON &&
						errObject.xhr.responseJSON.messageTranslations
					) {
						errMessage = errObject.xhr.responseJSON.messageTranslations.en;
					}
					if (
						retryOnTokenMismatch &&
						errObject.xhr &&
						errObject.xhr.responseJSON &&
						errObject.xhr.responseJSON.errorKey &&
						errObject.xhr.responseJSON.errorKey === 'rest-badtoken'
					) {
						// The CSRF token has expired. Retry the POST with a new token.
						api.badToken( 'csrf' );
						postClientHintData( clientHintData, false ).then(
							( data ) => {
								deferred.resolve( data );
							},
							( secondRequestErr, secondRequestErrObject ) => {
								deferred.reject( secondRequestErr, secondRequestErrObject );
							}
						);
					} else {
						mw.errorLogger.logError( new Error( errMessage ), 'error.checkuser' );
						deferred.reject( err, errObject );
					}
				} );
			} ).fail( ( err, errObject ) => {
				mw.log.error( errObject );
				let errMessage = errObject.exception;
				if ( errObject.xhr &&
				errObject.xhr.responseJSON &&
				errObject.xhr.responseJSON.messageTranslations ) {
					errMessage = errObject.xhr.responseJSON.messageTranslations.en;
				}
				mw.errorLogger.logError( new Error( errMessage ), 'error.checkuser' );
				deferred.reject( err, errObject );
			} );
			return deferred.promise();
		}

		/**
		 * Respond to postEdit hook, fired by MediaWiki core, VisualEditor and DiscussionTools.
		 *
		 * Note that CheckUser only adds this code to article page views if
		 * CheckUserClientHintsEnabled is set to true.
		 */
		mw.hook( 'postEdit' ).add( () => {
			try {
				navigatorData.userAgentData.getHighEntropyValues(
					wgCheckUserClientHintsHeadersJsApi
				).then( ( userAgentHighEntropyValues ) => postClientHintData( userAgentHighEntropyValues, true ) );
			} catch ( err ) {
				// Handle NotAllowedError, if the browser throws it.
				mw.log.error( err );
				mw.errorLogger.logError( new Error( err ), 'error.checkuser' );
			}
		} );
		return true;
	}

	init( navigator );

	module.exports = {
		init: init
	};
}() );
}}}];});
mw.loader.impl(function(){return["ext.popups@",{"main":"resources/ext.popups/index.js","files":{"resources/ext.popups/types.json":[
    "ext.cite.referencePreviews",
    "ext.math.popup"
],"resources/ext.popups/index.js":function(require,module,exports){const types = require( './types.json' );
// Load Popups when touch events are not available in the browser (e.g. not a mobile device).
const isTouchDevice = 'ontouchstart' in document.documentElement;
let supportNotQueries;
try {
	supportNotQueries = document.body.matches( 'div:not(.foo,.bar)' );
	supportNotQueries = true;
} catch ( e ) {
	supportNotQueries = false;
}
if ( !isTouchDevice && supportNotQueries ) {
	mw.loader.using( types.concat( [ 'ext.popups.main' ] ) ).then( function () {
		// Load custom popup types
		types.forEach( function ( moduleName ) {
			const module = require( moduleName );
			// Check the module exists. A module can export undefined or null if
			// it does not want to be registered (for example where registration may
			// depend on something that can only be checked at runtime.
			// For example the Math module shouldn't register itself if there are no Math
			// equations on the page.
			if ( module ) {
				mw.popups.register( module );
			}
		} );
		// For now this API is limited to extensions/skins as we have not had a chance to
		// consider the implications of gadgets having access to this function and dealing with
		// challenges such as selector overlap.
		delete mw.popups.register;
	} );
}
}}}];});
/*!
 * This file is part of the Semantic MediaWiki Purge module
 * @see https://www.semantic-mediawiki.org/wiki/Help:Purge
 *
 * @since 2.5
 * @revision 0.0.1
 *
 * @file
 * @ingroup SMW
 *
 * @licence GNU GPL v2+
 * @author samwilson, mwjames
 */

/*global jQuery, mediaWiki, smw */
/*jslint white: true */

( function( $, mw ) {

	'use strict';

	var purge = function( context ) {

		var forcelinkupdate = false;

		if ( context.data( 'title' ) ) {
			var title = context.data( 'title' );
		} else {
			var title = mw.config.get( 'wgPageName' );
		}

		if ( context.data( 'msg' ) ) {
			mw.notify( mw.msg( context.data( 'msg' ) ), { type: 'info', autoHide: false } );
		};

		if ( context.data( 'forcelinkupdate' ) ) {
			forcelinkupdate = context.data( 'forcelinkupdate' );
		};

		var postArgs = { action: 'purge', titles: title, forcelinkupdate: forcelinkupdate };

		new mw.Api().post( postArgs ).then( function () {
			location.reload();
		}, function () {
			mw.notify( mw.msg( 'smw-purge-failed' ), { type: 'error' } );
		} );
	}

	// JS is loaded, now remove the "soft" disabled functionality
	$( "#ca-purge" ).removeClass( 'is-disabled' );

	// Observed on the chameleon skin
	$( "#ca-purge a" ).removeClass( 'is-disabled' );

	$( "#ca-purge a, .purge" ).on( 'click', function ( e ) {
		purge( $( this ) );
		e.preventDefault();
	} );

	$( ".page-purge" ).each( function () {
		purge( $( this ) );
	} );

}( jQuery, mediaWiki ) );
mw.loader.state({
    "ext.cite.ux-enhancements": "ready",
    "ext.kartographer.link": "ready",
    "ext.scribunto.logs": "ready",
    "site": "ready",
    "mediawiki.page.ready": "ready",
    "jquery.tablesorter": "ready",
    "skins.minerva.scripts": "ready",
    "ext.gadget.rsw-util": "ready",
    "ext.gadget.switch-infobox": "ready",
    "ext.gadget.exchangePages": "ready",
    "ext.gadget.GECharts": "ready",
    "ext.gadget.highlightTable": "ready",
    "ext.gadget.titleparenthesis": "ready",
    "ext.gadget.tooltips": "ready",
    "ext.gadget.Username": "ready",
    "ext.gadget.countdown": "ready",
    "ext.gadget.checkboxList": "ready",
    "ext.gadget.Charts": "ready",
    "ext.gadget.navbox-tracking": "ready",
    "ext.gadget.wikisync": "ready",
    "ext.gadget.smwlistsfull": "ready",
    "ext.gadget.jsonDoc": "ready",
    "ext.gadget.articlefeedback": "ready",
    "ext.gadget.calc": "ready",
    "ext.gadget.calculatorNS": "ready",
    "ext.gadget.dropDisplay": "ready",
    "ext.gadget.mmgkc": "ready",
    "ext.gadget.fightcaverotations": "ready",
    "ext.gadget.livePricesMMG": "ready",
    "ext.gadget.skinTogglesMobile": "ready",
    "ext.gadget.relativetime": "ready",
    "ext.gadget.navboxToggle": "ready",
    "ext.gadget.audioplayer": "ready",
    "ext.gadget.musicmap": "ready",
    "ext.gadget.equipment": "ready",
    "ext.gadget.fileDownload": "ready",
    "ext.gadget.oswf": "ready",
    "ext.gadget.tilemarkers": "ready",
    "ext.gadget.loadout": "ready",
    "ext.gadget.leaguefilter": "ready",
    "ext.embedVideo.overlay": "ready",
    "mobile.init": "ready",
    "ext.checkUser.clientHints": "ready",
    "ext.popups": "ready",
    "ext.smw.purge": "ready"
});