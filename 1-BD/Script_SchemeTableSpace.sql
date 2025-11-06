create user HC identified by password;
GRANT EXECUTE ON DBMS_CRYPTO TO HC;
GRANT create session to HC;
GRANT resource to HC;
GRANT connect to HC;
GRANT recovery_catalog_owner to HC;
GRANT SELECT ON DBA_DATA_FILES TO HC;
GRANT SELECT ON DBA_FREE_SPACE TO HC;
GRANT EXECUTE ON UTL_MAIL TO HC;
GRANT EXECUTE ON UTL_SMTP TO HC;
GRANT CREATE ROLE TO HC;
grant sysbackup to HC;
GRANT EXECUTE ON DBMS_SCHEDULER TO HC;
GRANT SCHEDULER_ADMIN TO HC;
GRANT CREATE USER TO HC;
GRANT GRANT ANY ROLE TO HC;
GRANT CREATE ANY DIRECTORY TO HC;
GRANT DROP ANY DIRECTORY TO HC;
GRANT CREATE VIEW TO HC;
GRANT Administrator TO HC WITH ADMIN OPTION;

create tablespace HC_TS datafile '/opt/oracle/oradata/hc_ts.DBF' SIZE 1g autoextend on next 100m MAXSIZE 5g;
alter user HC default tablespace HC_TS;
ALTER USER HC QUOTA UNLIMITED ON HC_TS;

select tablespace_name, file_name, bytes
from dba_data_files
where tablespace_name = 'HC_TS';