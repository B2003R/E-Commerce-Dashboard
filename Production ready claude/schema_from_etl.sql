-- Relation-only DDL generated from `etl_pipeline.py`
-- This script DOES NOT create tables. It only creates the schema (if missing)
-- and applies foreign-key relationships and helpful indexes between tables
-- that are created/loaded by `etl_pipeline.py`.

-- Usage: run this *after* running the ETL once so the tables exist.

-- Create schema placeholder (no tables are created here)
CREATE SCHEMA IF NOT EXISTS {schema};
SET search_path TO {schema};

-- Primary keys: create (idempotent) primary key constraints first
-- Drop existing PK constraints if present, then add them. This ensures PKs exist
-- before foreign keys are applied.
ALTER TABLE IF EXISTS {schema}.product_categories DROP CONSTRAINT IF EXISTS pk_product_categories;
ALTER TABLE IF EXISTS {schema}.product_categories
    ADD CONSTRAINT pk_product_categories PRIMARY KEY (product_category_name);

ALTER TABLE IF EXISTS {schema}.geolocation DROP CONSTRAINT IF EXISTS pk_geolocation;
ALTER TABLE IF EXISTS {schema}.geolocation
    ADD CONSTRAINT pk_geolocation PRIMARY KEY (geolocation_zip_code_prefix);

ALTER TABLE IF EXISTS {schema}.customers DROP CONSTRAINT IF EXISTS pk_customers;
ALTER TABLE IF EXISTS {schema}.customers
    ADD CONSTRAINT pk_customers PRIMARY KEY (customer_id);

ALTER TABLE IF EXISTS {schema}.sellers DROP CONSTRAINT IF EXISTS pk_sellers;
ALTER TABLE IF EXISTS {schema}.sellers
    ADD CONSTRAINT pk_sellers PRIMARY KEY (seller_id);

ALTER TABLE IF EXISTS {schema}.products DROP CONSTRAINT IF EXISTS pk_products;
ALTER TABLE IF EXISTS {schema}.products
    ADD CONSTRAINT pk_products PRIMARY KEY (product_id);

ALTER TABLE IF EXISTS {schema}.orders DROP CONSTRAINT IF EXISTS pk_orders;
ALTER TABLE IF EXISTS {schema}.orders
    ADD CONSTRAINT pk_orders PRIMARY KEY (order_id);

ALTER TABLE IF EXISTS {schema}.order_items DROP CONSTRAINT IF EXISTS pk_order_items;
ALTER TABLE IF EXISTS {schema}.order_items
    ADD CONSTRAINT pk_order_items PRIMARY KEY (order_id, order_item_id);

ALTER TABLE IF EXISTS {schema}.payments DROP CONSTRAINT IF EXISTS pk_payments;
ALTER TABLE IF EXISTS {schema}.payments
    ADD CONSTRAINT pk_payments PRIMARY KEY (order_id);

ALTER TABLE IF EXISTS {schema}.reviews DROP CONSTRAINT IF EXISTS pk_reviews;
ALTER TABLE IF EXISTS {schema}.reviews
    ADD CONSTRAINT pk_reviews PRIMARY KEY (review_id, order_id);

-- Idempotent FK creation: drop constraint if exists then add it.
-- 1) products.product_category_name -> product_categories(product_category_name)
ALTER TABLE IF EXISTS {schema}.products DROP CONSTRAINT IF EXISTS fk_product_category;
ALTER TABLE IF EXISTS {schema}.products
    ADD CONSTRAINT fk_product_category FOREIGN KEY (product_category_name)
    REFERENCES {schema}.product_categories(product_category_name)
    ON DELETE SET NULL ON UPDATE CASCADE;

-- 2) orders.customer_id -> customers(customer_id)
ALTER TABLE IF EXISTS {schema}.orders DROP CONSTRAINT IF EXISTS fk_order_customer;
ALTER TABLE IF EXISTS {schema}.orders
    ADD CONSTRAINT fk_order_customer FOREIGN KEY (customer_id)
    REFERENCES {schema}.customers(customer_id)
    ON DELETE CASCADE ON UPDATE CASCADE;

