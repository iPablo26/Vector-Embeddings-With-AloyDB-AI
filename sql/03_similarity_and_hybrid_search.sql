-- ==============================================================================
-- 03: Semantic & Hybrid Search Queries
-- Description: Executes vector similarity search using Cosine Distance (<=>)
--              and blends semantic retrieval with relational business logic.
-- ==============================================================================

-- 1. Semantic Similarity Search with In-Store Inventory & Zip Code Filtering
-- Query: "What kind of fruit trees grow well here?"
-- Filter: store_id = 1583 (Kings County, CA - Zip 93230) and available stock
SELECT
    cp.product_name,
    LEFT(cp.product_description, 80) AS description,
    cp.sale_price,
    cs.zip_code,
    (cp.embedding <=> embedding('text-embedding-005', 'What kind of fruit trees grow well here?')::vector) AS distance
FROM
    cymbal_products cp
JOIN cymbal_inventory ci ON
    ci.uniq_id = cp.uniq_id
JOIN cymbal_stores cs ON
    cs.store_id = ci.store_id
    AND ci.inventory > 0
    AND cs.store_id = 1583
ORDER BY
    distance ASC
LIMIT 10;

-- 2. Hybrid Search: Filter by Price Ceiling & Category along with Semantic Relevance
SELECT
    cp.product_name,
    cp.sale_price,
    cp.category,
    (cp.embedding <=> embedding('text-embedding-005', 'Fruit trees for home backyard gardening')::vector) AS distance
FROM
    cymbal_products cp
WHERE
    cp.sale_price <= 100.00
    AND cp.available = TRUE
ORDER BY
    distance ASC
LIMIT 5;

-- 3. Top-Match Extraction Aggregated as JSON (Preparation for LLM Prompting)
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
