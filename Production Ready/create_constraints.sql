-- SQL Script to add Primary Keys and Foreign Keys to existing tables
-- Set search path to etl schema
SET search_path TO etl;

BEGIN;

-- ============================================================================
-- Add Primary Keys to existing tables
-- ============================================================================

-- Add Primary Key to customer table
ALTER TABLE IF EXISTS etl.customer
    DROP CONSTRAINT IF EXISTS "customer_PK" CASCADE;
ALTER TABLE IF EXISTS etl.customer
    ADD CONSTRAINT "customer_PK" PRIMARY KEY (customer_id);

-- Add Primary Key to geolocation table
ALTER TABLE IF EXISTS etl.geolocation
    DROP CONSTRAINT IF EXISTS geolocation_pk CASCADE;
ALTER TABLE IF EXISTS etl.geolocation
    ADD CONSTRAINT geolocation_pk PRIMARY KEY (geolocation_zip_code_prefix);

-- Add Primary Key to order_items table
ALTER TABLE IF EXISTS etl.order_items
    DROP CONSTRAINT IF EXISTS "orders_product_seller_PK" CASCADE;
ALTER TABLE IF EXISTS etl.order_items
    ADD CONSTRAINT "orders_product_seller_PK" PRIMARY KEY (order_id, order_item_id, product_id, seller_id);

-- Add Primary Key to orders table
ALTER TABLE IF EXISTS etl.orders
    DROP CONSTRAINT IF EXISTS "primary key" CASCADE;
ALTER TABLE IF EXISTS etl.orders
    ADD CONSTRAINT "primary key" PRIMARY KEY (order_id);

-- Add Primary Key to payments table
ALTER TABLE IF EXISTS etl.payments
    DROP CONSTRAINT IF EXISTS payments_pkey CASCADE;
ALTER TABLE IF EXISTS etl.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (order_id);

-- Add Primary Key to products table
ALTER TABLE IF EXISTS etl.products
    DROP CONSTRAINT IF EXISTS products_pkey CASCADE;
ALTER TABLE IF EXISTS etl.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (product_id);

-- Add Primary Key to products_categories table
ALTER TABLE IF EXISTS etl.products_categories
    DROP CONSTRAINT IF EXISTS products_categories_pkey CASCADE;
ALTER TABLE IF EXISTS etl.products_categories
    ADD CONSTRAINT products_categories_pkey PRIMARY KEY (product_category_name);

-- Add Primary Key to reviews table
ALTER TABLE IF EXISTS etl.reviews
    DROP CONSTRAINT IF EXISTS reviews_pkey CASCADE;
ALTER TABLE IF EXISTS etl.reviews
    ADD CONSTRAINT reviews_pkey PRIMARY KEY (review_id, order_id);

-- Add Primary Key to sellers table
ALTER TABLE IF EXISTS etl.sellers
    DROP CONSTRAINT IF EXISTS sellers_pkey CASCADE;
ALTER TABLE IF EXISTS etl.sellers
    ADD CONSTRAINT sellers_pkey PRIMARY KEY (seller_id);

-- ============================================================================
-- Add Foreign Keys to existing tables
-- ============================================================================

-- Add Foreign Key from customer to geolocation
ALTER TABLE IF EXISTS etl.customer
    DROP CONSTRAINT IF EXISTS "geolocation_FK" CASCADE;
ALTER TABLE IF EXISTS etl.customer
    ADD CONSTRAINT "geolocation_FK" FOREIGN KEY (customer_zip_code_prefix)
    REFERENCES etl.geolocation (geolocation_zip_code_prefix) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;

-- Add Foreign Key from order_items to orders
ALTER TABLE IF EXISTS etl.order_items
    DROP CONSTRAINT IF EXISTS "orders_FK" CASCADE;
ALTER TABLE IF EXISTS etl.order_items
    ADD CONSTRAINT "orders_FK" FOREIGN KEY (order_id)
    REFERENCES etl.orders (order_id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;

-- Add Foreign Key from order_items to products
ALTER TABLE IF EXISTS etl.order_items
    DROP CONSTRAINT IF EXISTS "product_FK" CASCADE;
ALTER TABLE IF EXISTS etl.order_items
    ADD CONSTRAINT "product_FK" FOREIGN KEY (product_id)
    REFERENCES etl.products (product_id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;

-- Add Foreign Key from order_items to sellers
ALTER TABLE IF EXISTS etl.order_items
    DROP CONSTRAINT IF EXISTS "seller_FK" CASCADE;
ALTER TABLE IF EXISTS etl.order_items
    ADD CONSTRAINT "seller_FK" FOREIGN KEY (seller_id)
    REFERENCES etl.sellers (seller_id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;

-- Add Foreign Key from orders to customer
ALTER TABLE IF EXISTS etl.orders
    DROP CONSTRAINT IF EXISTS "customer_FK" CASCADE;
ALTER TABLE IF EXISTS etl.orders
    ADD CONSTRAINT "customer_FK" FOREIGN KEY (customer_id)
    REFERENCES etl.customer (customer_id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;

-- Add Foreign Key from payments to orders
ALTER TABLE IF EXISTS etl.payments
    DROP CONSTRAINT IF EXISTS "orders_FK" CASCADE;
ALTER TABLE IF EXISTS etl.payments
    ADD CONSTRAINT "orders_FK" FOREIGN KEY (order_id)
    REFERENCES etl.orders (order_id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;

-- Create Index on payments
CREATE INDEX IF NOT EXISTS payments_order_id_idx
    ON etl.payments(order_id);

-- Add Foreign Key from products to products_categories
ALTER TABLE IF EXISTS etl.products
    DROP CONSTRAINT IF EXISTS "product_categories_FK" CASCADE;
ALTER TABLE IF EXISTS etl.products
    ADD CONSTRAINT "product_categories_FK" FOREIGN KEY (product_category_name)
    REFERENCES etl.products_categories (product_category_name) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;

-- Add Foreign Key from reviews to orders
ALTER TABLE IF EXISTS etl.reviews
    DROP CONSTRAINT IF EXISTS "order_FK" CASCADE;
ALTER TABLE IF EXISTS etl.reviews
    ADD CONSTRAINT "order_FK" FOREIGN KEY (order_id)
    REFERENCES etl.orders (order_id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;

-- ============================================================================
-- Constraints added successfully
-- ============================================================================

END;