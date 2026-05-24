/**
 * Create pm_task_labels.
 *
 * Many-to-many join between tasks and labels within a project.
 * Both sides cascade on delete (label removal removes the join,
 * task deletion removes the join).
 */
component {

    function up( schema, qb ){
        schema.create( "pm_task_labels", function( table ){
            table.string( "id", 36 ).primaryKey();
            table.string( "task_id", 36 )
                 .references( "id" ).onTable( "pm_tasks" ).onDelete( "CASCADE" );
            table.string( "label_id", 36 )
                 .references( "id" ).onTable( "pm_labels" ).onDelete( "CASCADE" );

            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );

            table.unique( [ "task_id", "label_id" ] );
            table.index( "task_id" );
            table.index( "label_id" );
        } );
    }

    function down( schema, qb ){
        schema.drop( "pm_task_labels" );
    }

}
