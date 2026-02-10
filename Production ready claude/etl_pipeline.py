"""
E-Commerce ETL Pipeline
=======================
This module implements an ETL (Extract, Transform, Load) pipeline for Brazilian e-commerce data.
It processes 9 datasets from Kaggle and loads them into PostgreSQL with proper data quality checks.

Author: Rohit Bollam
Date: 2025
"""

import pandas as pd
import glob
import os
import logging
from datetime import datetime
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError
from dotenv import load_dotenv
from typing import Dict, List, Optional, Callable
import sys

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f'etl_pipeline_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


class DataQualityMetrics:
    """Class to track data quality metrics throughout the ETL process."""
    
    def __init__(self):
        self.metrics = {}
    
    def calculate_metrics(self, df: pd.DataFrame, table_name: str, stage: str) -> Dict:
        """Calculate data quality metrics for a dataframe."""
        metrics = {
            'table': table_name,
            'stage': stage,
            'total_rows': len(df),
            'total_columns': len(df.columns),
            'null_counts': df.isnull().sum().to_dict(),
            'null_percentage': (df.isnull().sum() / len(df) * 100).to_dict(),
            'duplicate_rows': df.duplicated().sum(),
            'memory_usage_mb': df.memory_usage(deep=True).sum() / (1024 * 1024),
            'timestamp': datetime.now().isoformat()
        }
        
        key = f"{table_name}_{stage}"
        self.metrics[key] = metrics
        logger.info(f"Metrics for {table_name} ({stage}): {metrics['total_rows']} rows, "
                   f"{metrics['duplicate_rows']} duplicates, "
                   f"{df.isnull().sum().sum()} null values")
        return metrics
    
    def generate_report(self) -> pd.DataFrame:
        """Generate a summary report of all metrics."""
        if not self.metrics:
            return pd.DataFrame()
        
        report_data = []
        for key, metrics in self.metrics.items():
            report_data.append({
                'table': metrics['table'],
                'stage': metrics['stage'],
                'rows': metrics['total_rows'],
                'columns': metrics['total_columns'],
                'duplicates': metrics['duplicate_rows'],
                'total_nulls': sum(metrics['null_counts'].values()),
                'memory_mb': round(metrics['memory_usage_mb'], 2)
            })
        
        return pd.DataFrame(report_data)


class DatabaseManager:
    """Manages database connections and operations."""
    
    def __init__(self, schema: str = 'etl'):
        self.engine = None
        self.connection = None
        self.schema = schema
        self._connect()
        self._create_schema()
    
    def _connect(self):
        """Establish database connection using environment variables."""
        try:
            username = os.getenv('DB_USERNAME', 'postgres')
            password = os.getenv('DB_PASSWORD')
            host = os.getenv('DB_HOST', 'localhost')
            port = os.getenv('DB_PORT', '5432')
            database = os.getenv('DB_NAME', 'ecommerce_olist')
            
            if not password:
                raise ValueError("DB_PASSWORD environment variable not set")
            
            connection_string = f"postgresql://{username}:{password}@{host}:{port}/{database}"
            self.engine = create_engine(connection_string)
            self.connection = self.engine.connect()
            logger.info(f"Successfully connected to database: {database}")
            
        except Exception as e:
            logger.error(f"Failed to connect to database: {e}")
            raise
    
    def _create_schema(self):
        """Create schema if it doesn't exist."""
        try:
            # Validate schema name to prevent SQL injection
            # Schema names must be alphanumeric with underscores only
            import re
            if not re.match(r'^[a-zA-Z_][a-zA-Z0-9_]*$', self.schema):
                raise ValueError(f"Invalid schema name: {self.schema}. Only alphanumeric characters and underscores are allowed.")
            
            # Use quoted identifier for safety
            query = text(f'CREATE SCHEMA IF NOT EXISTS "{self.schema}"')
            self.connection.execute(query)
            self.connection.commit()
            logger.info(f"Schema '{self.schema}' is ready")
        except Exception as e:
            logger.error(f"Error creating schema {self.schema}: {e}")
            raise
    
    def check_table_exists(self, table_name: str) -> bool:
        """Check if a table exists in the database schema."""
        try:
            query = text("""
                SELECT EXISTS (
                    SELECT FROM information_schema.tables 
                    WHERE table_schema = :schema_name
                    AND table_name = :table_name
                )
            """)
            result = self.connection.execute(query, {
                "schema_name": self.schema,
                "table_name": table_name
            })
            return result.scalar()
        except Exception as e:
            logger.error(f"Error checking if table {self.schema}.{table_name} exists: {e}")
            return False
    
    def get_max_timestamp(self, table_name: str, timestamp_column: str) -> Optional[datetime]:
        """Get the maximum timestamp from a table for incremental loads."""
        try:
            if not self.check_table_exists(table_name):
                return None
            
            # Validate table and column names to prevent SQL injection
            import re
            if not re.match(r'^[a-zA-Z_][a-zA-Z0-9_]*$', table_name):
                raise ValueError(f"Invalid table name: {table_name}")
            if not re.match(r'^[a-zA-Z_][a-zA-Z0-9_]*$', timestamp_column):
                raise ValueError(f"Invalid column name: {timestamp_column}")
            
            # Use quoted identifiers for safety
            query = text(f'SELECT MAX("{timestamp_column}") FROM "{self.schema}"."{table_name}"')
            result = self.connection.execute(query)
            max_ts = result.scalar()
            logger.info(f"Max timestamp for {self.schema}.{table_name}.{timestamp_column}: {max_ts}")
            return max_ts
        except Exception as e:
            logger.warning(f"Could not get max timestamp for {self.schema}.{table_name}: {e}")
            return None
    
    def load_data(self, df: pd.DataFrame, table_name: str, if_exists: str = 'append') -> int:
        """Load dataframe to database table in the specified schema."""
        try:
            rows_loaded = df.to_sql(
                table_name, 
                con=self.engine, 
                schema=self.schema,
                if_exists=if_exists, 
                index=False
            )
            logger.info(f"Successfully loaded {rows_loaded} rows to {self.schema}.{table_name}")
            return rows_loaded
        except SQLAlchemyError as e:
            logger.error(f"Error loading data to {self.schema}.{table_name}: {e}")
            raise
    
    def close(self):
        """Close database connection."""
        if self.connection:
            self.connection.close()
        if self.engine:
            self.engine.dispose()
        logger.info("Database connection closed")


