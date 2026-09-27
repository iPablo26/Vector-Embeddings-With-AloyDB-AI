-- ==============================================================================
-- 04: In-Database RAG with Vertex AI (Gemini Foundation Model)
-- Description: Registers the Gemini model in AlloyDB via google_ml and
--              performs end-to-end Retrieval Augmented Generation (RAG)
--              directly inside a single SQL transaction.
-- ==============================================================================

-- 1. Register Gemini 3.5 Flash Model Endpoint in PostgreSQL
-- Replace 'PROJECT_ID' with your active GCP project ID
CALL google_ml.create_model(
    model_id => 'gemini-3.5-flash',
    model_request_url => 'https://aiplatform.googleapis.com/v1/projects/build-with-ai-488112/locations/global/publishers/google/models/gemini-3.5-flash:generateContent',
    model_provider => 'google',
    model_type => 'llm'
);

-- 2. Inspect Registered Machine Learning Models
SELECT model_id, model_type, model_provider 
FROM google_ml.model_info_view;

-- 3. In-Database End-to-End RAG Query:
-- CTE 1 (trees): Vector retrieval of top semantic match with store inventory check
-- CTE 2 (prompt): Dynamic prompt assembly embedding JSON-serialized retrieved product
-- CTE 3 (response): Direct in-engine LLM inference calling Gemini via google_ml.predict_row
-- Output: Human-like, grounded sales advisory response rendered in SQL
WITH trees AS (
    SELECT
        cp.product_name,
        cp.product_description AS description,
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
),
prompt AS (
    SELECT
        'You are a friendly advisor helping to find a product based on the customer''s needs. ' ||
        'Based on the client request we have loaded a list of products closely related to search. ' ||
        'The list in JSON format with list of values like {"product_name":"name","product_description":"some description","sale_price":10}. ' ||
        'Here is the list of products: ' || json_agg(trees) || ' ' ||
        'The customer asked: "What kind of fruit trees grow well here?" ' ||
        'You should give information about the product, price, and supplemental planting advice for this climate.' AS prompt_text
    FROM
        trees
),
response AS (
    SELECT
        google_ml.predict_row(
            model_id => 'gemini-3.5-flash',
            request_body => json_build_object(
                'contents', json_build_object(
                    'role', 'user',
                    'parts', json_build_object('text', prompt_text)
                )
            )
        )->'candidates'->0->'content'->'parts'->0->'text' AS resp
    FROM
        prompt
)
SELECT REPLACE(resp::text, '\n', CHR(10)) AS advisory_response
FROM response;
