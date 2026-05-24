/**
 * Create pm_comments.
 *
 * Polymorphic across Project, Task, Subtask. Threaded via the
 * nullable `parent_comment_id` self-reference.
 *
 * `is_internal` drives BUILD-PLAN §3.5 visibility: agent comments
 * default to internal; contact comments are forced external; the
 * portal surface never renders internal comments.
 *
 * Polymorphic actor (agent | contact). No FK on the
 * (commentable_type, commentable_id) pair per BUILD-PLAN §3.4;
 * the service layer validates the reference exists.
 *
 * Soft delete per BUILD-PLAN §3.13.
 */
component {

    function up( schema, qb ){
        schema.create( "pm_comments", function( table ){
            table.string( "id", 36 ).primaryKey();
            table.string( "organization_id", 36 )
                 .references( "id" ).onTable( "organizations" ).onDelete( "CASCADE" );

            table.string( "commentable_type", 16 );
            table.string( "commentable_id",   36 );

            table.string( "parent_comment_id", 36 ).nullable()
                 .references( "id" ).onTable( "pm_comments" ).onDelete( "CASCADE" );

            table.string( "author_type", 16 );
            table.string( "author_id",   36 );

            table.text( "body" );
            table.boolean( "is_internal" ).default( false );

            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "deleted_at" ).nullable();

            table.index( "organization_id" );
            table.index( [ "commentable_type", "commentable_id" ] );
            table.index( "parent_comment_id" );
            table.index( "is_internal" );
            table.index( "created_at" );
            table.index( "deleted_at" );
        } );
    }

    function down( schema, qb ){
        schema.drop( "pm_comments" );
    }

}
