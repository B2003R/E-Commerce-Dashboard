# E-Commerce Dashboard

This repository contains ETL pipelines and analytics for Brazilian e-commerce data.

## Security Best Practices

### Environment Variables

**IMPORTANT:** Never commit `.env` files to version control!

1. Copy `.env.example` to `.env` in the appropriate directory:
   ```bash
   cp "Production Ready/.env.example" "Production Ready/.env"
   # or
   cp "Production ready claude/.env.example" "Production ready claude/.env"
   ```

2. Update the `.env` file with your actual credentials:
   - Use strong passwords (minimum 12 characters, mix of upper/lower case, numbers, and special characters)
   - Never share your `.env` file
   - Use different passwords for development and production environments

### Database Security

1. **Connection Security:**
   - Use SSL/TLS for database connections in production
   - Limit database access to specific IP addresses
   - Use read-only database users when write access isn't needed

2. **Password Management:**
   - Store passwords in environment variables, never in code
   - Rotate passwords regularly
   - Use password managers or secret management services (e.g., AWS Secrets Manager, Azure Key Vault)

3. **SQL Injection Prevention:**
   - Always use parameterized queries with SQLAlchemy
   - Validate and sanitize all user inputs
   - Use quoted identifiers for table/column names
   - Never build SQL queries with string concatenation of user input

### Code Security

1. **Input Validation:**
   - Validate schema, table, and column names match expected patterns
   - Check data types before processing
   - Sanitize file paths to prevent directory traversal

2. **Dependencies:**
   - Keep all Python packages up to date
   - Review security advisories for dependencies
   - Use `pip-audit` or similar tools to check for vulnerabilities

3. **Logging:**
   - Never log sensitive information (passwords, tokens, PII)
   - Use appropriate log levels
   - Secure log files with proper permissions

## Setup

### Prerequisites

- Python 3.8 or higher
- PostgreSQL 12 or higher
- Required Python packages (install with `pip install -r requirements.txt` if available)

### Installation

1. Clone the repository
2. Set up your environment variables (see Security Best Practices above)
3. Install dependencies
4. Run the ETL pipeline:
   ```bash
   cd "Production Ready"
   python etl_pipeline.py
   ```

## Project Structure

- `Production Ready/` - Production-ready ETL pipeline
- `Production ready claude/` - Alternative ETL implementation
- `Data/` - Data files (not included in repository)
- `.env.example` - Template for environment variables

## Contributing

When contributing, please:
- Never commit sensitive data
- Follow the security best practices outlined above
- Test changes thoroughly before submitting
- Document any new security considerations

## License

[Add license information here]
