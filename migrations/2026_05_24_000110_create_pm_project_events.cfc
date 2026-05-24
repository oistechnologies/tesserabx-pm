/**
 * Create pm_project_events.
 *
 * PM's domain timeline, parallel to the host tickets module's
 * TicketEvent. Captures granular activity (status changes, comment
 * edits, label toggles, etc.) and renders the activity feed on
 * project detail. Cross-cutting compliance events also flow to the
 * host `audit` module's AuditService via the manifest's
 * auditEvents list, but those are coarser.
 *
 * Polymorphic subject (project | task | subtask | comment) and
 * polymorphic actor (agent | contact | system). No FK on either
 * pair per BUILD-PLAN §3.4.
 */
component {

    function up( schema, qb ){
        schema.create( "pm_project_events", function( table ){
            table.string( "id", 36 ).primaryKey();
            table.string( "project_id", 36 )
                 .references( "id" ).onTable( "pm_projects" ).onDelete( "CASCADE" );
            table.string( "organization_id", 36 )
                 .references( "id" ).onTable( "organizations" ).onDelete( "CASCADE" );

            table.string( "subject_type", 16 );
            table.string( "subject_id",   36 );

            table.string( "actor_type", 16 );
            table.string( "actor_id",   36 ).nullable();

            table.string( "action", 64 );
            table.text( "changes_json" ).nullable();

            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );

            table.index( "project_id" );
            table.index( "organization_id" );
            table.index( [ "subject_type", "subject_id" ] );
            table.index( "created_at" );
        } );
    }

    function down( schema, qb ){
        schema.drop( "pm_project_events" );
    }

}
