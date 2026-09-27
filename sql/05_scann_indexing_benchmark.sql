-- ==============================================================================
-- 05: Google ScaNN Vector Indexing & Query Plan Optimization
-- Description: Creates an Approximate Nearest Neighbors (ANN) vector index
--              using Google ScaNN algorithm and evaluates execution plans.
-- ==============================================================================

-- 1. Create ScaNN Vector Index on Products Embedding Column
-- Algorithm: Google ScaNN (Scalable Nearest Neighbors)
-- Distance Metric: Cosine
-- Parameters:
--   num_leaves: Number of partitions for the tree
--   max_num_levels: Tree quantization levels
CREATE INDEX IF NOT EXISTS cymbal_products_embeddings_scann 
ON cymbal_products
USING scann (embedding cosine)
WITH (num_leaves = 10, max_num_levels = 1);

-- 2. Performance Verification with EXPLAIN (ANALYZE)
-- Confirms that the PostgreSQL query planner utilizes the ScaNN index scan
-- rather than an unindexed sequential table scan
EXPLAIN (ANALYZE, BUFFERS)
WITH trees AS (
    SELECT
        cp.product_name,
        LEFT(cp.product_description, 80) AS description,
        cp.sale_price,
        cs.zip_code,
        cp.uniq_id AS product_id
    FROM
        cymbal_products cp
    JOIN cymbal_inventory ci ON
        ci.uniq_id = cp.uniq_id
    JOIN cymbal_stores cs ON
        cs.store_id = ci.store_id
        AND ci.inventory > 0
        AND cs.store_id = 1583
    ORDER BY
        (cp.embedding <=> embedding('text-embedding-005', 'What kind of fruit trees grow well here?')::vector) ASC
    LIMIT 1
)
SELECT json_agg(trees) FROM trees;

-- Expected Output Pattern:
-- -> Index Scan using cymbal_products_embeddings_scann on cymbal_products cp
--    (cost=... rows=... actual time=0.906..0.908 rows=2 loops=1)
--    Order By: (embedding <=> '[...]')
