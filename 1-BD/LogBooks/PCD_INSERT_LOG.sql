CREATE OR REPLACE PROCEDURE PCD_INSERT_LOG (
        p_table     IN VARCHAR2,
        p_attribute IN VARCHAR2,
        p_operation IN VARCHAR2,
        p_old_value IN VARCHAR2 DEFAULT NULL,
        p_new_value IN VARCHAR2 DEFAULT NULL
    ) IS
        v_roles  VARCHAR2(1000);
    BEGIN
        -- Obtener los roles del usuario actual
        BEGIN
        SELECT LISTAGG(GRANTED_ROLE, ', ') WITHIN GROUP (ORDER BY GRANTED_ROLE)
            INTO v_roles
            FROM USER_ROLE_PRIVS;
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_roles := '';
        END;

        -- Insertar en HC_Logbook
        INSERT INTO HC_Logbook (
        LBK_id,
        LBK_os_user,
        LBK_db_session_user,
        LBK_terminal,
        LBK_ip_address,
        LBK_module,
        LBK_roles,
        LBK_table,
        LBK_attribute,
        LBK_operation,
        LBK_old_value,
        LBK_new_value,
        LBK_date,
        LBK_host
        ) VALUES (
        1,
        SYS_CONTEXT('USERENV', 'OS_USER'),     
        SYS_CONTEXT('USERENV', 'SESSION_USER'),
        SYS_CONTEXT('USERENV', 'TERMINAL'),    
        SYS_CONTEXT('USERENV', 'IP_ADDRESS'),  
        SYS_CONTEXT('USERENV', 'MODULE'),      
        v_roles,                               
        UPPER(p_table),                        
        UPPER(p_attribute),                    
        UPPER(p_operation),                    
        p_old_value,                           
        p_new_value,                           
        SYSDATE,                               
        SYS_CONTEXT('USERENV', 'HOST')         
        );
        DBMS_OUTPUT.PUT_LINE('Registro de bitácora creado: ' || p_table || ' - ' || p_operation);

    EXCEPTION
        WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR al insertar en HC_Logbook: ' || SQLERRM);
    END PCD_INSERT_LOG;