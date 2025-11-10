-- Simple schema for testing Oracle Data Guard replication
-- This schema is designed to test:
--   1. Table replication
--   2. Sequence replication
--   3. Timestamp tracking for verifying data consistency
--   4. Basic DML operations (INSERT, UPDATE, DELETE)

-- ============================================================================
-- Test Tables
-- ============================================================================

-- Main test table with timestamp for replication verification
CREATE TABLE replication_test (
  id            NUMBER(10) PRIMARY KEY,
  test_name     VARCHAR2(100) NOT NULL,
  test_data     VARCHAR2(500),
  created_at    TIMESTAMP DEFAULT SYSTIMESTAMP,
  updated_at    TIMESTAMP DEFAULT SYSTIMESTAMP,
  created_on_db VARCHAR2(50) DEFAULT SYS_CONTEXT('USERENV', 'DB_UNIQUE_NAME')
);

-- Secondary test table for foreign key replication testing
CREATE TABLE replication_details (
  detail_id     NUMBER(10) PRIMARY KEY,
  test_id       NUMBER(10) NOT NULL,
  detail_info   VARCHAR2(200),
  recorded_at   TIMESTAMP DEFAULT SYSTIMESTAMP,
  CONSTRAINT fk_test FOREIGN KEY (test_id) REFERENCES replication_test(id) ON DELETE CASCADE
);

-- Simple audit log table
CREATE TABLE audit_log (
  log_id        NUMBER(10) PRIMARY KEY,
  operation     VARCHAR2(20),
  table_name    VARCHAR2(50),
  timestamp     TIMESTAMP DEFAULT SYSTIMESTAMP,
  db_name       VARCHAR2(50) DEFAULT SYS_CONTEXT('USERENV', 'DB_UNIQUE_NAME')
);

-- ============================================================================
-- Sequences
-- ============================================================================

CREATE SEQUENCE seq_replication_test
  START WITH 1
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;

CREATE SEQUENCE seq_replication_details
  START WITH 1
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;

CREATE SEQUENCE seq_audit_log
  START WITH 1
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;

-- ============================================================================
-- Triggers for automatic timestamp updates
-- ============================================================================

-- Trigger to update updated_at timestamp on replication_test
CREATE OR REPLACE TRIGGER trg_replication_test_update
BEFORE UPDATE ON replication_test
FOR EACH ROW
BEGIN
  :NEW.updated_at := SYSTIMESTAMP;
END;
/

-- ============================================================================
-- Simple test procedures
-- ============================================================================

-- Procedure to insert test data
CREATE OR REPLACE PROCEDURE insert_test_data(
  p_test_name   IN VARCHAR2,
  p_test_data   IN VARCHAR2 DEFAULT NULL,
  p_test_id     OUT NUMBER
) AS
BEGIN
  SELECT seq_replication_test.NEXTVAL INTO p_test_id FROM dual;

  INSERT INTO replication_test (id, test_name, test_data)
  VALUES (p_test_id, p_test_name, p_test_data);

  -- Log the operation
  INSERT INTO audit_log (log_id, operation, table_name)
  VALUES (seq_audit_log.NEXTVAL, 'INSERT', 'REPLICATION_TEST');

  COMMIT;
END;
/

-- ============================================================================
-- Insert sample test data
-- ============================================================================

-- Insert initial test records
INSERT INTO replication_test (id, test_name, test_data)
VALUES (seq_replication_test.NEXTVAL, 'Initial Test', 'Data Guard replication test - inserted during schema creation');

INSERT INTO replication_test (id, test_name, test_data)
VALUES (seq_replication_test.NEXTVAL, 'Timestamp Test', 'Verify timestamp replication: ' || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF3'));

-- Insert audit log entries
INSERT INTO audit_log (log_id, operation, table_name)
VALUES (seq_audit_log.NEXTVAL, 'SCHEMA_CREATE', 'ALL_TABLES');

INSERT INTO audit_log (log_id, operation, table_name)
VALUES (seq_audit_log.NEXTVAL, 'INITIAL_DATA', 'REPLICATION_TEST');

COMMIT;

-- ============================================================================
-- Display summary
-- ============================================================================

-- Display table counts
SELECT 'Tables created: ' || COUNT(*) AS status FROM user_tables;
SELECT 'Sequences created: ' || COUNT(*) AS status FROM user_sequences;
SELECT 'Test records: ' || COUNT(*) AS status FROM replication_test;

-- Display sample data
SELECT id, test_name, created_at, created_on_db FROM replication_test ORDER BY id;

PROMPT
PROMPT ========================================
PROMPT Simple schema deployment complete!
PROMPT ========================================
PROMPT
PROMPT To verify replication on standby:
PROMPT   1. Wait for log transport (check with verify_dataguard.sh)
PROMPT   2. On standby (read-only): SELECT * FROM dgtest.replication_test;
PROMPT   3. Compare timestamps and created_on_db values
PROMPT
PROMPT To test replication with new data on primary:
PROMPT   EXEC insert_test_data('My Test', 'Test data here');
PROMPT   SELECT * FROM replication_test ORDER BY created_at DESC;
PROMPT
