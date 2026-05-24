/**
 * Create pm_time_logs.
 *
 * Polymorphic over Task and Subtask. Per BUILD-PLAN §3.7, time
 * tracking is per-project-opt-in; controlled by
 * pm_projects.time_tracking_enabled. Subtask hours roll up to the
 * parent task; task hours roll up to the project (Phase 5
 * reporting).
 *
 * Either an agent or a contact may log time. `is_billable` is a
 * per-row flag the reports surface filters on.
 *
 * Soft delete per BUILD-PLAN §3.13.
 */
component {

    function up( schema, qb ){
        schema.create( "pm_time_logs", function( table ){
            table.string( "id", 36 ).primaryKey();
            table.string( "organization_id", 36 )
                 .references( "id" ).onTable( "organizations" ).onDelete( "CASCADE" );

            table.string( "loggable_type", 16 );
            table.string( "loggable_id",   36 );

            table.string( "user_type", 16 );
            table.string( "user_id",   36 );

            table.decimal( "hours", 8, 2 );
            table.timestamp( "logged_at" );
            table.text( "description" ).nullable();
            table.boolean( "is_billable" ).default( false );

            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "deleted_at" ).nullable();

            table.index( "organization_id" );
            table.index( [ "loggable_type", "loggable_id" ] );
            table.index( [ "user_type", "user_id" ] );
            table.index( "logged_at" );
            table.index( "is_billable" );
            table.index( "deleted_at" );
        } );
    }

    function down( schema, qb ){
        schema.drop( "pm_time_logs" );
    }

}
