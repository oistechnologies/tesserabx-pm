/**
 * Create pm_saved_filters.
 *
 * Phase 10b per-user named filter sets. Polymorphic owner via the
 * (user_type, user_id) pair so both account families can save
 * filters. `view` is one of: "board" | "list" | "calendar" |
 * "my-tasks". `project_id` is nullable: cross-project views
 * (my-tasks) save filters with NULL project_id; per-project views
 * carry the concrete id so the same name can repeat across
 * different projects.
 *
 * `filters_json` carries the wire's data struct as TEXT (the same
 * TEXT-not-jsonb convention every other PM JSON column uses).
 *
 * `is_default` flips one filter per (user, view, project) tuple
 * into the "auto-applied on mount" slot. The service enforces the
 * one-default invariant on writes.
 */
component {

    function up( schema, qb ){
        schema.create( "pm_saved_filters", function( table ){
            table.string( "id",         36 ).primaryKey();
            table.string( "user_type",  16 );
            table.string( "user_id",    36 );
            table.string( "view",       32 );
            table.string( "project_id", 36 ).nullable()
                 .references( "id" ).onTable( "pm_projects" ).onDelete( "CASCADE" );
            table.string( "name",      100 );
            table.text(   "filters_json" );
            table.boolean( "is_default" ).default( false );

            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );

            table.index( [ "user_type", "user_id" ] );
            table.index( [ "user_type", "user_id", "view" ] );
            table.index( "project_id" );
        } );
    }

    function down( schema, qb ){
        schema.drop( "pm_saved_filters" );
    }

}
