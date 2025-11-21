-- =====================================================================
-- E-Commerce Database Schema Setup
-- =====================================================================
-- Description: Creates schema, tables, and relationships for Brazilian 
--              e-commerce data (Olist dataset)
-- Author: Rohit Bollam
-- Database: PostgreSQL
-- Note: This schema matches the exact structure from ETL pipeline
-- =====================================================================

-- Create schema if not exists
CREATE SCHEMA IF NOT EXISTS etl;

-- Set search path to etl schema
SET search_path TO etl;

-- =====================================================================
-- DROP EXISTING TABLES (in correct order due to dependencies)
-- =====================================================================

DROP TABLE IF EXISTS etl.reviews CASCADE;
DROP TABLE IF EXISTS etl.payments CASCADE;
DROP TABLE IF EXISTS etl.order_items CASCADE;
DROP TABLE IF EXISTS etl.orders CASCADE;
DROP TABLE IF EXISTS etl.products CASCADE;
DROP TABLE IF EXISTS etl.product_categories CASCADE;
DROP TABLE IF EXISTS etl.sellers CASCADE;
DROP TABLE IF EXISTS etl.customers CASCADE;
DROP TABLE IF EXISTS etl.geolocation CASCADE;

-- =====================================================================
-- DIMENSION TABLES
-- =====================================================================

-- Geolocation Table (No Primary Key due to aggregation in ETL)
CREATE TABLE etl.geolocation (
    geolocation_zip_code_prefix INTEGER NOT NULL,
    geolocation_lat DOUBLE PRECISION NOT NULL,
    geolocation_lng DOUBLE PRECISION NOT NULL,
    geolocation_city VARCHAR(100) NOT NULL,
    geolocation_state VARCHAR(2) NOT NULL
);

COMMENT ON TABLE etl.geolocation IS 'Geographical data for zip codes in Brazil (averaged coordinates)';

-- Create index on zip code for lookups
CREATE INDEX idx_geolocation_zip ON etl.geolocation(geolocation_zip_code_prefix);

-- Product Categories Table
CREATE TABLE etl.product_categories (
    product_category_name VARCHAR(100) PRIMARY KEY,
    product_category_name_english VARCHAR(100) NOT NULL
);

COMMENT ON TABLE etl.product_categories IS 'Product category translations from Portuguese to English';

-- Customers Table
CREATE TABLE etl.customers (
    customer_id VARCHAR(255) PRIMARY KEY,
    customer_unique_id VARCHAR(255) NOT NULL,
    customer_zip_code_prefix INTEGER NOT NULL,
    customer_city VARCHAR(100) NOT NULL,
    customer_state VARCHAR(2) NOT NULL
);

COMMENT ON TABLE etl.customers IS 'Customer information and location data';
COMMENT ON COLUMN etl.customers.customer_id IS 'Unique identifier for customer per order';
COMMENT ON COLUMN etl.customers.customer_unique_id IS 'Unique identifier for customer across all orders';

-- Create indexes
CREATE INDEX idx_customers_unique_id ON etl.customers(customer_unique_id);
CREATE INDEX idx_customers_zip ON etl.customers(customer_zip_code_prefix);
CREATE INDEX idx_customers_state ON etl.customers(customer_state);

-- Sellers Table
CREATE TABLE etl.sellers (
    seller_id VARCHAR(255) PRIMARY KEY,
    seller_zip_code_prefix INTEGER NOT NULL,
    seller_city VARCHAR(100) NOT NULL,
    seller_state VARCHAR(2) NOT NULL
);

COMMENT ON TABLE etl.sellers IS 'Seller information and location data';

CREATE INDEX idx_sellers_zip ON etl.sellers(seller_zip_code_prefix);
CREATE INDEX idx_sellers_state ON etl.sellers(seller_state);

-- Products Table
CREATE TABLE etl.products (
    product_id VARCHAR(255) PRIMARY KEY,
    product_category_name VARCHAR(100),
    product_name_lenght DOUBLE PRECISION,
    product_description_lenght DOUBLE PRECISION,
    product_photos_qty DOUBLE PRECISION,
    product_weight_g DOUBLE PRECISION,
    product_length_cm DOUBLE PRECISION,
    product_height_cm DOUBLE PRECISION,
    product_width_cm DOUBLE PRECISION,
    product_volume_cm3 DOUBLE PRECISION,
    CONSTRAINT fk_product_category FOREIGN KEY (product_category_name) 
        REFERENCES etl.product_categories(product_category_name)
        ON DELETE SET NULL
        ON UPDATE CASCADE
);

COMMENT ON TABLE etl.products IS 'Product catalog with dimensions and category';
COMMENT ON COLUMN etl.products.product_volume_cm3 IS 'Calculated volume (length × height × width)';

CREATE INDEX idx_products_category ON etl.products(product_category_name);

