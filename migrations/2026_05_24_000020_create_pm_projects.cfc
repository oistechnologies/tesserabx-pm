/**
 * Create pm_projects.
 *
 * The top of the Project > Task > Subtask hierarchy. Always tenant
 * scoped: organization_id is required and CASCADE on delete tracks
 * the organization out of existence.
 *
 * Soft delete: `deleted_at` per BUILD-PLAN §3.13.
 * Embedding: pgvector column added after schema.create via raw SQL
 * (cfmigrations has no DSL for the vector type). Populated by the
 * Phase 12 embedding consumer; safe to leave NULL until then.
 */
component {

    function up( schema, qb ){
        schema.create( "pm_projects", function( table ){
            table.string( "id", 36 ).primaryKey();
            table.string( "organization_id", 36 )
                 .references( "id" ).onTable( "organizations" ).onDelete( "CASCADE" );

            table.string( "name", 255 );
            table.text( "description" ).nullable();

            table.string( "visibility_scope", 32 ).default( "all_org_members" );
            table.string( "lifecycle_status", 32 ).default( "active" );

            table.date( "start_date" ).nullable();
            table.date( "end_date" ).nullable();

            table.boolean( "time_tracking_enabled" ).default( false );
            table.boolean( "is_template" ).default( false );

            table.string( "template_source_id", 36 ).nullable()
                 .references( "id" ).onTable( "pm_project_templates" ).onDelete( "SET NULL" );

            table.string( "created_by_type", 16 ).nullable();
            table.string( "created_by_id",   36 ).nullable();
            table.string( "updated_by_type", 16 ).nullable();
            table.string( "updated_by_id",   36 ).nullable();

            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "deleted_at" ).nullable();

            table.index( "organization_id" );
            table.index( "lifecycle_status" );
            table.index( "template_source_id" );
            table.index( "deleted_at" );
        } );

        queryExecute( "ALTER TABLE pm_projects ADD COLUMN embedding vector(1536)" );
    }

    function down( schema, qb ){
        schema.drop( "pm_projects" );
    }

}
