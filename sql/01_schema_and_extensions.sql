-- ==============================================================================
-- 01: Enable PostgreSQL AI Extensions & Define Schemas
-- Database: quickstart_db
-- Description: Enables Google ML Integration, pgvector, and ScaNN extensions,
--              then creates tables for the Cymbal Retail dataset.
-- ==============================================================================

-- 1. Enable Vertex AI & Vector Extensions
CREATE EXTENSION IF NOT EXISTS google_ml_integration CASCADE;
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS alloydb_scann;

-- 2. Verify Google ML Extension Version (Should be 1.6+)
SELECT extversion 
FROM pg_extension 
WHERE extname = 'google_ml_integration';

-- 3. Verify Database Flag for Accelerated Embedding Generation
SHOW google_ml_integration.enable_faster_embedding_generation;

-- 4. Cymbal Products Table Schema (Base Table)
CREATE TABLE IF NOT EXISTS cymbal_products (
    uniq_id VARCHAR(32) PRIMARY KEY,
    crawl_timestamp TIMESTAMP WITH TIME ZONE,
    product_url TEXT,
    product_name TEXT,
    product_description TEXT,
    list_price NUMERIC(10, 2),
    sale_price NUMERIC(10, 2),
    brand VARCHAR(100),
    item_number VARCHAR(50),
    gtin VARCHAR(50),
    package_size VARCHAR(50),
    category VARCHAR(100),
    postal_code VARCHAR(20),
    available BOOLEAN
);

-- 5. Cymbal Stores Table Schema
CREATE TABLE IF NOT EXISTS cymbal_stores (
    store_id INTEGER PRIMARY KEY,
    store_name VARCHAR(100),
    street_address TEXT,
    city VARCHAR(100),
    state VARCHAR(50),
    zip_code VARCHAR(20),
    phone VARCHAR(50)
);

-- 6. Cymbal Inventory Table Schema
CREATE TABLE IF NOT EXISTS cymbal_inventory (
    inventory_id SERIAL PRIMARY KEY,
    store_id INTEGER REFERENCES cymbal_stores(store_id),
    uniq_id VARCHAR(32) REFERENCES cymbal_products(uniq_id),
    inventory INTEGER
);