-- =====================================================================
-- FACT TABLES
-- =====================================================================

-- Orders Table (Main Fact Table)
CREATE TABLE etl.orders (
    order_id VARCHAR(255) PRIMARY KEY,
    customer_id VARCHAR(255) NOT NULL,
    order_status VARCHAR(50) NOT NULL,
    order_purchase_timestamp TIMESTAMP NOT NULL,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP NOT NULL,
    order_purchase_date DATE,
    order_purchase_time TIME,
    CONSTRAINT fk_order_customer FOREIGN KEY (customer_id) 
        REFERENCES etl.customers(customer_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

COMMENT ON TABLE etl.orders IS 'Order transaction data with status and timestamps';

-- Create indexes for better query performance
CREATE INDEX idx_orders_customer ON etl.orders(customer_id);
CREATE INDEX idx_orders_status ON etl.orders(order_status);
CREATE INDEX idx_orders_purchase_timestamp ON etl.orders(order_purchase_timestamp);
CREATE INDEX idx_orders_purchase_date ON etl.orders(order_purchase_date);
CREATE INDEX idx_orders_delivered_date ON etl.orders(order_delivered_customer_date);

-- Order Items Table
CREATE TABLE etl.order_items (
    order_id VARCHAR(255) NOT NULL,
    order_item_id INTEGER NOT NULL,
    product_id VARCHAR(255) NOT NULL,
    seller_id VARCHAR(255) NOT NULL,
    shipping_limit_date TIMESTAMP NOT NULL,
    price DOUBLE PRECISION NOT NULL,
    freight_value DOUBLE PRECISION NOT NULL,
    PRIMARY KEY (order_id, order_item_id),
    CONSTRAINT fk_order_item_order FOREIGN KEY (order_id) 
        REFERENCES etl.orders(order_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_order_item_product FOREIGN KEY (product_id) 
        REFERENCES etl.products(product_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_order_item_seller FOREIGN KEY (seller_id) 
        REFERENCES etl.sellers(seller_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

COMMENT ON TABLE etl.order_items IS 'Line items for each order with pricing and seller info';

-- Create indexes
CREATE INDEX idx_order_items_order ON etl.order_items(order_id);
CREATE INDEX idx_order_items_product ON etl.order_items(product_id);
CREATE INDEX idx_order_items_seller ON etl.order_items(seller_id);

-- Payments Table
CREATE TABLE etl.payments (
    order_id VARCHAR(255) PRIMARY KEY,
    payment_sequential INTEGER NOT NULL,
    payment_type VARCHAR(50) NOT NULL,
    payment_installments INTEGER NOT NULL,
    payment_value DOUBLE PRECISION NOT NULL,
    CONSTRAINT fk_payment_order FOREIGN KEY (order_id) 
        REFERENCES etl.orders(order_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

COMMENT ON TABLE etl.payments IS 'Payment information for orders';

CREATE INDEX idx_payments_type ON etl.payments(payment_type);

-- Reviews Table
CREATE TABLE etl.reviews (
    review_id VARCHAR(255) NOT NULL,
    order_id VARCHAR(255) NOT NULL,
    review_score INTEGER NOT NULL,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP NOT NULL,
    review_answer_timestamp TIMESTAMP NOT NULL,
    PRIMARY KEY (review_id, order_id),
    CONSTRAINT fk_review_order FOREIGN KEY (order_id) 
        REFERENCES etl.orders(order_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

COMMENT ON TABLE etl.reviews IS 'Customer reviews and ratings for orders';

CREATE INDEX idx_reviews_order ON etl.reviews(order_id);
CREATE INDEX idx_reviews_score ON etl.reviews(review_score);
CREATE INDEX idx_reviews_creation_date ON etl.reviews(review_creation_date);

-- =====================================================================
-- ANALYTICAL VIEWS FOR POWER BI
-- =====================================================================

-- View: Order Summary with Customer and Payment Info
CREATE OR REPLACE VIEW etl.vw_order_summary AS
SELECT 
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    c.customer_zip_code_prefix,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_purchase_date,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    p.payment_type,
    p.payment_installments,
    p.payment_value,
    CASE 
        WHEN o.order_delivered_customer_date IS NOT NULL AND o.order_purchase_timestamp IS NOT NULL
        THEN EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp))/86400 
    END AS delivery_days,
    CASE 
        WHEN o.order_delivered_customer_date IS NOT NULL AND o.order_estimated_delivery_date IS NOT NULL
        THEN EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date))/86400 
    END AS delivery_delay_days,
    CASE 
        WHEN o.order_delivered_customer_date IS NULL THEN 'Not Delivered'
        WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 'On Time'
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 'Delayed'
    END AS delivery_status
FROM etl.orders o
LEFT JOIN etl.customers c ON o.customer_id = c.customer_id
LEFT JOIN etl.payments p ON o.order_id = p.order_id;

COMMENT ON VIEW etl.vw_order_summary IS 'Comprehensive order view with customer and payment details';

-- View: Product Sales Summary
CREATE OR REPLACE VIEW etl.vw_product_sales AS
SELECT 
    p.product_id,
    p.product_category_name,
    pc.product_category_name_english,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,
    p.product_volume_cm3,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    SUM(oi.order_item_id) AS total_items_sold,
    ROUND(CAST(AVG(oi.price) AS numeric), 2) AS avg_price,
    ROUND(CAST(SUM(oi.price) AS numeric), 2) AS total_revenue,
    ROUND(CAST(AVG(oi.freight_value) AS numeric), 2) AS avg_freight,
    ROUND(CAST(AVG(r.review_score) AS numeric), 2) AS avg_review_score,
    COUNT(r.review_id) AS total_reviews
FROM etl.products p
LEFT JOIN etl.order_items oi ON p.product_id = oi.product_id
LEFT JOIN etl.product_categories pc ON p.product_category_name = pc.product_category_name
LEFT JOIN etl.orders o ON oi.order_id = o.order_id
LEFT JOIN etl.reviews r ON o.order_id = r.order_id
GROUP BY 
    p.product_id, 
    p.product_category_name, 
    pc.product_category_name_english,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,
    p.product_volume_cm3;

COMMENT ON VIEW etl.vw_product_sales IS 'Product performance metrics including sales and reviews';

-- View: Seller Performance
CREATE OR REPLACE VIEW etl.vw_seller_performance AS
SELECT 
    s.seller_id,
    s.seller_city,
    s.seller_state,
    s.seller_zip_code_prefix,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(oi.order_item_id) AS total_items_sold,
    ROUND(CAST(SUM(oi.price) AS numeric), 2) AS total_revenue,
    ROUND(CAST(AVG(oi.price) AS numeric), 2) AS avg_item_price,
    ROUND(CAST(AVG(oi.freight_value) AS numeric), 2) AS avg_freight,
    ROUND(CAST(AVG(r.review_score) AS numeric), 2) AS avg_review_score,
    COUNT(DISTINCT p.product_category_name) AS unique_categories
FROM etl.sellers s
LEFT JOIN etl.order_items oi ON s.seller_id = oi.seller_id
LEFT JOIN etl.products p ON oi.product_id = p.product_id
LEFT JOIN etl.orders o ON oi.order_id = o.order_id
LEFT JOIN etl.reviews r ON o.order_id = r.order_id
GROUP BY s.seller_id, s.seller_city, s.seller_state, s.seller_zip_code_prefix;

COMMENT ON VIEW etl.vw_seller_performance IS 'Seller metrics including revenue and customer satisfaction';

-- View: Customer Lifetime Value
CREATE OR REPLACE VIEW etl.vw_customer_ltv AS
SELECT 
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    c.customer_zip_code_prefix,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(CAST(SUM(p.payment_value) AS numeric), 2) AS lifetime_value,
    ROUND(CAST(AVG(p.payment_value) AS numeric), 2) AS avg_order_value,
    MIN(o.order_purchase_timestamp) AS first_purchase_date,
    MAX(o.order_purchase_timestamp) AS last_purchase_date,
    ROUND(CAST(AVG(r.review_score) AS numeric), 2) AS avg_review_score,
    EXTRACT(DAYS FROM (MAX(o.order_purchase_timestamp) - MIN(o.order_purchase_timestamp))) AS customer_lifespan_days
FROM etl.customers c
LEFT JOIN etl.orders o ON c.customer_id = o.customer_id
LEFT JOIN etl.payments p ON o.order_id = p.order_id
LEFT JOIN etl.reviews r ON o.order_id = r.order_id
GROUP BY c.customer_unique_id, c.customer_city, c.customer_state, c.customer_zip_code_prefix;

COMMENT ON VIEW etl.vw_customer_ltv IS 'Customer lifetime value and purchase behavior metrics';

-- View: Monthly Sales Trends
CREATE OR REPLACE VIEW etl.vw_monthly_sales AS
SELECT 
    DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT o.customer_id) AS unique_customers,
    ROUND(CAST(SUM(p.payment_value) AS numeric), 2) AS total_revenue,
    ROUND(CAST(AVG(p.payment_value) AS numeric), 2) AS avg_order_value,
    COUNT(CASE WHEN o.order_status = 'delivered' THEN 1 END) AS delivered_orders,
    COUNT(CASE WHEN o.order_status = 'canceled' THEN 1 END) AS canceled_orders,
    ROUND(CAST(AVG(r.review_score) AS numeric), 2) AS avg_review_score,
    COUNT(r.review_id) AS total_reviews
FROM etl.orders o
LEFT JOIN etl.payments p ON o.order_id = p.order_id
LEFT JOIN etl.reviews r ON o.order_id = r.order_id
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY month;

COMMENT ON VIEW etl.vw_monthly_sales IS 'Monthly aggregated sales and performance metrics';

-- View: Geographic Sales Analysis
CREATE OR REPLACE VIEW etl.vw_geographic_sales AS
SELECT 
    c.customer_state,
    c.customer_city,
    g.geolocation_lat,
    g.geolocation_lng,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
    ROUND(CAST(SUM(p.payment_value) AS numeric), 2) AS total_revenue,
    ROUND(CAST(AVG(p.payment_value) AS numeric), 2) AS avg_order_value,
    ROUND(CAST(AVG(r.review_score) AS numeric), 2) AS avg_review_score
FROM etl.customers c
LEFT JOIN etl.orders o ON c.customer_id = o.customer_id
LEFT JOIN etl.payments p ON o.order_id = p.order_id
LEFT JOIN etl.reviews r ON o.order_id = r.order_id
LEFT JOIN etl.geolocation g ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix
GROUP BY c.customer_state, c.customer_city, g.geolocation_lat, g.geolocation_lng;

COMMENT ON VIEW etl.vw_geographic_sales IS 'Sales metrics by geographic location with coordinates';

-- View: Category Performance
CREATE OR REPLACE VIEW etl.vw_category_performance AS
SELECT 
    pc.product_category_name_english AS category,
    COUNT(DISTINCT p.product_id) AS total_products,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    SUM(oi.order_item_id) AS total_items_sold,
    ROUND(CAST(SUM(oi.price) AS numeric), 2) AS total_revenue,
    ROUND(CAST(AVG(oi.price) AS numeric), 2) AS avg_price,
    ROUND(CAST(AVG(oi.freight_value) AS numeric), 2) AS avg_freight,
    ROUND(CAST(AVG(r.review_score) AS numeric), 2) AS avg_review_score,
    ROUND(CAST(AVG(p.product_weight_g) AS numeric), 2) AS avg_weight_g,
    ROUND(CAST(AVG(p.product_volume_cm3) AS numeric), 2) AS avg_volume_cm3
FROM etl.product_categories pc
LEFT JOIN etl.products p ON pc.product_category_name = p.product_category_name
LEFT JOIN etl.order_items oi ON p.product_id = oi.product_id
LEFT JOIN etl.orders o ON oi.order_id = o.order_id
LEFT JOIN etl.reviews r ON o.order_id = r.order_id
GROUP BY pc.product_category_name_english;

COMMENT ON VIEW etl.vw_category_performance IS 'Performance metrics aggregated by product category';

-- =====================================================================
-- GRANT PERMISSIONS
-- =====================================================================

-- Grant usage on schema
GRANT USAGE ON SCHEMA etl TO PUBLIC;

-- Grant select on all tables and views
GRANT SELECT ON ALL TABLES IN SCHEMA etl TO PUBLIC;

-- Grant select on future tables and views
ALTER DEFAULT PRIVILEGES IN SCHEMA etl GRANT SELECT ON TABLES TO PUBLIC;

-- =====================================================================
-- VERIFICATION QUERIES
-- =====================================================================

-- Check all tables created
DO $$
DECLARE
    table_count INTEGER;
    view_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO table_count FROM pg_tables WHERE schemaname = 'etl';
    SELECT COUNT(*) INTO view_count FROM pg_views WHERE schemaname = 'etl';
    
    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'Schema Setup Completed Successfully!';
    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'Schema: etl';
    RAISE NOTICE 'Tables Created: %', table_count;
    RAISE NOTICE 'Views Created: %', view_count;
    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'Tables:';
    RAISE NOTICE '  - geolocation';
    RAISE NOTICE '  - product_categories';
    RAISE NOTICE '  - customers';
    RAISE NOTICE '  - sellers';
    RAISE NOTICE '  - products';
    RAISE NOTICE '  - orders';
    RAISE NOTICE '  - order_items';
    RAISE NOTICE '  - payments';
    RAISE NOTICE '  - reviews';
    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'Views:';
    RAISE NOTICE '  - vw_order_summary';
    RAISE NOTICE '  - vw_product_sales';
    RAISE NOTICE '  - vw_seller_performance';
    RAISE NOTICE '  - vw_customer_ltv';
    RAISE NOTICE '  - vw_monthly_sales';
    RAISE NOTICE '  - vw_geographic_sales';
    RAISE NOTICE '  - vw_category_performance';
    RAISE NOTICE '=====================================================';
END $$;

-- List all foreign key relationships
SELECT
    tc.table_name AS "Table", 
    kcu.column_name AS "Column", 
    ccu.table_name AS "References Table",
    ccu.column_name AS "References Column"
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND tc.table_schema = 'etl'
ORDER BY tc.table_name;