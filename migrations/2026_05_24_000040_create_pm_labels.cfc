/**
 * Create pm_labels.
 *
 * Per-project labels (tags) applied to tasks via pm_task_labels.
 * Scoped to the parent project; deleting a project cascades labels
 * out.
 */
component {

    function up( schema, qb ){
        schema.create( "pm_labels", function( table ){
            table.string( "id", 36 ).primaryKey();
            table.string( "project_id", 36 )
                 .references( "id" ).onTable( "pm_projects" ).onDelete( "CASCADE" );
            table.string( "organization_id", 36 )
                 .references( "id" ).onTable( "organizations" ).onDelete( "CASCADE" );

            table.string( "name", 100 );
            table.string( "color", 32 ).nullable();
            table.integer( "sort_order" ).default( 0 );

            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );

            table.index( "project_id" );
            table.index( "organization_id" );
            table.unique( [ "project_id", "name" ] );
        } );
    }

    function down( schema, qb ){
        schema.drop( "pm_labels" );
    }

}
