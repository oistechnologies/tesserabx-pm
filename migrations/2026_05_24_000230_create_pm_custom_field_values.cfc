/**
 * Create pm_custom_field_values.
 *
 * Polymorphic over Task and Subtask. A row stores the value of
 * one custom field for one task or subtask, normalized to TEXT
 * regardless of the field type (dates as ISO strings, numbers as
 * stringified decimals, multiselect as JSON-encoded array). The
 * field definition's `field_type` drives parsing on read.
 *
 * Unique by (custom_field_id, valuable_type, valuable_id) so an
 * INSERT-or-UPDATE-on-conflict pattern works at the service layer.
 */
component {

    function up( schema, qb ){
        schema.create( "pm_custom_field_values", function( table ){
            table.string( "id", 36 ).primaryKey();
            table.string( "custom_field_id", 36 )
                 .references( "id" ).onTable( "pm_custom_fields" ).onDelete( "CASCADE" );
            table.string( "organization_id", 36 )
                 .references( "id" ).onTable( "organizations" ).onDelete( "CASCADE" );

            table.string( "valuable_type", 16 );
            table.string( "valuable_id",   36 );

            table.text( "value" ).nullable();

            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );

            table.unique( [ "custom_field_id", "valuable_type", "valuable_id" ] );
            table.index( "custom_field_id" );
            table.index( "organization_id" );
            table.index( [ "valuable_type", "valuable_id" ] );
        } );
    }

    function down( schema, qb ){
        schema.drop( "pm_custom_field_values" );
    }

}