-- 3) order_items -> orders/products/sellers
ALTER TABLE IF EXISTS {schema}.order_items DROP CONSTRAINT IF EXISTS fk_order_item_order;
ALTER TABLE IF EXISTS {schema}.order_items
    ADD CONSTRAINT fk_order_item_order FOREIGN KEY (order_id)
    REFERENCES {schema}.orders(order_id) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE IF EXISTS {schema}.order_items DROP CONSTRAINT IF EXISTS fk_order_item_product;
ALTER TABLE IF EXISTS {schema}.order_items
    ADD CONSTRAINT fk_order_item_product FOREIGN KEY (product_id)
    REFERENCES {schema}.products(product_id) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE IF EXISTS {schema}.order_items DROP CONSTRAINT IF EXISTS fk_order_item_seller;
ALTER TABLE IF EXISTS {schema}.order_items
    ADD CONSTRAINT fk_order_item_seller FOREIGN KEY (seller_id)
    REFERENCES {schema}.sellers(seller_id) ON DELETE CASCADE ON UPDATE CASCADE;

-- 4) payments.order_id -> orders(order_id)
ALTER TABLE IF EXISTS {schema}.payments DROP CONSTRAINT IF EXISTS fk_payment_order;
ALTER TABLE IF EXISTS {schema}.payments
    ADD CONSTRAINT fk_payment_order FOREIGN KEY (order_id)
    REFERENCES {schema}.orders(order_id) ON DELETE CASCADE ON UPDATE CASCADE;

-- 5) reviews.order_id -> orders(order_id)
ALTER TABLE IF EXISTS {schema}.reviews DROP CONSTRAINT IF EXISTS fk_review_order;
ALTER TABLE IF EXISTS {schema}.reviews
    ADD CONSTRAINT fk_review_order FOREIGN KEY (order_id)
    REFERENCES {schema}.orders(order_id) ON DELETE CASCADE ON UPDATE CASCADE;

-- 6) customers.customer_zip_code_prefix -> geolocation.geolocation_zip_code_prefix
-- (optional, useful for joins; left as a FK but only add if geolocation is populated)
ALTER TABLE IF EXISTS {schema}.customers DROP CONSTRAINT IF EXISTS fk_customers_geolocation;
ALTER TABLE IF EXISTS {schema}.customers
    ADD CONSTRAINT fk_customers_geolocation FOREIGN KEY (customer_zip_code_prefix)
    REFERENCES {schema}.geolocation(geolocation_zip_code_prefix) ON DELETE SET NULL ON UPDATE CASCADE;

-- Indexes on FK columns (created conditionally)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = '{schema}' AND table_name = 'orders') THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS idx_orders_customer ON {schema}.orders(customer_id)';
        EXECUTE 'CREATE INDEX IF NOT EXISTS idx_orders_purchase_timestamp ON {schema}.orders(order_purchase_timestamp)';
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = '{schema}' AND table_name = 'order_items') THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS idx_order_items_order ON {schema}.order_items(order_id)';
        EXECUTE 'CREATE INDEX IF NOT EXISTS idx_order_items_product ON {schema}.order_items(product_id)';
        EXECUTE 'CREATE INDEX IF NOT EXISTS idx_order_items_seller ON {schema}.order_items(seller_id)';
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = '{schema}' AND table_name = 'customers') THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS idx_customers_unique_id ON {schema}.customers(customer_unique_id)';
        EXECUTE 'CREATE INDEX IF NOT EXISTS idx_customers_zip ON {schema}.customers(customer_zip_code_prefix)';
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = '{schema}' AND table_name = 'products') THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS idx_products_category ON {schema}.products(product_category_name)';
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = '{schema}' AND table_name = 'payments') THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS idx_payments_type ON {schema}.payments(payment_type)';
    END IF;
END$$;

-- Optional: keep the analytical view creation (view will fail if underlying tables are missing)
CREATE OR REPLACE VIEW {schema}.vw_order_summary AS
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
FROM {schema}.orders o
LEFT JOIN {schema}.customers c ON o.customer_id = c.customer_id
LEFT JOIN {schema}.payments p ON o.order_id = p.order_id;

-- End relation-only schema
