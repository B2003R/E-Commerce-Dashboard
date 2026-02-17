"""
E-Commerce Data ETL Pipeline
This script extracts data from CSV files, transforms them according to business rules,
and loads them into a PostgreSQL database.
"""

import os
import logging
import sys
from datetime import datetime
from pathlib import Path
import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError
from dotenv import load_dotenv
from security_utils import validate_and_quote_identifier


# Configure logging
def setup_logging():
    """Configure logging with both file and console handlers"""
    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)
    
    log_filename = log_dir / f"etl_pipeline_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
    
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_filename),
            logging.StreamHandler(sys.stdout)
        ]
    )
    return logging.getLogger(__name__)


# Initialize logger
logger = setup_logging()


class DatabaseConnection:
    """Handle database connection with context manager"""
    
    def __init__(self):
        load_dotenv()
        self.username = os.getenv('DB_USERNAME')
        self.password = os.getenv('DB_PASSWORD')
        self.host = os.getenv('DB_HOST')
        self.port = os.getenv('DB_PORT')
        self.database = os.getenv('DB_NAME')
        self.schema = os.getenv('DB_SCHEMA', 'etl')
        self.engine = None
        self.connection = None
        
    def __enter__(self):
        """Establish database connection"""
        try:
            connection_string = f"postgresql://{self.username}:{self.password}@{self.host}:{self.port}/{self.database}"
            self.engine = create_engine(connection_string)
            self.connection = self.engine.connect()
            logger.info("Database connection established successfully")
            self._check_and_create_schema()
            return self.engine
        except SQLAlchemyError as e:
            logger.error(f"Failed to connect to database: {e}")
            raise
    
    def _check_and_create_schema(self):
        """Check if schema exists and create if not present"""
        try:
            # Validate and quote schema name to prevent SQL injection
            quoted_schema = validate_and_quote_identifier(self.schema, "schema")
            
            # Check if schema exists
            check_query = text(
                "SELECT schema_name FROM information_schema.schemata WHERE schema_name = :schema_name"
            )
            result = self.connection.execute(check_query, {"schema_name": self.schema})
            schema_exists = result.fetchone() is not None
            
            if schema_exists:
                logger.info(f"Schema '{self.schema}' already exists")
            else:
                # Create schema if it doesn't exist - use quoted identifier for safety
                create_query = text(f'CREATE SCHEMA IF NOT EXISTS {quoted_schema}')
                self.connection.execute(create_query)
                self.connection.commit()
                logger.info(f"Schema '{self.schema}' created successfully")
                
        except SQLAlchemyError as e:
            logger.error(f"Error checking/creating schema: {e}")
            raise
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Close database connection"""
        if self.connection:
            self.connection.close()
            logger.info("Database connection closed")
        if exc_type:
            logger.error(f"Error occurred: {exc_val}")
        return False


class ETLPipeline:
    """ETL Pipeline for E-Commerce data"""
    
    def __init__(self, data_path, engine, schema):
        self.data_path = Path(data_path)
        self.engine = engine
        self.schema = schema
        
        if not self.data_path.exists():
            raise FileNotFoundError(f"Data directory not found: {self.data_path}")
        
        logger.info(f"ETL Pipeline initialized with data path: {self.data_path}")
        logger.info(f"Using schema: {self.schema}")
    
    def load_csv(self, filename):
        """Load CSV file with error handling"""
        try:
            file_path = self.data_path / filename
            logger.info(f"Loading file: {file_path}")
            data = pd.read_csv(file_path, low_memory=False)
            logger.info(f"Successfully loaded {filename} - Shape: {data.shape}")
            return data
        except FileNotFoundError:
            logger.error(f"File not found: {filename}")
            raise
        except Exception as e:
            logger.error(f"Error loading {filename}: {e}")
            raise
    
    def save_to_db(self, data, table_name, if_exists='append'):
        """Save DataFrame to database with error handling"""
        try:
            logger.info(f"Saving data to table: {self.schema}.{table_name} - Rows: {len(data)}")
            data.to_sql(table_name, con=self.engine, schema=self.schema, if_exists= if_exists, index=False)
            logger.info(f"Successfully saved {len(data)} rows to {self.schema}.{table_name}")
        except SQLAlchemyError as e:
            logger.error(f"Database error while saving to {table_name}: {e}")
            raise
        except Exception as e:
            logger.error(f"Error saving to {table_name}: {e}")
            raise
    
    def process_order_items(self):
        """Extract, Transform, and Load order items dataset"""
        logger.info("Processing order_items dataset...")
        try:
            # Extract
            data = self.load_csv('olist_order_items_dataset.csv')
            
            # Transform
            data['shipping_limit_date'] = pd.to_datetime(data['shipping_limit_date'])
            
            # Load
            self.save_to_db(data, 'order_items')
            logger.info("order_items processing completed")
            
        except Exception as e:
            logger.error(f"Error processing order_items: {e}")
            raise
    
    def process_orders(self):
        """Extract, Transform, and Load orders dataset"""
        logger.info("Processing orders dataset...")
        try:
            # Extract
            data = self.load_csv('olist_orders_dataset.csv')
            
            # Transform - Convert timestamp columns to datetime
            data['order_purchase_timestamp'] = pd.to_datetime(data['order_purchase_timestamp'])
            data['order_approved_at'] = pd.to_datetime(data['order_approved_at'])
            data['order_delivered_carrier_date'] = pd.to_datetime(data['order_delivered_carrier_date'])
            data['order_delivered_customer_date'] = pd.to_datetime(data['order_delivered_customer_date'])
            data['order_estimated_delivery_date'] = pd.to_datetime(data['order_estimated_delivery_date'])
            
            # Drop rows with missing values
            initial_rows = len(data)
            data = data.dropna()
            logger.info(f"Dropped {initial_rows - len(data)} rows with missing values")
            
            # Create derived date and time columns
            data['order_purchase_timestamp_date'] = data['order_purchase_timestamp'].dt.date
            data['order_purchase_timestamp_time'] = data['order_purchase_timestamp'].dt.time
            data['order_approved_at_date'] = data['order_approved_at'].dt.date
            data['order_approved_at_time'] = data['order_approved_at'].dt.time
            data['order_delivered_carrier_date_date'] = data['order_delivered_carrier_date'].dt.date
            data['order_delivered_carrier_date_time'] = data['order_delivered_carrier_date'].dt.time
            data['order_delivered_customer_date_date'] = data['order_delivered_customer_date'].dt.date
            data['order_delivered_customer_date_time'] = data['order_delivered_customer_date'].dt.time
            
            # Convert derived date columns back to datetime
            data['order_purchase_timestamp_date'] = pd.to_datetime(data['order_purchase_timestamp_date'])
            data['order_approved_at_date'] = pd.to_datetime(data['order_approved_at_date'])
            data['order_delivered_carrier_date_date'] = pd.to_datetime(data['order_delivered_carrier_date_date'])
            data['order_delivered_customer_date_date'] = pd.to_datetime(data['order_delivered_customer_date_date'])
            data['order_estimated_delivery_date'] = pd.to_datetime(data['order_estimated_delivery_date'])
            
            # Load
            self.save_to_db(data, 'orders')
            logger.info("orders processing completed")
            
        except Exception as e:
            logger.error(f"Error processing orders: {e}")
            raise
    
    def process_payments(self):
        """Extract, Transform, and Load payments dataset"""
        logger.info("Processing payments dataset...")
        try:
            # Extract
            data = self.load_csv('olist_order_payments_dataset.csv')
            
            # Transform - Remove 'not_defined' payment types
            initial_rows = len(data)
            data = data[data['payment_type'] != 'not_defined']
            logger.info(f"Filtered out {initial_rows - len(data)} rows with 'not_defined' payment type")
            
            # Remove duplicates based on order_id
            initial_rows = len(data)
            data = data.drop_duplicates(subset='order_id')
            logger.info(f"Removed {initial_rows - len(data)} duplicate order_ids")
            
            # Load
            self.save_to_db(data, 'payments')
            logger.info("payments processing completed")
            
        except Exception as e:
            logger.error(f"Error processing payments: {e}")
            raise
    
    def process_reviews(self):
        """Extract, Transform, and Load reviews dataset"""
        logger.info("Processing reviews dataset...")
        try:
            # Extract
            data = self.load_csv('olist_order_reviews_dataset.csv')
            
            # Transform - Convert date columns
            data['review_creation_date'] = pd.to_datetime(data['review_creation_date'])
            data['review_answer_timestamp'] = pd.to_datetime(data['review_answer_timestamp'])
            
            # Load
            self.save_to_db(data, 'reviews')
            logger.info("reviews processing completed")
            
        except Exception as e:
            logger.error(f"Error processing reviews: {e}")
            raise
    
    def process_customers(self):
        """Extract, Transform, and Load customers dataset"""
        logger.info("Processing customers dataset...")
        try:
            # Extract
            data = self.load_csv('olist_customers_dataset.csv')
            
            # Transform - No specific transformations needed
            # Data is already clean according to the notebook
            
            # Load
            self.save_to_db(data, 'customer')
            logger.info("customers processing completed")
            
        except Exception as e:
            logger.error(f"Error processing customers: {e}")
            raise
    
    def process_products(self):
        """Extract, Transform, and Load products dataset"""
        logger.info("Processing products dataset...")
        try:
            # Extract
            data = self.load_csv('olist_products_dataset.csv')
            
            # Transform - Drop null values
            initial_rows = len(data)
            data.dropna(inplace=True)
            logger.info(f"Dropped {initial_rows - len(data)} rows with missing values")
            
            # Create product volume column
            data['product_volume_cm3'] = (data['product_length_cm'] * 
                                         data['product_height_cm'] * 
                                         data['product_width_cm'])
            logger.info("Created product_volume_cm3 column")
            
            # Load
            self.save_to_db(data, 'products')
            logger.info("products processing completed")
            
        except Exception as e:
            logger.error(f"Error processing products: {e}")
            raise
    
    def process_sellers(self):
        """Extract, Transform, and Load sellers dataset"""
        logger.info("Processing sellers dataset...")
        try:
            # Extract
            data = self.load_csv('olist_sellers_dataset.csv')
            
            # Transform - No specific transformations needed
            
            # Load
            self.save_to_db(data, 'sellers')
            logger.info("sellers processing completed")
            
        except Exception as e:
            logger.error(f"Error processing sellers: {e}")
            raise
    
    def process_geolocation(self):
        """Extract, Transform, and Load geolocation dataset"""
        logger.info("Processing geolocation dataset...")
        try:
            # Extract
            data = self.load_csv('olist_geolocation_dataset.csv')
            
            # Transform - Remove duplicates based on zip code prefix
            initial_rows = len(data)
            data = data.drop_duplicates(subset=['geolocation_zip_code_prefix'])
            logger.info(f"Removed {initial_rows - len(data)} duplicate zip codes")
            
            # Load
            self.save_to_db(data, 'geolocation')
            logger.info("geolocation processing completed")
            
        except Exception as e:
            logger.error(f"Error processing geolocation: {e}")
            raise
    
    def process_product_categories(self):
        """Extract, Transform, and Load product categories dataset"""
        logger.info("Processing product_categories dataset...")
        try:
            # Extract
            data = self.load_csv('product_category_name_translation.csv')
            
            # Transform - No specific transformations needed
            
            # Load
            self.save_to_db(data, 'products_categories')
            logger.info("product_categories processing completed")
            
        except Exception as e:
            logger.error(f"Error processing product_categories: {e}")
            raise
    
    # # def cleanup_orphaned_records(self):
    # #     """Remove orphaned records that violate foreign key constraints"""
    # #     logger.info("=" * 80)
    # #     logger.info("Cleaning up orphaned records for foreign key integrity...")
    # #     logger.info("=" * 80)
        
    #     try:
    #         # Clean up customers with invalid zip codes (not in geolocation)
    #         logger.info("Checking Customer records...")
    #         query = text(f"""
    #             DELETE FROM {self.schema}."Customer"
    #             WHERE customer_zip_code_prefix NOT IN (
    #                 SELECT geolocation_zip_code_prefix FROM {self.schema}.geolocation
    #             )
    #         """)
    #         result = self.engine.execute(query)
    #         logger.info(f"Removed {result.rowcount} customers with invalid zip codes")
            
    #         # Clean up products with invalid categories
    #         logger.info("Checking products records...")
    #         query = text(f"""
    #             DELETE FROM {self.schema}.products
    #             WHERE product_category_name IS NOT NULL 
    #             AND product_category_name NOT IN (
    #                 SELECT product_category_name FROM {self.schema}.products_categories
    #             )
    #         """)
    #         result = self.engine.execute(query)
    #         logger.info(f"Removed {result.rowcount} products with invalid categories")
            
    #         # Clean up orders with invalid customer_id
    #         logger.info("Checking orders records...")
    #         query = text(f"""
    #             DELETE FROM {self.schema}.orders
    #             WHERE customer_id NOT IN (
    #                 SELECT customer_id FROM {self.schema}."Customer"
    #             )
    #         """)
    #         result = self.engine.execute(query)
    #         logger.info(f"Removed {result.rowcount} orders with invalid customer_id")
            
    #         # Clean up order_items with invalid order_id
    #         logger.info("Checking order_items records...")
    #         query = text(f"""
    #             DELETE FROM {self.schema}.order_items
    #             WHERE order_id NOT IN (
    #                 SELECT order_id FROM {self.schema}.orders
    #             )
    #         """)
    #         result = self.engine.execute(query)
    #         logger.info(f"Removed {result.rowcount} order_items with invalid order_id")
            
    #         # Clean up order_items with invalid product_id
    #         query = text(f"""
    #             DELETE FROM {self.schema}.order_items
    #             WHERE product_id NOT IN (
    #                 SELECT product_id FROM {self.schema}.products
    #             )
    #         """)
    #         result = self.engine.execute(query)
    #         logger.info(f"Removed {result.rowcount} order_items with invalid product_id")
            
    #         # Clean up order_items with invalid seller_id
    #         query = text(f"""
    #             DELETE FROM {self.schema}.order_items
    #             WHERE seller_id NOT IN (
    #                 SELECT seller_id FROM {self.schema}.sellers
    #             )
    #         """)
    #         result = self.engine.execute(query)
    #         logger.info(f"Removed {result.rowcount} order_items with invalid seller_id")
            
    #         # Clean up payments with invalid order_id
    #         logger.info("Checking payments records...")
    #         query = text(f"""
    #             DELETE FROM {self.schema}.payments
    #             WHERE order_id NOT IN (
    #                 SELECT order_id FROM {self.schema}.orders
    #             )
    #         """)
    #         result = self.engine.execute(query)
    #         logger.info(f"Removed {result.rowcount} payments with invalid order_id")
            
    #         # Clean up reviews with invalid order_id
    #         logger.info("Checking reviews records...")
    #         query = text(f"""
    #             DELETE FROM {self.schema}.reviews
    #             WHERE order_id NOT IN (
    #                 SELECT order_id FROM {self.schema}.orders
    #             )
    #         """)
    #         result = self.engine.execute(query)
    #         logger.info(f"Removed {result.rowcount} reviews with invalid order_id")
            
    #         logger.info("=" * 80)
    #         logger.info("Orphaned records cleanup completed")
    #         logger.info("=" * 80)
            
    #     except Exception as e:
    #         logger.error(f"Error cleaning up orphaned records: {e}")
    #         raise
    
    def run_full_pipeline(self):
        """Execute the complete ETL pipeline"""
        logger.info("=" * 80)
        logger.info("Starting ETL Pipeline Execution")
        logger.info("=" * 80)
        
        start_time = datetime.now()
        
        try:
            # Process all datasets in order
            self.process_geolocation()
            self.process_customers()
            self.process_product_categories()
            self.process_products()
            self.process_sellers()
            self.process_order_items()
            self.process_payments()
            self.process_reviews()
            self.process_orders()
            
            
            # Clean up orphaned records
            # self.cleanup_orphaned_records()
            
            end_time = datetime.now()
            duration = (end_time - start_time).total_seconds()
            
            logger.info("=" * 80)
            logger.info(f"ETL Pipeline Completed Successfully in {duration:.2f} seconds")
            logger.info("=" * 80)
            
        except Exception as e:
            logger.error("=" * 80)
            logger.error(f"ETL Pipeline Failed: {e}")
            logger.error("=" * 80)
            raise


def main():
    """Main execution function"""
    try:
        # Load environment variables
        load_dotenv()
        data_path = os.getenv('DATA_PATH', './Data')
        schema = os.getenv('DB_SCHEMA', 'etl')
        
        # Create database connection and run ETL pipeline
        with DatabaseConnection() as engine:
            pipeline = ETLPipeline(data_path, engine, schema)
            pipeline.run_full_pipeline()
            
    except Exception as e:
        logger.critical(f"Critical error in main execution: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
