/**
 * Create pm_subtasks.
 *
 * Lightweight child of Task per BUILD-PLAN §3.1: binary
 * completion, polymorphic assignee, optional estimated hours, but
 * no status set, no custom fields, no embeddings. Time logs attach
 * polymorphically (Task or Subtask). Subtask hours roll up to the
 * parent task in reporting (Phase 5).
 *
 * organization_id is denormalized from the parent task for direct
 * tenant scoping. Soft delete per BUILD-PLAN §3.13.
 */
component {

    function up( schema, qb ){
        schema.create( "pm_subtasks", function( table ){
            table.string( "id", 36 ).primaryKey();
            table.string( "task_id", 36 )
                 .references( "id" ).onTable( "pm_tasks" ).onDelete( "CASCADE" );
            table.string( "organization_id", 36 )
                 .references( "id" ).onTable( "organizations" ).onDelete( "CASCADE" );

            table.string( "title", 500 );
            table.text( "description" ).nullable();

            table.string( "assignee_type", 16 ).nullable();
            table.string( "assignee_id",   36 ).nullable();

            table.date( "due_date" ).nullable();
            table.decimal( "estimated_hours", 8, 2 ).nullable();

            table.boolean( "is_completed" ).default( false );
            table.timestamp( "completed_at" ).nullable();
            table.integer( "sort_order" ).default( 0 );

            table.string( "created_by_type", 16 ).nullable();
            table.string( "created_by_id",   36 ).nullable();

            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "deleted_at" ).nullable();

            table.index( "task_id" );
            table.index( "organization_id" );
            table.index( [ "task_id", "sort_order" ] );
            table.index( [ "assignee_type", "assignee_id" ] );
            table.index( "is_completed" );
            table.index( "deleted_at" );
        } );
    }

    function down( schema, qb ){
        schema.drop( "pm_subtasks" );
    }

}
