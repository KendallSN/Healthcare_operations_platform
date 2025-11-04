#!/bin/bash
# Deploy SQL scripts and Oracle directories to VM
# This script can be run on both primary and standby VMs
# Oracle DIRECTORY objects are only created on primary (they replicate to standby)

# ============================================================================
# Pre-flight checks
# ============================================================================

# Check if synced folders are properly mounted
if [ ! -f "/vagrant_config/install.env" ]; then
  echo "ERROR: Configuration file not found: /vagrant_config/install.env"
  echo ""
  echo "This usually means synced folders are not properly mounted."
  echo ""
  echo "Possible causes:"
  echo "  1. VirtualBox Guest Additions version mismatch"
  echo "  2. VM was not reloaded after Vagrantfile changes"
  echo ""
  echo "To fix:"
  echo "  1. Install vagrant-vbguest plugin: vagrant plugin install vagrant-vbguest"
  echo "  2. Reload the VM: vagrant reload"
  echo ""
  exit 1
fi

# Source environment files
. /vagrant_config/install.env
. /home/oracle/scripts/setEnv.sh

LOG_FILE="/home/oracle/logs/sql_directories_deployment.log"
mkdir -p /home/oracle/logs

echo "******************************************************************************" | tee -a "$LOG_FILE"
echo "SQL Scripts and Directories Deployment" `date` | tee -a "$LOG_FILE"
echo "******************************************************************************" | tee -a "$LOG_FILE"

# Check if Oracle is running (for database operations later)
echo "Checking Oracle database status..." | tee -a "$LOG_FILE"
ORACLE_RUNNING=$(su - oracle -c "ps aux | grep pmon | grep -v grep" || true)
if [ -z "$ORACLE_RUNNING" ]; then
  echo "WARNING: Oracle database is not running!" | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
  echo "Oracle DIRECTORY objects cannot be created while database is down." | tee -a "$LOG_FILE"
  echo "SQL files and filesystem directories will still be deployed." | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
  echo "To start Oracle database, run one of:" | tee -a "$LOG_FILE"
  echo "  Option 1 (systemd):  vagrant provision --provision-with setup_oracle_autostart" | tee -a "$LOG_FILE"
  echo "  Option 2 (manual):   vagrant ssh -c 'sudo su - oracle -c \"lsnrctl start && sqlplus / as sysdba <<< STARTUP\"'" | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
  DB_IS_DOWN=true
else
  echo "[OK] Oracle database is running" | tee -a "$LOG_FILE"
  DB_IS_DOWN=false
fi
echo "" | tee -a "$LOG_FILE"

# ============================================================================
# Step 1: Copy SQL files from synced folder to /home/oracle/scripts/
# ============================================================================
echo "" | tee -a "$LOG_FILE"
echo "Step 1: Copying SQL scripts..." `date` | tee -a "$LOG_FILE"
echo "******************************************************************************" | tee -a "$LOG_FILE"

SQL_SOURCE="/vagrant_sql_scripts"
SQL_DEST="/home/oracle/scripts"

# Create destination directory if it doesn't exist
mkdir -p "$SQL_DEST"
chown oracle:oinstall "$SQL_DEST"
chmod 755 "$SQL_DEST"

# Check if source directory has any SQL files
if [ -d "$SQL_SOURCE" ] && [ "$(ls -A "$SQL_SOURCE" 2>/dev/null)" ]; then
  SQL_COUNT=$(find "$SQL_SOURCE" -type f -name "*.sql" 2>/dev/null | wc -l)

  if [ "$SQL_COUNT" -gt 0 ]; then
    echo "Found $SQL_COUNT SQL file(s) to copy" | tee -a "$LOG_FILE"

    # Copy all SQL files preserving directory structure
    find "$SQL_SOURCE" -type f -name "*.sql" -print0 | while IFS= read -r -d '' file; do
      # Get relative path from source
      rel_path="${file#$SQL_SOURCE/}"
      dest_file="$SQL_DEST/$rel_path"
      dest_dir=$(dirname "$dest_file")

      # Create destination directory if needed
      mkdir -p "$dest_dir"

      # Copy file
      cp "$file" "$dest_file"
      chown oracle:oinstall "$dest_file"
      chmod 644 "$dest_file"

      echo "  Copied: $rel_path" | tee -a "$LOG_FILE"
    done

    echo "SQL files copied successfully" | tee -a "$LOG_FILE"
  else
    echo "No SQL files found in $SQL_SOURCE - skipping" | tee -a "$LOG_FILE"
  fi
else
  echo "Source directory $SQL_SOURCE is empty or does not exist - skipping" | tee -a "$LOG_FILE"
fi

