/**
 * Create pm_task_tickets.
 *
 * Bidirectional join between PM tasks and host tickets. PM owns
 * this table because the link is PM's concern; the host `tickets`
 * module is unaware of PM. The ticket-side panel rendered by PM
 * via the `ticketPanels` manifest entry (Phase 8) reads this table
 * through PM's TaskTicketService.
 *
 * `link_type` is one of: related, blocks, fixes.
 *
 * organization_id is nullable per BUILD-PLAN §7.6: a ticket may be
 * accountless (no organization), in which case the link row is
 * accountless too. The ticket FK is CASCADE so deleting a ticket
 * removes its link rows; the task survives.
 */
component {

    function up( schema, qb ){
        schema.create( "pm_task_tickets", function( table ){
            table.string( "id", 36 ).primaryKey();
            table.string( "task_id", 36 )
                 .references( "id" ).onTable( "pm_tasks" ).onDelete( "CASCADE" );
            table.string( "ticket_id", 36 )
                 .references( "id" ).onTable( "tickets" ).onDelete( "CASCADE" );
            table.string( "organization_id", 36 ).nullable()
                 .references( "id" ).onTable( "organizations" ).onDelete( "CASCADE" );

            table.string( "link_type", 32 ).default( "related" );

            table.string( "linked_by_type", 16 ).nullable();
            table.string( "linked_by_id",   36 ).nullable();
            table.timestamp( "linked_at" ).default( "CURRENT_TIMESTAMP" );

            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );

            table.unique( [ "task_id", "ticket_id" ] );
            table.index( "task_id" );
            table.index( "ticket_id" );
            table.index( "organization_id" );
        } );
    }

    function down( schema, qb ){
        schema.drop( "pm_task_tickets" );
    }

}
