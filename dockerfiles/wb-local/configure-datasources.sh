#!/bin/bash

# Configure Databricks and Snowflake connections for Workbench

echo "Configuring data source connections..."

# Configure Databricks if URL is provided
if [ -n "${DATABRICKS_URL_}" ]; then
    echo "Configuring Databricks..."

    # Extract workspace name from URL
    WORKSPACE_NAME=$(echo "$DATABRICKS_URL_" | sed -E 's|https?://([^.]+).*|\1|')

    sudo tee /etc/rstudio/databricks.conf > /dev/null <<EOF
[${WORKSPACE_NAME}]
name = Databricks Dev Workspace
url = ${DATABRICKS_URL_}
client-id = ${DATABRICKS_CLIENT_ID_}
EOF

    echo "  Created /etc/rstudio/databricks.conf for workspace: ${WORKSPACE_NAME}"
else
    echo "  Skipping Databricks configuration (DATABRICKS_URL_ not set)"
fi

# Configure Snowflake if account is provided
if [ -n "${SNOWFLAKE_ACCOUNT_}" ]; then
    echo "Configuring Snowflake..."

    sudo tee /etc/rstudio/snowflake.conf > /dev/null <<EOF
[${SNOWFLAKE_ACCOUNT_}]
client-id = ${SNOWFLAKE_CLIENT_ID_}
client-secret = ${SNOWFLAKE_CLIENT_SECRET_}
account = ${SNOWFLAKE_ACCOUNT_}
EOF

    echo "  Created /etc/rstudio/snowflake.conf for account: ${SNOWFLAKE_ACCOUNT_}"
else
    echo "  Skipping Snowflake configuration (SNOWFLAKE_ACCOUNT_ not set)"
fi

# Append feature flags to rserver.conf if data sources are configured
if [ -n "${DATABRICKS_URL_}" ] || [ -n "${SNOWFLAKE_ACCOUNT_}" ]; then
    echo "Enabling data source features in rserver.conf..."

    # Check if flags already exist to avoid duplicates
    if ! grep -q "allow-refresh-snowflake-roles=1" /etc/rstudio/rserver.conf 2>/dev/null; then
        echo "allow-refresh-snowflake-roles=1" | sudo tee -a /etc/rstudio/rserver.conf > /dev/null
    fi

    if ! grep -q "databricks-enabled=1" /etc/rstudio/rserver.conf 2>/dev/null; then
        echo "databricks-enabled=1" | sudo tee -a /etc/rstudio/rserver.conf > /dev/null
    fi

    echo "  Updated /etc/rstudio/rserver.conf with feature flags"
fi

echo "Data source configuration complete"
