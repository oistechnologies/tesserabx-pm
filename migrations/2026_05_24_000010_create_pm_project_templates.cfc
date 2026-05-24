/**
 * Create pm_project_templates.
 *
 * Snapshots of project structure (statuses, labels, custom fields,
 * tasks with relative date offsets, subtasks) stored as JSON text.
 * organization_id is NULLABLE to support shared global templates
 * gated by the pm.admin permission. Per-tenant templates carry a
 * concrete organization_id and apply TenantScope@contacts.
 *
 * The JSON snapshot lives in `structure_json` as TEXT, not jsonb:
 * the JDBC binder cannot send a typed jsonb value through named
 * parameters reliably; the host's convention is to stash JSON as
 * TEXT and parse application-side.
 */
component {

    function up( schema, qb ){
        schema.create( "pm_project_templates", function( table ){
            table.string( "id", 36 ).primaryKey();
            table.string( "organization_id", 36 ).nullable()
                 .references( "id" ).onTable( "organizations" ).onDelete( "CASCADE" );

            table.string( "name", 200 );
            table.text( "description" ).nullable();
            table.text( "structure_json" );

            table.string( "created_by_type", 16 ).nullable();
            table.string( "created_by_id",   36 ).nullable();

            table.boolean( "is_shared" ).default( false );

            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );

            table.index( "organization_id" );
            table.index( "is_shared" );
        } );
    }

    function down( schema, qb ){
        schema.drop( "pm_project_templates" );
    }

}
