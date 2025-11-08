-- Borrar el usuario dueño de las tablas
DROP USER HC_SCHEMA;
-- En caso de querer borrar todo el tablespace con los contenidos y datafiles
DROP TABLESPACE HC_TS INCLUDING CONTENTS AND DATAFILES CASCADE CONSTRAINTS;
-- 