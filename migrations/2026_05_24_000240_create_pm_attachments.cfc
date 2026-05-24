/**
 * Create pm_attachments.
 *
 * Polymorphic over Task, Subtask, and Comment. File contents live
 * on the host's CBFS provider (configurable: local disk, S3, B2);
 * this row records the CBFS-relative key plus metadata.
 *
 * Distinct from the host's own `attachments` table because PM
 * attachments belong to PM entities. The host's table is for
 * ticket and message attachments.
 */
component {

    function up( schema, qb ){
        schema.create( "pm_attachments", function( table ){
            table.string( "id", 36 ).primaryKey();
            table.string( "organization_id", 36 )
                 .references( "id" ).onTable( "organizations" ).onDelete( "CASCADE" );

            table.string( "attachable_type", 16 );
            table.string( "attachable_id",   36 );

            table.string( "file_path", 500 );
            table.string( "file_name", 255 );
            table.integer( "file_size" ).default( 0 );
            table.string( "mime_type", 128 ).nullable();

            table.string( "uploaded_by_type", 16 ).nullable();
            table.string( "uploaded_by_id",   36 ).nullable();

            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );

            table.index( "organization_id" );
            table.index( [ "attachable_type", "attachable_id" ] );
        } );
    }

    function down( schema, qb ){
        schema.drop( "pm_attachments" );
    }

}
