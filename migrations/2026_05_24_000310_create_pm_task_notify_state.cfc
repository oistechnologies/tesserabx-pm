/**
 * Create pm_task_notify_state.
 *
 * Phase 9b dedup table for the scheduled scanners. One row per
 * task; columns track when the scanner last fired the due-soon and
 * overdue notifications so the next run knows not to re-notify.
 *
 * Uses a synthetic `id` primary key plus a UNIQUE on `task_id`
 * because the qb migration builder's `.primaryKey()` on a non-`id`
 * column generates a constraint that still references `id`. The
 * application layer treats `task_id` as the row identity via the
 * INSERT ... ON CONFLICT ( task_id ) upsert in PmTaskDueScanService.
 *
 * Bumping a task's due date does NOT auto-clear these columns; an
 * operator who wants the notification to re-fire calls
 * PmTaskDueScanService.resetState( taskId ) or DELETEs the row.
 */
component {

    function up( schema, qb ){
        schema.create( "pm_task_notify_state", function( table ){
            table.string( "id",      36 ).primaryKey();
            table.string( "task_id", 36 )
                 .unique()
                 .references( "id" ).onTable( "pm_tasks" ).onDelete( "CASCADE" );
            table.timestamp( "due_soon_at" ).nullable();
            table.timestamp( "overdue_at"  ).nullable();
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );

            table.index( "due_soon_at" );
            table.index( "overdue_at"  );
        } );
    }

    function down( schema, qb ){
        schema.drop( "pm_task_notify_state" );
    }

}
