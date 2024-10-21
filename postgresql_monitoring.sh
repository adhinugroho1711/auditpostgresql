# PostgreSQL Monitoring Configuration

# PostgreSQL connection details
PG_HOST="localhost"
PG_PORT="5432"
PG_USER="postgres"
PG_DB="postgres"

# Log settings
LOG_DIRECTORY="/var/log/postgresql"
LOG_FILENAME="postgresql-%Y-%m-%d_%H%M%S.log"
LOG_ROTATION_AGE="1d"
LOG_ROTATION_SIZE="0"

# Audit settings
AUDIT_LOG_LEVEL="log"
AUDIT_LOG_CATALOG="on"
AUDIT_LOG_PARAMETER="on"
AUDIT_LOG_STATEMENT_ONCE="on"
AUDIT_LOG="write, function, role, ddl"

# Monitoring view name
MONITORING_VIEW_NAME="log_view"

# Monitoring function name
MONITORING_FUNCTION_NAME="get_recent_logs"