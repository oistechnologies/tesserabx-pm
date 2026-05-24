/**
 * tesserabx-pm kanban drag-and-drop wiring.
 *
 * Initialised per CBWire component on the livewire:init + component.init
 * hook (PM CLAUDE.md global rule: DOMContentLoaded is too early — the
 * wire is not registered yet). The CBWire template inlines a script
 * tag that calls window.tesserabxPmKanban.init(componentId) inside
 * the hook callback once the component matches.
 *
 * SortableJS handles the DOM-level drag mechanics; this script
 * translates the drag-end event into a wire:method call that
 * persists status_id + sort_order through TaskService.
 */
window.tesserabxPmKanban = window.tesserabxPmKanban || (function(){

	function init( wireId ){
		if ( typeof Sortable === "undefined" ) {
			console.warn( "[tesserabx-pm] SortableJS not loaded; kanban drag-drop disabled." );
			return;
		}
		var root = document.querySelector( '[data-pm-wire-id="' + wireId + '"]' );
		if ( !root ) {
			console.warn( "[tesserabx-pm] kanban root not found for wireId " + wireId );
			return;
		}
		// Idempotency: if Sortable instances already exist from a
		// previous render, destroy them before re-initialising. CBWire
		// patches the DOM in place on each render so re-init can run
		// repeatedly on the same elements.
		root.querySelectorAll( '[data-pm-kanban-column]' ).forEach( function( col ){
			if ( col._pmSortable ) {
				col._pmSortable.destroy();
			}
			col._pmSortable = new Sortable( col, {
				group:        "pm-kanban",
				animation:    150,
				ghostClass:   "pm-task-card-ghost",
				chosenClass:  "pm-task-card-chosen",
				dragClass:    "pm-task-card-drag",
				draggable:    "[data-pm-task-id]",
				onAdd:        function( evt ){ tintReceiving( evt.from, false ); tintReceiving( evt.to, false ); },
				onStart:      function( evt ){ tintReceiving( evt.from, true );  },
				onUnchoose:   function( evt ){ tintReceiving( evt.from, false ); },
				onEnd:        function( evt ){
					tintReceiving( evt.from, false );
					tintReceiving( evt.to, false );

					var taskId      = evt.item.getAttribute( "data-pm-task-id" );
					var toColumn    = evt.to.closest( "[data-pm-kanban-column-status]" );
					if ( !toColumn ) return;
					var newStatusId = toColumn.getAttribute( "data-pm-kanban-column-status" );
					var newIndex    = evt.newIndex;

					// Find the wire and call the persist action. The
					// server returns the refreshed board which CBWire
					// patches back into the DOM, including this script
					// re-initialising via the hook (because the wire
					// element re-mounts).
					var wire = Livewire.find( wireId );
					if ( !wire ) {
						console.warn( "[tesserabx-pm] could not find wire " + wireId + " for reorder" );
						return;
					}
					wire.call( "persistReorder", taskId, newStatusId, newIndex );
				}
			} );
		} );
	}

	function tintReceiving( columnBody, on ){
		if ( !columnBody ) return;
		if ( on ) columnBody.classList.add( "pm-column-receiving" );
		else      columnBody.classList.remove( "pm-column-receiving" );
	}

	return { init: init };
})();
