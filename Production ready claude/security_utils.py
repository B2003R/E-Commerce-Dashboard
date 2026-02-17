"""
Security utilities for database operations
Provides validation functions to prevent SQL injection and other security vulnerabilities
"""

import re


def validate_identifier(identifier: str, identifier_type: str = "identifier") -> None:
    """
    Validate that an identifier (schema, table, column name) is safe to use in SQL queries.
    
    This prevents SQL injection by ensuring identifiers only contain alphanumeric 
    characters and underscores, and start with a letter or underscore.
    
    Args:
        identifier: The identifier to validate (schema, table, or column name)
        identifier_type: Type of identifier for error messages (default: "identifier")
    
    Raises:
        ValueError: If the identifier contains invalid characters
    
    Example:
        >>> validate_identifier("my_schema", "schema")
        >>> validate_identifier("123invalid", "table")
        ValueError: Invalid table name: 123invalid
    """
    if not identifier:
        raise ValueError(f"Empty {identifier_type} name is not allowed")
    
    if not re.match(r'^[a-zA-Z_][a-zA-Z0-9_]*$', identifier):
        raise ValueError(
            f"Invalid {identifier_type} name: {identifier}. "
            f"Only alphanumeric characters and underscores are allowed, "
            f"and must start with a letter or underscore."
        )


def quote_identifier(identifier: str) -> str:
    """
    Quote an SQL identifier for safe use in queries.
    
    This adds double quotes around the identifier to prevent SQL injection
    and handle identifiers with special characters or reserved words.
    
    Args:
        identifier: The identifier to quote
    
    Returns:
        The quoted identifier
    
    Example:
        >>> quote_identifier("my_table")
        '"my_table"'
    """
    # Escape any existing double quotes in the identifier
    escaped = identifier.replace('"', '""')
    return f'"{escaped}"'


def validate_and_quote_identifier(identifier: str, identifier_type: str = "identifier") -> str:
    """
    Validate an identifier and return it as a quoted identifier.
    
    Combines validation and quoting in a single function for convenience.
    
    Args:
        identifier: The identifier to validate and quote
        identifier_type: Type of identifier for error messages
    
    Returns:
        The quoted identifier
    
    Raises:
        ValueError: If the identifier is invalid
    
    Example:
        >>> validate_and_quote_identifier("my_schema", "schema")
        '"my_schema"'
    """
    validate_identifier(identifier, identifier_type)
    return quote_identifier(identifier)
