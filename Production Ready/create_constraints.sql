-- ============================================================================
-- E-Commerce Database Constraints Script
-- This script adds primary keys and foreign keys to existing tables
-- Schema: etl
-- ============================================================================

-- Set the schema
SET search_path TO etl;

BEGIN;

-- ============================================================================
-- ADD PRIMARY KEYS
-- ============================================================================

-- Customer table: customer_id as primary key
ALTER TABLE IF EXISTS etl."Customer"
    DROP CONSTRAINT IF EXISTS customer_pk CASCADE;

ALTER TABLE IF EXISTS etl."Customer"
    ADD CONSTRAINT customer_pk PRIMARY KEY (customer_id);

-- Geolocation table: geolocation_zip_code_prefix as primary key
ALTER TABLE IF EXISTS etl.geolocation
    DROP CONSTRAINT IF EXISTS geolocation_pk CASCADE;

ALTER TABLE IF EXISTS etl.geolocation
    ADD CONSTRAINT geolocation_pk PRIMARY KEY (geolocation_zip_code_prefix);

-- Orders table: order_id as primary key
ALTER TABLE IF EXISTS etl.orders
    DROP CONSTRAINT IF EXISTS orders_pk CASCADE;

ALTER TABLE IF EXISTS etl.orders
    ADD CONSTRAINT orders_pk PRIMARY KEY (order_id);

-- Order items table: Composite primary key
ALTER TABLE IF EXISTS etl.order_items
    DROP CONSTRAINT IF EXISTS order_items_pk CASCADE;

ALTER TABLE IF EXISTS etl.order_items
    ADD CONSTRAINT order_items_pk PRIMARY KEY (order_id, order_item_id);

-- Payments table: order_id as primary key
ALTER TABLE IF EXISTS etl.payments
    DROP CONSTRAINT IF EXISTS payments_pk CASCADE;

ALTER TABLE IF EXISTS etl.payments
    ADD CONSTRAINT payments_pk PRIMARY KEY (order_id);

-- Products table: product_id as primary key
ALTER TABLE IF EXISTS etl.products
    DROP CONSTRAINT IF EXISTS products_pk CASCADE;

ALTER TABLE IF EXISTS etl.products
    ADD CONSTRAINT products_pk PRIMARY KEY (product_id);

-- Products categories table: product_category_name as primary key
ALTER TABLE IF EXISTS etl.products_categories
    DROP CONSTRAINT IF EXISTS products_categories_pk CASCADE;

ALTER TABLE IF EXISTS etl.products_categories
    ADD CONSTRAINT products_categories_pk PRIMARY KEY (product_category_name);

-- Reviews table: Composite primary key
ALTER TABLE IF EXISTS etl.reviews
    DROP CONSTRAINT IF EXISTS reviews_pk CASCADE;

ALTER TABLE IF EXISTS etl.reviews
    ADD CONSTRAINT reviews_pk PRIMARY KEY (review_id, order_id);

-- Sellers table: seller_id as primary key
ALTER TABLE IF EXISTS etl.sellers
    DROP CONSTRAINT IF EXISTS sellers_pk CASCADE;

ALTER TABLE IF EXISTS etl.sellers
    ADD CONSTRAINT sellers_pk PRIMARY KEY (seller_id);

-- ============================================================================
-- ADD FOREIGN KEYS
-- ============================================================================
-- ============================================================================
-- ADD FOREIGN KEYS
-- ============================================================================

-- Customer to Geolocation
ALTER TABLE IF EXISTS etl."Customer"
    DROP CONSTRAINT IF EXISTS geolocation_fk;

ALTER TABLE IF EXISTS etl."Customer"
    ADD CONSTRAINT geolocation_fk FOREIGN KEY (customer_zip_code_prefix)
    REFERENCES etl.geolocation (geolocation_zip_code_prefix) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE SET NULL;

-- Orders to Customer
ALTER TABLE IF EXISTS etl.orders
    DROP CONSTRAINT IF EXISTS customer_fk;

