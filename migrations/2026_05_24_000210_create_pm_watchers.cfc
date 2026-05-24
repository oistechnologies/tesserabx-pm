/**
 * Create pm_watchers.
 *
 * Polymorphic watcher attached to Project, Task, or Subtask.
 * Auto-added flag distinguishes implicit watches (set by the
 * WatcherService on assignment or on comment) from explicit ones
 * (clicked "watch" on the UI).
 *
 * Polymorphic on both sides: watchable (Project|Task|Subtask) AND
 * watcher (agent|contact). No FKs on either pair per BUILD-PLAN
 * §3.4. Unique by the full quadruple to prevent duplicate watches.
 */
component {

    function up( schema, qb ){
        schema.create( "pm_watchers", function( table ){
            table.string( "id", 36 ).primaryKey();
            table.string( "organization_id", 36 )
                 .references( "id" ).onTable( "organizations" ).onDelete( "CASCADE" );

            table.string( "watchable_type", 16 );
            table.string( "watchable_id",   36 );

            table.string( "watcher_type", 16 );
            table.string( "watcher_id",   36 );

            table.boolean( "auto_added" ).default( false );

            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );

            table.unique( [ "watchable_type", "watchable_id", "watcher_type", "watcher_id" ] );
            table.index( "organization_id" );
            table.index( [ "watchable_type", "watchable_id" ] );
            table.index( [ "watcher_type", "watcher_id" ] );
        } );
    }

    function down( schema, qb ){
        schema.drop( "pm_watchers" );
    }

}