# ============================================================================
# Step 2: Create filesystem directories from /vagrant_directories
# ============================================================================
echo "" | tee -a "$LOG_FILE"
echo "Step 2: Creating filesystem directories..." `date` | tee -a "$LOG_FILE"
echo "******************************************************************************" | tee -a "$LOG_FILE"

DIR_SOURCE="/vagrant_directories"
DIR_BASE="/u01/app/oracle/admin/directories"

# Create base directory
mkdir -p "$DIR_BASE"
chown oracle:oinstall "$DIR_BASE"
chmod 755 "$DIR_BASE"

# Check if source directory has any subdirectories
if [ -d "$DIR_SOURCE" ] && [ "$(ls -A "$DIR_SOURCE" 2>/dev/null)" ]; then
  DIR_COUNT=$(find "$DIR_SOURCE" -mindepth 1 -type d 2>/dev/null | wc -l)

  if [ "$DIR_COUNT" -gt 0 ]; then
    echo "Found $DIR_COUNT directory/directories to create" | tee -a "$LOG_FILE"

    # Create each subdirectory
    find "$DIR_SOURCE" -mindepth 1 -type d -print0 | while IFS= read -r -d '' dir; do
      # Get relative path from source
      rel_path="${dir#$DIR_SOURCE/}"
      dest_dir="$DIR_BASE/$rel_path"

      # Create directory
      mkdir -p "$dest_dir"
      chown oracle:oinstall "$dest_dir"
      chmod 755 "$dest_dir"

      echo "  Created directory: $dest_dir" | tee -a "$LOG_FILE"
    done

    echo "Filesystem directories created successfully" | tee -a "$LOG_FILE"

    # Copy files from each subdirectory
    echo "" | tee -a "$LOG_FILE"
    echo "Copying files from synced directories..." | tee -a "$LOG_FILE"

    FILE_COUNT=$(find "$DIR_SOURCE" -mindepth 1 -type f 2>/dev/null | wc -l)

    if [ "$FILE_COUNT" -gt 0 ]; then
      echo "Found $FILE_COUNT file(s) to copy" | tee -a "$LOG_FILE"

      find "$DIR_SOURCE" -mindepth 1 -type f -print0 | while IFS= read -r -d '' file; do
        # Get relative path from source
        rel_path="${file#$DIR_SOURCE/}"
        dest_file="$DIR_BASE/$rel_path"

        # Get file size for logging
        file_size=$(du -h "$file" | cut -f1)

        echo "  Copying: $rel_path ($file_size)" | tee -a "$LOG_FILE"

        # Copy file
        cp "$file" "$dest_file"
        chown oracle:oinstall "$dest_file"
        chmod 644 "$dest_file"
      done

      echo "Files copied successfully" | tee -a "$LOG_FILE"
    else
      echo "No files found to copy" | tee -a "$LOG_FILE"
    fi
  else
    echo "No subdirectories found in $DIR_SOURCE - skipping" | tee -a "$LOG_FILE"
  fi
else
  echo "Source directory $DIR_SOURCE is empty or does not exist - skipping" | tee -a "$LOG_FILE"
fi

# ============================================================================
# Step 3: Create Oracle DIRECTORY objects (Primary only)
# ============================================================================
echo "" | tee -a "$LOG_FILE"
echo "Step 3: Oracle DIRECTORY object creation..." `date` | tee -a "$LOG_FILE"
echo "******************************************************************************" | tee -a "$LOG_FILE"

# Skip database operations if Oracle is not running
if [ "$DB_IS_DOWN" = "true" ]; then
  echo "Skipping Oracle DIRECTORY creation - database is not running" | tee -a "$LOG_FILE"
  echo "Start the database and re-run this provisioner to create DIRECTORY objects" | tee -a "$LOG_FILE"
