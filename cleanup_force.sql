-- Desactiva FKs, trunca todas las tablas del esquema y vuelve a activar FKs
BEGIN FOR fk IN (
    SELECT
        table_name,
        constraint_name
    FROM
        user_constraints
    WHERE
        constraint_type = 'R'
) LOOP EXECUTE IMMEDIATE 'ALTER TABLE ' || fk.table_name || ' DISABLE CONSTRAINT ' || fk.constraint_name;

END LOOP;

FOR t IN (
    SELECT
        table_name
    FROM
        user_tables
) LOOP EXECUTE IMMEDIATE 'TRUNCATE TABLE ' || t.table_name;

END LOOP;

FOR fk IN (
    SELECT
        table_name,
        constraint_name
    FROM
        user_constraints
    WHERE
        constraint_type = 'R'
) LOOP EXECUTE IMMEDIATE 'ALTER TABLE ' || fk.table_name || ' ENABLE CONSTRAINT ' || fk.constraint_name;

END LOOP;

END;

/