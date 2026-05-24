/**
 * Create pm_custom_fields.
 *
 * Per-project custom field definitions. PM keeps its own custom
 * fields distinct from the host's per-tenant CustomFieldsService
 * because PM users need fields scoped to a specific project
 * (BUILD-PLAN §3.16).
 *
 * `field_type` is one of: text, number, date, dropdown, multiselect,
 * checkbox, url. `options_json` carries the choice set for
 * dropdown/multiselect; TEXT not jsonb per host convention.
 * `applies_to` is one of: task, subtask, both.
 */
component {

    function up( schema, qb ){
        schema.create( "pm_custom_fields", function( table ){
            table.string( "id", 36 ).primaryKey();
            table.string( "project_id", 36 )
                 .references( "id" ).onTable( "pm_projects" ).onDelete( "CASCADE" );
            table.string( "organization_id", 36 )
                 .references( "id" ).onTable( "organizations" ).onDelete( "CASCADE" );

            table.string( "name", 100 );
            table.string( "field_type", 32 );
            table.text( "options_json" ).nullable();

            table.boolean( "is_required" ).default( false );
            table.string( "applies_to", 16 ).default( "both" );
            table.integer( "sort_order" ).default( 0 );

            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );

            table.index( "project_id" );
            table.index( "organization_id" );
            table.unique( [ "project_id", "name" ] );
        } );
    }

    function down( schema, qb ){
        schema.drop( "pm_custom_fields" );
    }

}