ALTER TABLE IF EXISTS etl.orders
    ADD CONSTRAINT customer_fk FOREIGN KEY (customer_id)
    REFERENCES etl."Customer" (customer_id) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE CASCADE;

-- Order items to Orders
ALTER TABLE IF EXISTS etl.order_items
    DROP CONSTRAINT IF EXISTS orders_fk;

ALTER TABLE IF EXISTS etl.order_items
    ADD CONSTRAINT orders_fk FOREIGN KEY (order_id)
    REFERENCES etl.orders (order_id) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE CASCADE;

-- Order items to Products
ALTER TABLE IF EXISTS etl.order_items
    DROP CONSTRAINT IF EXISTS product_fk;

ALTER TABLE IF EXISTS etl.order_items
    ADD CONSTRAINT product_fk FOREIGN KEY (product_id)
    REFERENCES etl.products (product_id) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE SET NULL;

-- Order items to Sellers
ALTER TABLE IF EXISTS etl.order_items
    DROP CONSTRAINT IF EXISTS seller_fk;

ALTER TABLE IF EXISTS etl.order_items
    ADD CONSTRAINT seller_fk FOREIGN KEY (seller_id)
    REFERENCES etl.sellers (seller_id) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE SET NULL;

-- Payments to Orders
ALTER TABLE IF EXISTS etl.payments
    DROP CONSTRAINT IF EXISTS payments_orders_fk;

ALTER TABLE IF EXISTS etl.payments
    ADD CONSTRAINT payments_orders_fk FOREIGN KEY (order_id)
    REFERENCES etl.orders (order_id) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE CASCADE;

-- Products to Product Categories
ALTER TABLE IF EXISTS etl.products
    DROP CONSTRAINT IF EXISTS product_categories_fk;

ALTER TABLE IF EXISTS etl.products
    ADD CONSTRAINT product_categories_fk FOREIGN KEY (product_category_name)
    REFERENCES etl.products_categories (product_category_name) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE SET NULL;

-- Reviews to Orders
ALTER TABLE IF EXISTS etl.reviews
    DROP CONSTRAINT IF EXISTS reviews_order_fk;

ALTER TABLE IF EXISTS etl.reviews
    ADD CONSTRAINT reviews_order_fk FOREIGN KEY (order_id)
    REFERENCES etl.orders (order_id) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE CASCADE;

-- ============================================================================
-- CREATE INDEXES for better query performance
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_customer_zip_code ON etl."Customer"(customer_zip_code_prefix);
CREATE INDEX IF NOT EXISTS idx_customer_city ON etl."Customer"(customer_city);
CREATE INDEX IF NOT EXISTS idx_customer_state ON etl."Customer"(customer_state);

CREATE INDEX IF NOT EXISTS idx_seller_zip_code ON etl.sellers(seller_zip_code_prefix);
CREATE INDEX IF NOT EXISTS idx_seller_city ON etl.sellers(seller_city);
CREATE INDEX IF NOT EXISTS idx_seller_state ON etl.sellers(seller_state);

CREATE INDEX IF NOT EXISTS idx_product_category ON etl.products(product_category_name);

CREATE INDEX IF NOT EXISTS idx_order_customer_id ON etl.orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_order_status ON etl.orders(order_status);
CREATE INDEX IF NOT EXISTS idx_order_purchase_date ON etl.orders(order_purchase_timestamp_date);

CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON etl.order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_order_items_seller_id ON etl.order_items(seller_id);
CREATE INDEX IF NOT EXISTS idx_order_items_shipping_date ON etl.order_items(shipping_limit_date);

CREATE INDEX IF NOT EXISTS idx_payment_type ON etl.payments(payment_type);

CREATE INDEX IF NOT EXISTS idx_review_score ON etl.reviews(review_score);
CREATE INDEX IF NOT EXISTS idx_review_creation_date ON etl.reviews(review_creation_date);

CREATE INDEX IF NOT EXISTS idx_geolocation_state ON etl.geolocation(geolocation_state);
CREATE INDEX IF NOT EXISTS idx_geolocation_city ON etl.geolocation(geolocation_city);

END;