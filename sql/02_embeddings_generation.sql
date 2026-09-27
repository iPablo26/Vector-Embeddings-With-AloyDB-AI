-- ==============================================================================
-- 02: Generate & Manage Vector Embeddings with AlloyDB AI
-- Model: text-embedding-005 (768 dimensions)
-- Description: Demonstrates batch embedding initialization and real-time
--              transactional embedding calculation.
-- ==============================================================================

-- 1. Add vector column for precomputed embeddings (768 dimensions)
ALTER TABLE cymbal_products ADD COLUMN IF NOT EXISTS embedding vector(768);

-- 2. Batch generate embeddings for existing catalog descriptions (Batch size: 50)
-- Timing can be monitored via '\timing' in psql
CALL ai.initialize_embeddings(
    model_id => 'text-embedding-005',
    table_name => 'cymbal_products',
    content_column => 'product_description',
    embedding_column => 'embedding',
    batch_size => 50
);

-- 3. Set up an Auto-Updating Vector Column with Transactional Refresh
-- Ensures new/updated rows automatically receive fresh vector embeddings
ALTER TABLE cymbal_products ADD COLUMN IF NOT EXISTS product_embedding vector(768);

CALL ai.initialize_embeddings(
    model_id => 'text-embedding-005',
    table_name => 'cymbal_products',
    content_column => 'product_description',
    embedding_column => 'product_embedding',
    batch_size => 50,
    incremental_refresh_mode => 'transactional'
);

-- 4. Test Transactional Vector Generation with New Insert
INSERT INTO cymbal_products (
    uniq_id, crawl_timestamp, product_url, product_name, product_description,
    list_price, sale_price, brand, item_number, gtin, package_size,
    category, postal_code, available, product_embedding, embedding
) VALUES (
    'fd604542e04b470f9e6348e640cff794',
    NOW(),
    'https://example.com/new_product',
    'New Cymbal Product',
    'This is a new cymbal product description for gardening trees.',
    199.99,
    149.99,
    'Example Brand',
    'EB123',
    '1234567890',
    'Single',
    'Garden',
    '12345',
    TRUE,
    NULL,
    NULL
);

-- 5. Validate that product_embedding was automatically generated
SELECT 
    uniq_id, 
    embedding, 
    (product_embedding::real[])[1:5] AS product_embedding_sample
FROM cymbal_products 
WHERE uniq_id = 'fd604542e04b470f9e6348e640cff794';
