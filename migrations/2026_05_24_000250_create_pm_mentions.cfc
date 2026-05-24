/**
 * Create pm_mentions.
 *
 * Records @mentions parsed out of comment bodies at save time.
 * Polymorphic mention target (agent | contact) because PM treats
 * both as first-class actors. The MentionService autocomplete
 * disambiguates (@agent:slug vs @contact:slug).
 *
 * `notified_at` is set when the host notifications module has
 * delivered the in-app notification; `read_at` is set when the
 * mentioned user opens the surface where the mention lives.
 */
component {

    function up( schema, qb ){
        schema.create( "pm_mentions", function( table ){
            table.string( "id", 36 ).primaryKey();
            table.string( "comment_id", 36 )
                 .references( "id" ).onTable( "pm_comments" ).onDelete( "CASCADE" );
            table.string( "organization_id", 36 )
                 .references( "id" ).onTable( "organizations" ).onDelete( "CASCADE" );

            table.string( "mentioned_user_type", 16 );
            table.string( "mentioned_user_id",   36 );

            table.timestamp( "notified_at" ).nullable();
            table.timestamp( "read_at" ).nullable();

            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );

            table.index( "comment_id" );
            table.index( "organization_id" );
            table.index( [ "mentioned_user_type", "mentioned_user_id" ] );
            table.index( "read_at" );
        } );
    }

    function down( schema, qb ){
        schema.drop( "pm_mentions" );
    }

}
