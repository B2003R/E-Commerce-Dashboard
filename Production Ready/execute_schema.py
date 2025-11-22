"""
SQL Constraints Execution Script
This script executes the create_constraints.sql file to add primary keys, 
foreign keys, and indexes to the database tables.
"""

import os
import logging
import sys
from pathlib import Path
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError
from dotenv import load_dotenv
from datetime import datetime


# Configure logging
def setup_logging():
    """Configure logging with both file and console handlers"""
    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)
    
    log_filename = log_dir / f"constraints_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
    
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


class SQLConstraintsExecutor:
    """Execute SQL constraints script with transaction management"""
    
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
    
    def connect(self):
        """Establish database connection"""
        try:
            connection_string = f"postgresql://{self.username}:{self.password}@{self.host}:{self.port}/{self.database}"
            self.engine = create_engine(connection_string)
            self.connection = self.engine.connect()
            logger.info("Database connection established successfully")
            logger.info(f"Target schema: {self.schema}")
        except SQLAlchemyError as e:
            logger.error(f"Failed to connect to database: {e}")
            raise
    
    def disconnect(self):
        """Close database connection"""
        if self.connection:
            self.connection.close()
            logger.info("Database connection closed")
    
    def read_sql_file(self, file_path):
        """Read SQL file and return its content"""
        try:
            sql_file = Path(file_path)
            if not sql_file.exists():
                raise FileNotFoundError(f"SQL file not found: {file_path}")
            
            with open(sql_file, 'r', encoding='utf-8') as file:
                sql_content = file.read()
            
            logger.info(f"Successfully read SQL file: {file_path}")
            return sql_content
        except Exception as e:
            logger.error(f"Error reading SQL file: {e}")
            raise
    
    def execute_sql_script(self, sql_file_path):
        """Execute SQL script file with BEGIN/END transaction handling"""
        try:
            # Read SQL file
            sql_content = self.read_sql_file(sql_file_path)
            
            # Check if script has BEGIN/END transaction blocks
            has_transaction = 'BEGIN;' in sql_content and 'END;' in sql_content
            
            if has_transaction:
                logger.info("Detected BEGIN/END transaction block")
                logger.info("Executing entire script as single transaction...")
                try:
                    # Execute the entire script as one transaction
                    self.connection.execute(text(sql_content))
                    self.connection.commit()
                    logger.info("=" * 80)
                    logger.info("Transaction committed successfully!")
                    logger.info("All constraints and indexes created successfully!")
                    logger.info("=" * 80)
                    return True
                except SQLAlchemyError as e:
                    logger.error(f"Transaction failed: {e}")
                    try:
                        self.connection.rollback()
                        logger.info("Transaction rolled back")
                    except:
                        pass
                    raise
            else:
                # Split by semicolons for individual statement execution
                logger.info("No transaction block detected - executing statements individually")
                statements = self._parse_statements(sql_content)
                return self._execute_statements(statements)
                
        except Exception as e:
            logger.error(f"Error executing SQL script: {e}")
            raise
    
    def _parse_statements(self, sql_content):
        """Parse SQL content into individual statements"""
        raw_statements = sql_content.split(';')
        statements = []
        
        for stmt in raw_statements:
            clean_stmt = stmt.strip()
            
            # Skip empty statements
            if not clean_stmt:
                continue
            
            # Skip comment-only blocks
            lines = clean_stmt.split('\n')
            non_comment_lines = [line for line in lines if line.strip() and not line.strip().startswith('--')]
            
            if non_comment_lines:
                statements.append(clean_stmt)
        
        return statements
    
    def _execute_statements(self, statements):
        """Execute individual SQL statements"""
        logger.info(f"Found {len(statements)} SQL statements to execute")
        
        executed_count = 0
        failed_count = 0
        
        for i, statement in enumerate(statements, 1):
            try:
                # Get a preview of the statement for logging
                preview = statement.replace('\n', ' ').strip()[:100]
                logger.info(f"Executing statement {i}/{len(statements)}: {preview}...")
                
                self.connection.execute(text(statement))
                self.connection.commit()
                executed_count += 1
                
            except SQLAlchemyError as e:
                # Log error but continue with other statements
                error_msg = str(e).split('\n')[0][:200]
                logger.warning(f"Statement {i} failed: {error_msg}")
                failed_count += 1
                try:
                    self.connection.rollback()
                except:
                    pass
        
        logger.info("=" * 80)
        logger.info(f"SQL Script Execution Summary:")
        logger.info(f"  Successfully executed: {executed_count} statements")
        logger.info(f"  Failed: {failed_count} statements")
        logger.info("=" * 80)
        
        if failed_count > 0:
            logger.warning("Some statements failed. Check logs for details.")
            return False
        else:
            logger.info("All statements executed successfully!")
            return True


def main():
    """Main execution function"""
    executor = None
    
    try:
        logger.info("=" * 80)
        logger.info("Starting SQL Constraints Creation")
        logger.info("=" * 80)
        logger.info("This script will add primary keys, foreign keys, and indexes")
        logger.info("=" * 80)
        
        # SQL file path
        sql_file = "create_constraints.sql"
        
        # Create executor and connect
        executor = SQLConstraintsExecutor()
        executor.connect()
        
        # Execute SQL script
        success = executor.execute_sql_script(sql_file)
        
        logger.info("=" * 80)
        if success:
            logger.info("✓ Constraints creation completed successfully!")
            logger.info("✓ All primary keys added")
            logger.info("✓ All foreign keys added")
            logger.info("✓ All indexes created")
        else:
            logger.warning("⚠ Constraints creation completed with some errors")
        logger.info("=" * 80)
        
    except FileNotFoundError as e:
        logger.error(f"File not found: {e}")
        sys.exit(1)
    except SQLAlchemyError as e:
        logger.error(f"Database error: {e}")
        sys.exit(1)
    except Exception as e:
        logger.critical(f"Critical error: {e}")
        sys.exit(1)
    finally:
        # Always disconnect
        if executor:
            executor.disconnect()


if __name__ == "__main__":
    main()
