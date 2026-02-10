from sqlalchemy import create_engine, text
import os
from dotenv import load_dotenv
from security_utils import validate_identifier

load_dotenv()
username = os.getenv('DB_USERNAME', 'postgres')
password = os.getenv('DB_PASSWORD')
host = os.getenv('DB_HOST', 'localhost')
port = os.getenv('DB_PORT', '5432')
database = os.getenv('DB_NAME', 'ecommerce_olist')
schema = os.getenv('DB_SCHEMA', 'etl')

# Validate schema name to prevent SQL injection
validate_identifier(schema, "schema")
            
connection_string = f"postgresql://{username}:{password}@{host}:{port}/{database}"
engine = create_engine(connection_string)

with open('schema_from_etl.sql', 'r') as f:
    sql = f.read()

# Inject schema value into SQL file. The SQL uses the placeholder `{schema}` everywhere the schema name is required.
# Schema name has been validated above to contain only safe characters
sql = sql.format(schema=schema)

with engine.connect() as conn:
    conn.execute(text(sql))
    conn.commit()
