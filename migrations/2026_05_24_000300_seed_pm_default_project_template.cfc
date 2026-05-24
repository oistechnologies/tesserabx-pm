/**
 * Seed the shared "Standard Workflow" ProjectTemplate.
 *
 * Per BUILD-PLAN §9 Phase 1, PM ships with a default template
 * carrying the 5 canonical statuses (Backlog, To Do, In Progress,
 * In Review, Done). organization_id IS NULL marks it shared
 * across all tenants; the pm.admin permission gates the
 * settings.tesserabx-pm.default-template-id setting that points
 * to it.
 *
 * ProjectService (Phase 2) consults this template when creating a
 * project without an explicit template selection.
 *
 * The seed is idempotent: skips insert when a row with this slug
 * already exists. Down removes only the row this migration
 * inserted.
 */
component {

    variables.SEED_ID = "00000000-0000-0000-0000-00000000pm01";

    function up( schema, qb ){
        var existing = queryExecute(
            "SELECT id FROM pm_project_templates WHERE id = :id",
            { id : variables.SEED_ID }
        );
        if ( existing.recordCount ) return;

        // Hash chars in CFML string literals are interpolation
        // delimiters; double them to embed a literal `#`. After CFML
        // parsing the in-memory struct holds `#6c757d` etc., and
        // serializeJSON writes the canonical CSS hex form into the
        // JSON column.
        var structure = {
            "statuses" : [
                { "name" : "Backlog",     "color" : "##6c757d", "sort_order" : 0, "is_default" : true,  "is_completed" : false },
                { "name" : "To Do",       "color" : "##0d6efd", "sort_order" : 1, "is_default" : false, "is_completed" : false },
                { "name" : "In Progress", "color" : "##ffc107", "sort_order" : 2, "is_default" : false, "is_completed" : false },
                { "name" : "In Review",   "color" : "##6610f2", "sort_order" : 3, "is_default" : false, "is_completed" : false },
                { "name" : "Done",        "color" : "##198754", "sort_order" : 4, "is_default" : false, "is_completed" : true  }
            ],
            "labels"        : [],
            "custom_fields" : [],
            "tasks"         : []
        };

        queryExecute(
            "INSERT INTO pm_project_templates
                ( id, organization_id, name, description, structure_json,
                  created_by_type, created_by_id, is_shared,
                  created_at, updated_at )
             VALUES
                ( :id, NULL, :name, :description, :structure,
                  'system', NULL, TRUE,
                  CURRENT_TIMESTAMP, CURRENT_TIMESTAMP )",
            {
                id          : variables.SEED_ID,
                name        : "Standard Workflow",
                description : "Default five-column kanban workflow shipped with tesserabx-pm: Backlog, To Do, In Progress, In Review, Done.",
                structure   : serializeJSON( structure )
            }
        );
    }

    function down( schema, qb ){
        queryExecute(
            "DELETE FROM pm_project_templates WHERE id = :id",
            { id : variables.SEED_ID }
        );
    }

}
