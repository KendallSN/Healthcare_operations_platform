CREATE OR REPLACE PROCEDURE PCD_UPDATE_ROLE_PASSWORD(p_new_password VARCHAR2) IS
    v_encrypted_password RAW(1000);
BEGIN
    -- Encripta la nueva contraseña
    v_encrypted_password := FNC_ENCRYPT(p_new_password);

    -- Cambia la contraseña de todos los roles existentes
    FOR r IN (SELECT role FROM dba_roles WHERE role IN ('ADMINISTRATOR', 'MEDIC', 'ADMINISTRATIVE')) LOOP
        EXECUTE IMMEDIATE 'ALTER ROLE ' || r.role || ' IDENTIFIED BY "' || p_new_password || '"';
    END LOOP;

    -- Actualiza la contraseña encriptada
    UPDATE GeneralParameters
    SET GP_value = v_encrypted_password
    WHERE GP_name = 'ROLE_PASSWORD';

    COMMIT;
END PCD_UPDATE_ROLE_PASSWORD;
/