-- =====================================================================
-- 01_load_data.sql
-- Load the nine Olist CSV files into DuckDB tables with short names.
-- Run from the project root with the CSVs in a data/ folder.
-- =====================================================================

CREATE OR REPLACE TABLE customers      AS SELECT * FROM read_csv_auto('data/olist_customers_dataset.csv');
CREATE OR REPLACE TABLE geolocation    AS SELECT * FROM read_csv_auto('data/olist_geolocation_dataset.csv');
CREATE OR REPLACE TABLE order_items    AS SELECT * FROM read_csv_auto('data/olist_order_items_dataset.csv');
CREATE OR REPLACE TABLE payments       AS SELECT * FROM read_csv_auto('data/olist_order_payments_dataset.csv');
CREATE OR REPLACE TABLE reviews        AS SELECT * FROM read_csv_auto('data/olist_order_reviews_dataset.csv');
CREATE OR REPLACE TABLE orders         AS SELECT * FROM read_csv_auto('data/olist_orders_dataset.csv');
CREATE OR REPLACE TABLE products       AS SELECT * FROM read_csv_auto('data/olist_products_dataset.csv');
CREATE OR REPLACE TABLE sellers        AS SELECT * FROM read_csv_auto('data/olist_sellers_dataset.csv');
CREATE OR REPLACE TABLE category_names AS SELECT * FROM read_csv_auto('data/product_category_name_translation.csv');
