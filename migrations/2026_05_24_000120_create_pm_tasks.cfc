/**
 * Create pm_tasks.
 *
 * The kanban-board level entity. Carries full status, custom field
 * values, labels, embeddings, time logs. Tenant-scoped via
 * organization_id (denormalized from project for direct scoping).
 *
 * Polymorphic assignee (agent | contact) per BUILD-PLAN §3.4.
 * Only agent users can assign to a contact (gated by
 * `pm.assign-client` permission at the service layer).
 *
 * `is_client_visible` drives Option C visibility (BUILD-PLAN §3.3):
 * contacts see tasks assigned to themselves, tasks assigned to
 * another contact in their org, or any task with this flag set.
 *
 * Soft delete + pgvector embedding (Phase 12) per BUILD-PLAN.
 */
component {

    function up( schema, qb ){
        schema.create( "pm_tasks", function( table ){
            table.string( "id", 36 ).primaryKey();
            table.string( "project_id", 36 )
                 .references( "id" ).onTable( "pm_projects" ).onDelete( "CASCADE" );
            table.string( "organization_id", 36 )
                 .references( "id" ).onTable( "organizations" ).onDelete( "CASCADE" );
            table.string( "status_id", 36 ).nullable()
                 .references( "id" ).onTable( "pm_project_statuses" ).onDelete( "SET NULL" );

            table.string( "title", 500 );
            table.text( "description" ).nullable();
            table.string( "priority", 16 ).default( "medium" );

            table.string( "assignee_type", 16 ).nullable();
            table.string( "assignee_id",   36 ).nullable();

            table.date( "start_date" ).nullable();
            table.date( "due_date" ).nullable();
            table.decimal( "estimated_hours", 8, 2 ).nullable();

            table.boolean( "is_client_visible" ).default( false );
            table.integer( "sort_order" ).default( 0 );
            table.timestamp( "completed_at" ).nullable();

            table.string( "created_by_type", 16 ).nullable();
            table.string( "created_by_id",   36 ).nullable();

            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "deleted_at" ).nullable();

            table.index( "project_id" );
            table.index( "organization_id" );
            table.index( "status_id" );
            table.index( [ "project_id", "status_id", "sort_order" ] );
            table.index( [ "assignee_type", "assignee_id" ] );
            table.index( "due_date" );
            table.index( "is_client_visible" );
            table.index( "deleted_at" );
        } );

        queryExecute( "ALTER TABLE pm_tasks ADD COLUMN embedding vector(1536)" );
    }

    function down( schema, qb ){
        schema.drop( "pm_tasks" );
    }

}