class ETLPipeline:
    """Main ETL Pipeline class for processing e-commerce data."""
    
    def __init__(self, data_path: str, schema: str = 'etl'):
        self.data_path = data_path
        self.all_files = glob.glob(os.path.join(data_path, "*.csv"))
        self.schema = schema
        self.db_manager = DatabaseManager(schema=schema)
        self.quality_metrics = DataQualityMetrics()
        logger.info(f"Initialized ETL Pipeline with {len(self.all_files)} CSV files")
        logger.info(f"Target schema: {schema}")
    
    def _convert_datetime_columns(self, df: pd.DataFrame, columns: List[str]) -> pd.DataFrame:
        """Convert specified columns to datetime type."""
        for col in columns:
            if col in df.columns:
                try:
                    df[col] = pd.to_datetime(df[col])
                    logger.debug(f"Converted {col} to datetime")
                except Exception as e:
                    logger.warning(f"Could not convert {col} to datetime: {e}")
        return df
    
    def _validate_positive_values(self, df: pd.DataFrame, columns: List[str]) -> pd.DataFrame:
        """Validate that numeric columns contain only positive values."""
        for col in columns:
            if col in df.columns:
                negative_count = (df[col] < 0).sum()
                if negative_count > 0:
                    logger.warning(f"Found {negative_count} negative values in {col}, setting to 0")
                    df.loc[df[col] < 0, col] = 0
        return df
    
    def process_customers(self) -> pd.DataFrame:
        """Extract, transform and load customer data."""
        logger.info("Processing customers dataset...")
        try:
            df = pd.read_csv(self.all_files[0], low_memory=False)
            self.quality_metrics.calculate_metrics(df, 'customers', 'raw')
            
            # No transformations needed - data is clean
            self.quality_metrics.calculate_metrics(df, 'customers', 'transformed')
            self.db_manager.load_data(df, 'customers', if_exists='replace')
            # self.db_manager.load_data(df, 'customers')
            
            return df
        except Exception as e:
            logger.error(f"Error processing customers: {e}")
            raise
    
    def process_geolocation(self) -> pd.DataFrame:
        """Extract, transform and load geolocation data."""
        logger.info("Processing geolocation dataset...")
        try:
            df = pd.read_csv(self.all_files[1], low_memory=False)
            self.quality_metrics.calculate_metrics(df, 'geolocation', 'raw')
            
            # Average coordinates for duplicate zip codes
            df = df.groupby('geolocation_zip_code_prefix').agg({
                'geolocation_lat': 'mean',
                'geolocation_lng': 'mean',
                'geolocation_city': 'first',
                'geolocation_state': 'first'
            }).reset_index()
            
            self.quality_metrics.calculate_metrics(df, 'geolocation', 'transformed')
            self.db_manager.load_data(df, 'geolocation', if_exists='replace')
            
            return df
        except Exception as e:
            logger.error(f"Error processing geolocation: {e}")
            raise
    
    def process_orders(self) -> pd.DataFrame:
        """Extract, transform and load orders data."""
        logger.info("Processing orders dataset...")
        try:
            df = pd.read_csv(self.all_files[2], low_memory=False)
            self.quality_metrics.calculate_metrics(df, 'orders', 'raw')
            
            # Convert datetime columns
            datetime_cols = [
                'order_purchase_timestamp', 'order_approved_at',
                'order_delivered_carrier_date', 'order_delivered_customer_date',
                'order_estimated_delivery_date'
            ]
            df = self._convert_datetime_columns(df, datetime_cols)
            
            # Keep records with missing dates but log the counts
            null_counts = df[datetime_cols].isnull().sum()
            for col, count in null_counts.items():
                if count > 0:
                    logger.info(f"{col} has {count} null values (keeping these records)")
            
            # Create date and time columns for analysis
            df['order_purchase_date'] = df['order_purchase_timestamp'].dt.date
            df['order_purchase_time'] = df['order_purchase_timestamp'].dt.time
            df['order_purchase_date'] = pd.to_datetime(df['order_purchase_date'])
            
            # Validate date logic: delivery should be after purchase
            if 'order_delivered_customer_date' in df.columns:
                invalid_dates = df[
                    (df['order_delivered_customer_date'].notna()) & 
                    (df['order_purchase_timestamp'].notna()) &
                    (df['order_delivered_customer_date'] < df['order_purchase_timestamp'])
                ]
                if len(invalid_dates) > 0:
                    logger.warning(f"Found {len(invalid_dates)} orders with delivery before purchase")
            
            self.quality_metrics.calculate_metrics(df, 'orders', 'transformed')
            
            # Incremental load based on purchase timestamp
            max_ts = self.db_manager.get_max_timestamp('orders', 'order_purchase_timestamp')
            if max_ts:
                df_new = df[df['order_purchase_timestamp'] > max_ts]
                logger.info(f"Incremental load: {len(df_new)} new orders since {max_ts}")
                if len(df_new) > 0:
                    self.db_manager.load_data(df_new, 'orders', if_exists='append')
            else:
                self.db_manager.load_data(df, 'orders', if_exists='replace')
            
            return df
        except Exception as e:
            logger.error(f"Error processing orders: {e}")
            raise
    
    def process_order_items(self) -> pd.DataFrame:
        """Extract, transform and load order items data."""
        logger.info("Processing order items dataset...")
        try:
            df = pd.read_csv(self.all_files[3], low_memory=False)
            self.quality_metrics.calculate_metrics(df, 'order_items', 'raw')
            
            # Convert datetime
            df = self._convert_datetime_columns(df, ['shipping_limit_date'])
            
            # Validate positive values for price and freight
            df = self._validate_positive_values(df, ['price', 'freight_value'])
            
            self.quality_metrics.calculate_metrics(df, 'order_items', 'transformed')
            self.db_manager.load_data(df, 'order_items', if_exists='replace')
            
            return df
        except Exception as e:
            logger.error(f"Error processing order items: {e}")
            raise
    
    def process_payments(self) -> pd.DataFrame:
        """Extract, transform and load payment data."""
        logger.info("Processing payments dataset...")
        try:
            df = pd.read_csv(self.all_files[4], low_memory=False)
            self.quality_metrics.calculate_metrics(df, 'payments', 'raw')
            
            # Remove undefined payment types
            df = df[df['payment_type'] != 'not_defined']
            logger.info(f"Removed {len(df[df['payment_type'] == 'not_defined'])} undefined payment types")
            
            # Validate positive payment values
            df = self._validate_positive_values(df, ['payment_value'])
            
            # Keep all payment records (multiple per order is valid)
            self.quality_metrics.calculate_metrics(df, 'payments', 'transformed')
            self.db_manager.load_data(df, 'payments', if_exists='replace')
            
            return df
        except Exception as e:
            logger.error(f"Error processing payments: {e}")
            raise
    
    def process_reviews(self) -> pd.DataFrame:
        """Extract, transform and load review data."""
        logger.info("Processing reviews dataset...")
        try:
            df = pd.read_csv(self.all_files[5], low_memory=False)
            self.quality_metrics.calculate_metrics(df, 'reviews', 'raw')
            
            # Convert datetime columns
            df = self._convert_datetime_columns(df, ['review_creation_date', 'review_answer_timestamp'])
            
            # Keep null comments (they provide insight into engagement)
            self.quality_metrics.calculate_metrics(df, 'reviews', 'transformed')
            
            # Incremental load based on review creation date
            max_ts = self.db_manager.get_max_timestamp('reviews', 'review_creation_date')
            if max_ts:
                df_new = df[df['review_creation_date'] > max_ts]
                logger.info(f"Incremental load: {len(df_new)} new reviews since {max_ts}")
                if len(df_new) > 0:
                    self.db_manager.load_data(df_new, 'reviews', if_exists='append')
            else:
                self.db_manager.load_data(df, 'reviews', if_exists='replace')
            
            return df
        except Exception as e:
            logger.error(f"Error processing reviews: {e}")
            raise
    
    def process_products(self) -> pd.DataFrame:
        """Extract, transform and load product data."""
        logger.info("Processing products dataset...")
        try:
            df = pd.read_csv(self.all_files[6], low_memory=False)
            self.quality_metrics.calculate_metrics(df, 'products', 'raw')
            
            # Drop rows with missing essential data
            initial_rows = len(df)
            df = df.dropna(subset=['product_category_name', 'product_weight_g'])
            logger.info(f"Dropped {initial_rows - len(df)} rows with missing essential product data")
            
            # Create product volume column
            df['product_volume_cm3'] = (
                df['product_length_cm'] * 
                df['product_height_cm'] * 
                df['product_width_cm']
            )
            
            # Validate positive dimensions and weight
            df = self._validate_positive_values(df, [
                'product_weight_g', 'product_length_cm', 
                'product_height_cm', 'product_width_cm'
            ])
            
            self.quality_metrics.calculate_metrics(df, 'products', 'transformed')
            self.db_manager.load_data(df, 'products', if_exists='replace')
            
            return df
        except Exception as e:
            logger.error(f"Error processing products: {e}")
            raise
    
    def process_sellers(self) -> pd.DataFrame:
        """Extract, transform and load seller data."""
        logger.info("Processing sellers dataset...")
        try:
            df = pd.read_csv(self.all_files[7], low_memory=False)
            self.quality_metrics.calculate_metrics(df, 'sellers', 'raw')
            
            # No transformations needed - data is clean
            self.quality_metrics.calculate_metrics(df, 'sellers', 'transformed')
            self.db_manager.load_data(df, 'sellers', if_exists='replace')
            
            return df
        except Exception as e:
            logger.error(f"Error processing sellers: {e}")
            raise
    
    def process_product_categories(self) -> pd.DataFrame:
        """Extract, transform and load product category translations."""
        logger.info("Processing product categories dataset...")
        try:
            df = pd.read_csv(self.all_files[8], low_memory=False)
            self.quality_metrics.calculate_metrics(df, 'product_categories', 'raw')
            
            # No transformations needed - data is clean
            self.quality_metrics.calculate_metrics(df, 'product_categories', 'transformed')
            self.db_manager.load_data(df, 'product_categories', if_exists='replace')
            
            return df
        except Exception as e:
            logger.error(f"Error processing product categories: {e}")
            raise
    
    def run(self):
        """Execute the complete ETL pipeline."""
        logger.info("=" * 80)
        logger.info("Starting ETL Pipeline Execution")
        logger.info("=" * 80)
        
        start_time = datetime.now()
        
        try:
            # Process all datasets in order
            self.process_customers()
            self.process_geolocation()
            self.process_sellers()
            self.process_product_categories()
            self.process_products()
            self.process_orders()
            self.process_order_items()
            self.process_payments()
            self.process_reviews()
            
            # Generate quality report
            quality_report = self.quality_metrics.generate_report()
            logger.info("\n" + "=" * 80)
            logger.info("DATA QUALITY REPORT")
            logger.info("=" * 80)
            logger.info("\n" + quality_report.to_string())
            
            # Save quality report
            report_filename = f'quality_report_{datetime.now().strftime("%Y%m%d_%H%M%S")}.csv'
            quality_report.to_csv(report_filename, index=False)
            logger.info(f"\nQuality report saved to: {report_filename}")
            
            end_time = datetime.now()
            duration = (end_time - start_time).total_seconds()
            
            logger.info("\n" + "=" * 80)
            logger.info(f"ETL Pipeline Completed Successfully in {duration:.2f} seconds")
            logger.info("=" * 80)
            
        except Exception as e:
            logger.error(f"ETL Pipeline failed: {e}")
            raise
        finally:
            self.db_manager.close()


def main():
    """Main entry point for the ETL pipeline."""
    # Get data path from environment variable or use default
    data_path = os.getenv('DATA_PATH', r"C:\Kuslu\project\E-Commerce Dashboard\Production ready claude\.env")
    
    # Get schema from environment variable or use default
    schema = os.getenv('DB_SCHEMA', 'etl')
    
    if not os.path.exists(data_path):
        logger.error(f"Data path does not exist: {data_path}")
        logger.info("Please set DATA_PATH environment variable or update the default path")
        sys.exit(1)
    
    try:
        pipeline = ETLPipeline(data_path, schema=schema)
        pipeline.run()
    except Exception as e:
        logger.error(f"Pipeline execution failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()