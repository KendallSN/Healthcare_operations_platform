-- Desde sys como dba crear el esquema HC_SCHEMA que va a ser el dueño de las tablas y procedimientos
create user HC_SCHEMA identified by password;
GRANT EXECUTE ON DBMS_CRYPTO TO HC_SCHEMA;
GRANT create session to HC_SCHEMA;
GRANT resource to HC_SCHEMA;
GRANT connect to HC_SCHEMA;
GRANT recovery_catalog_owner to HC_SCHEMA;
GRANT SELECT ON DBA_DATA_FILES TO HC_SCHEMA;
GRANT SELECT ON DBA_FREE_SPACE TO HC_SCHEMA;
GRANT EXECUTE ON UTL_MAIL TO HC_SCHEMA;
GRANT EXECUTE ON UTL_SMTP TO HC_SCHEMA;
GRANT CREATE ROLE TO HC_SCHEMA;
GRANT SELECT ON DBA_ROLES TO HC_SCHEMA;
GRANT SELECT ON DBA_ROLES TO HC_SCHEMA;
GRANT SELECT ON DBA_ROLE_PRIVS TO HC_SCHEMA;
grant sysbackup to HC_SCHEMA;
GRANT EXECUTE ON DBMS_SCHEDULER TO HC_SCHEMA;
GRANT SCHEDULER_ADMIN TO HC_SCHEMA;
GRANT CREATE USER TO HC_SCHEMA;
GRANT GRANT ANY ROLE TO HC_SCHEMA;
GRANT CREATE ANY DIRECTORY TO HC_SCHEMA;
GRANT DROP ANY DIRECTORY TO HC_SCHEMA;
GRANT CREATE VIEW TO HC_SCHEMA;


-- Tambien desde sys como dba crear el tablespace principal para las tablas y procedimientos
create tablespace HC_TS datafile '/opt/oracle/oradata/hc_ts.DBF' SIZE 1g autoextend on next 100m MAXSIZE 5g;
alter user HC_SCHEMA default tablespace HC_TS;
ALTER USER HC_SCHEMA QUOTA UNLIMITED ON HC_TS;

-- Crear el usuario con privilegios de administrador (Solo usables al activarlos)
create user HC_ADMIN identificación by password
GRANT Administrator TO HC WITH ADMIN OPTION;

-- Comando para revisar si el tablespace HC_TS se hizo correctamente
select tablespace_name, file_name, bytes
from dba_data_files
where tablespace_name = 'HC_TS';