/**
 * Add a pgvector embedding column to pm_tasks for Phase 12a
 * semantic similarity ("Related tasks" panel + find-similar on
 * task create).
 *
 * Dimension is fixed at 1536 to match the host's default OpenAI
 * text-embedding-3-small model and the kb_articles.embedding
 * column. Changing AI_EMBEDDING_MODEL to a model with a different
 * dimension requires altering this column too.
 *
 * HNSW index with vector_cosine_ops mirrors the KB pattern; ANALYZE
 * after backfilling embeddings to refresh planner stats. pgvector
 * is already enabled application-wide by the host's
 * baseline_extensions migration.
 */
component {

    function up( schema, qb ){
        queryExecute( "ALTER TABLE pm_tasks ADD COLUMN embedding vector(1536)" );
        queryExecute( "CREATE INDEX idx_pm_tasks_embedding_hnsw ON pm_tasks USING hnsw ( embedding vector_cosine_ops )" );
    }

    function down( schema, qb ){
        queryExecute( "DROP INDEX IF EXISTS idx_pm_tasks_embedding_hnsw" );
        queryExecute( "ALTER TABLE pm_tasks DROP COLUMN IF EXISTS embedding" );
    }

}
