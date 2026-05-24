/**
 * Create pm_project_statuses.
 *
 * Per-project kanban columns. PM uses per-project custom statuses;
 * the Standard Workflow seed creates the default 5-status set
 * (Backlog, To Do, In Progress, In Review, Done) on every new
 * project unless a template specifies otherwise.
 *
 * `is_completed` marks a terminal status, which the Phase 8
 * close-on-complete listener uses to detect "task finished" and
 * prompt to close any linked tickets.
 */
component {

    function up( schema, qb ){
        schema.create( "pm_project_statuses", function( table ){
            table.string( "id", 36 ).primaryKey();
            table.string( "project_id", 36 )
                 .references( "id" ).onTable( "pm_projects" ).onDelete( "CASCADE" );
            table.string( "organization_id", 36 )
                 .references( "id" ).onTable( "organizations" ).onDelete( "CASCADE" );

            table.string( "name", 100 );
            table.string( "color", 32 ).nullable();
            table.integer( "sort_order" ).default( 0 );

            table.boolean( "is_default" ).default( false );
            table.boolean( "is_completed" ).default( false );

            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );

            table.index( "project_id" );
            table.index( "organization_id" );
            table.index( [ "project_id", "sort_order" ] );
        } );
    }

    function down( schema, qb ){
        schema.drop( "pm_project_statuses" );
    }

}
