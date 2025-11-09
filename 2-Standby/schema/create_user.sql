-- Create simple test user for Data Guard testing
-- Uses default tablespace (no custom tablespace needed)
-- This script is called from deploy_custom_schema.sh with password substitution

-- Drop user if exists (for redeployment)
BEGIN
  EXECUTE IMMEDIATE 'DROP USER dgtest CASCADE';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -1918 THEN  -- ORA-01918: user does not exist
      RAISE;
    END IF;
END;
/

-- Create user with default tablespace
CREATE USER dgtest IDENTIFIED BY password
  DEFAULT TABLESPACE users
  TEMPORARY TABLESPACE temp
  QUOTA UNLIMITED ON users;

-- Grant necessary privileges
GRANT CONNECT, RESOURCE TO dgtest;
GRANT CREATE SESSION TO dgtest;
GRANT CREATE TABLE TO dgtest;
GRANT CREATE SEQUENCE TO dgtest;
GRANT CREATE VIEW TO dgtest;
GRANT CREATE PROCEDURE TO dgtest;

-- Display confirmation
SELECT 'User dgtest created successfully' AS status FROM dual;
