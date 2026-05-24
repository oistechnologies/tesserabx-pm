/**
 * Create pm_project_members.
 *
 * Explicit project membership when Project.visibility_scope is
 * 'specific_members'. Polymorphic: a member is either an `agent`
 * or a `contact`; no FK on member_id (BUILD-PLAN §3.4: polymorphic
 * actor integrity is enforced at the service layer).
 *
 * `role` is one of: owner, manager, contributor, viewer. Distinct
 * from the TesseraBX-wide RBAC roles; these are project-local.
 */
component {

    function up( schema, qb ){
        schema.create( "pm_project_members", function( table ){
            table.string( "id", 36 ).primaryKey();
            table.string( "project_id", 36 )
                 .references( "id" ).onTable( "pm_projects" ).onDelete( "CASCADE" );
            table.string( "organization_id", 36 )
                 .references( "id" ).onTable( "organizations" ).onDelete( "CASCADE" );

            table.string( "member_type", 16 );
            table.string( "member_id",   36 );

            table.string( "role", 32 ).default( "contributor" );

            table.string( "added_by_type", 16 ).nullable();
            table.string( "added_by_id",   36 ).nullable();
            table.timestamp( "added_at" ).default( "CURRENT_TIMESTAMP" );

            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );

            table.index( "project_id" );
            table.index( "organization_id" );
            table.index( [ "member_type", "member_id" ] );
            table.unique( [ "project_id", "member_type", "member_id" ] );
        } );
    }

    function down( schema, qb ){
        schema.drop( "pm_project_members" );
    }

}
