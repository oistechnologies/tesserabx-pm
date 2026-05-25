/**
 * Add the HNSW index on pm_tasks.embedding for Phase 12a semantic
 * similarity ("Related tasks" panel + find-similar on task create).
 *
 * The pm_tasks.embedding column was already created by the
 * 2026_05_24_000120_create_pm_tasks migration (Phase 2) which
 * forecasted Phase 12. This migration is index-only: dim 1536
 * matches the column and the host's default OpenAI text-embedding-
 * 3-small model. HNSW with vector_cosine_ops mirrors the KB pattern;
 * ANALYZE after a bulk backfill refreshes planner stats. pgvector is
 * already enabled application-wide by the host's baseline_extensions
 * migration.
 *
 * Filename keeps the original "add_embedding_to_pm_tasks" slug for
 * continuity with anyone who pulled this migration before the index-
 * only fix landed, but the body is index-only.
 */
component {

    function up( schema, qb ){
        queryExecute( "CREATE INDEX IF NOT EXISTS idx_pm_tasks_embedding_hnsw ON pm_tasks USING hnsw ( embedding vector_cosine_ops )" );
    }

    function down( schema, qb ){
        queryExecute( "DROP INDEX IF EXISTS idx_pm_tasks_embedding_hnsw" );
    }

}