else
  # Detect if this is the primary database (run as oracle user)
  echo "Detecting database role..." | tee -a "$LOG_FILE"
  DB_ROLE=$(su - oracle -c "sqlplus -s / as sysdba <<EOF
SET HEADING OFF
SET FEEDBACK OFF
SET PAGESIZE 0
SELECT database_role FROM v\\\$database;
EXIT;
EOF
")

  DB_ROLE=$(echo "$DB_ROLE" | tr -d '[:space:]')

  echo "Database role: $DB_ROLE" | tee -a "$LOG_FILE"

  if [ "$DB_ROLE" = "PRIMARY" ]; then
  echo "" | tee -a "$LOG_FILE"
  echo "This is the PRIMARY database - creating Oracle DIRECTORY objects..." | tee -a "$LOG_FILE"
  echo "******************************************************************************" | tee -a "$LOG_FILE"

  # Only create DIRECTORY objects if we have directories
  if [ -d "$DIR_SOURCE" ] && [ "$(ls -A "$DIR_SOURCE" 2>/dev/null)" ]; then
    DIR_COUNT=$(find "$DIR_SOURCE" -mindepth 1 -type d 2>/dev/null | wc -l)

    if [ "$DIR_COUNT" -gt 0 ]; then
      # Generate SQL for creating DIRECTORY objects
      TEMP_SQL="/tmp/create_directories_$$.sql"

      echo "-- Auto-generated script to create Oracle DIRECTORY objects" > "$TEMP_SQL"
      echo "-- Generated on: $(date)" >> "$TEMP_SQL"
      echo "" >> "$TEMP_SQL"
      echo "ALTER SESSION SET CONTAINER=${PDB_NAME};" >> "$TEMP_SQL"
      echo "" >> "$TEMP_SQL"

      # Create DIRECTORY object for each subdirectory
      find "$DIR_SOURCE" -mindepth 1 -type d -print0 | while IFS= read -r -d '' dir; do
        # Get relative path and convert to directory name
        rel_path="${dir#$DIR_SOURCE/}"
        # Convert path to Oracle directory name (uppercase, replace / with _)
        dir_name=$(echo "$rel_path" | tr '[:lower:]/' '[:upper:]_' | sed 's/[^A-Z0-9_]/_/g')
        dest_dir="$DIR_BASE/$rel_path"

        echo "-- Directory: $rel_path" >> "$TEMP_SQL"
        echo "CREATE OR REPLACE DIRECTORY ${dir_name} AS '${dest_dir}';" >> "$TEMP_SQL"
        echo "GRANT READ, WRITE ON DIRECTORY ${dir_name} TO ${APP_SCHEMA};" >> "$TEMP_SQL"
        echo "" >> "$TEMP_SQL"

        echo "  Will create DIRECTORY: ${dir_name} => ${dest_dir}" | tee -a "$LOG_FILE"
      done

      echo "EXIT;" >> "$TEMP_SQL"

      # Execute the SQL script
      echo "" | tee -a "$LOG_FILE"
      echo "Executing Oracle DIRECTORY creation script..." | tee -a "$LOG_FILE"

      su - oracle -c "sqlplus -s / as sysdba @\"$TEMP_SQL\"" >> "$LOG_FILE" 2>&1

      if [ $? -eq 0 ]; then
        echo "Oracle DIRECTORY objects created successfully" | tee -a "$LOG_FILE"
        echo "Privileges granted to ${APP_SCHEMA}" | tee -a "$LOG_FILE"
      else
        echo "ERROR: Failed to create Oracle DIRECTORY objects - check $LOG_FILE" | tee -a "$LOG_FILE"
      fi

      # Clean up temp SQL file
      rm -f "$TEMP_SQL"

      # Force log archive to replicate to standby
      echo "" | tee -a "$LOG_FILE"
      echo "Forcing log archive to replicate changes to standby..." | tee -a "$LOG_FILE"
      su - oracle -c "sqlplus -s / as sysdba <<EOF
ALTER SYSTEM ARCHIVE LOG CURRENT;
EXIT;
EOF
" >> "$LOG_FILE" 2>&1
      echo "Log archive complete" | tee -a "$LOG_FILE"

    else
      echo "No directories to create - skipping Oracle DIRECTORY creation" | tee -a "$LOG_FILE"
    fi
  else
    echo "Source directory $DIR_SOURCE is empty - skipping Oracle DIRECTORY creation" | tee -a "$LOG_FILE"
  fi

  else
    echo "" | tee -a "$LOG_FILE"
    echo "This is a STANDBY database - skipping Oracle DIRECTORY creation" | tee -a "$LOG_FILE"
    echo "DIRECTORY objects will be replicated from primary via Data Guard" | tee -a "$LOG_FILE"
  fi
fi  # End of DB_IS_DOWN check

# ============================================================================
# Summary
# ============================================================================
echo "" | tee -a "$LOG_FILE"
echo "******************************************************************************" | tee -a "$LOG_FILE"
echo "Deployment complete!" `date` | tee -a "$LOG_FILE"
echo "******************************************************************************" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Summary:" | tee -a "$LOG_FILE"
echo "  - SQL scripts location: $SQL_DEST" | tee -a "$LOG_FILE"
echo "  - Filesystem directories: $DIR_BASE" | tee -a "$LOG_FILE"
echo "  - Database role: $DB_ROLE" | tee -a "$LOG_FILE"
echo "  - Log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

if [ "$DB_ROLE" = "PRIMARY" ]; then
  echo "To verify Oracle DIRECTORY objects, run:" | tee -a "$LOG_FILE"
  echo "  sqlplus ${APP_SCHEMA}/${APP_SCHEMA_PASSWORD}@localhost:1521/${PDB_NAME}" | tee -a "$LOG_FILE"
  echo "  SELECT directory_name, directory_path FROM all_directories ORDER BY directory_name;" | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"
