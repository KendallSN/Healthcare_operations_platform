CREATE OR REPLACE PROCEDURE PCD_GeneratePaymentPayroll (
p_prl_id IN NUMBER
) IS
v_exist_count       NUMBER := 0;
v_deposited         VARCHAR2(1);
v_authorized        VARCHAR2(1);
v_prl_month         VARCHAR2(10);
v_prl_year          VARCHAR2(10);
v_prt_name          VARCHAR2(500);
v_total_users       NUMBER := 0;
v_sent_count        NUMBER := 0;
v_failed_count      NUMBER := 0;
v_pru_ids           VARCHAR2(4000) := '';

CURSOR c_payroll_users IS
    SELECT PRU_id, USR_id
    FROM HC_PayrollXUser
    WHERE PRL_id = p_prl_id
    ORDER BY PRU_id;
    
BEGIN
-- Verificar si existe el Payroll
SELECT COUNT(*), MAX(PRL_deposited), MAX(PRL_authorized), MAX(PRL_month), MAX(PRL_year)
    INTO v_exist_count, v_deposited, v_authorized, v_prl_month, v_prl_year
    FROM HC_Payroll
WHERE PRL_id = p_prl_id;

IF v_exist_count = 0 THEN
    RAISE_APPLICATION_ERROR(-20004, 'Payroll con PRL_id=' || p_prl_id || ' no existe.');
END IF;

-- Obtener nombre del tipo de planilla
SELECT pt.PRT_name INTO v_prt_name
    FROM HC_Payroll p
    JOIN HC_PayrollType pt ON p.PRT_id = pt.PRT_id
WHERE p.PRL_id = p_prl_id;

-- Verificar si ya fue depositado
IF v_deposited = 'Y' THEN
    DBMS_OUTPUT.PUT_LINE('======================================');
    DBMS_OUTPUT.PUT_LINE('ADVERTENCIA: Payroll ya depositado');
    DBMS_OUTPUT.PUT_LINE('PRL_id: ' || p_prl_id);
    DBMS_OUTPUT.PUT_LINE('Tipo: ' || v_prt_name);
    DBMS_OUTPUT.PUT_LINE('Período: ' || v_prl_month || '/' || v_prl_year);
    DBMS_OUTPUT.PUT_LINE('Estado: Ya fue depositado (PRL_deposited = Y)');
    RETURN;
END IF;

-- Verificar si está autorizado
IF v_authorized = 'N' THEN
    RAISE_APPLICATION_ERROR(-20005, 'Payroll con PRL_id=' || p_prl_id || ' no está autorizado. Debe ejecutar PCD_ApprovePayroll primero.');
END IF;

-- Contar usuarios a procesar
SELECT COUNT(*) INTO v_total_users
    FROM HC_PayrollXUser
WHERE PRL_id = p_prl_id;

IF v_total_users = 0 THEN
    RAISE_APPLICATION_ERROR(-20006, 'No hay usuarios asociados al Payroll PRL_id=' || p_prl_id);
END IF;

DBMS_OUTPUT.PUT_LINE('======================================');
DBMS_OUTPUT.PUT_LINE('INICIANDO PROCESO DE DEPÓSITO Y NOTIFICACIÓN');
DBMS_OUTPUT.PUT_LINE('PRL_id: ' || p_prl_id);
DBMS_OUTPUT.PUT_LINE('Tipo: ' || v_prt_name);
DBMS_OUTPUT.PUT_LINE('Período: ' || v_prl_month || '/' || v_prl_year);
DBMS_OUTPUT.PUT_LINE('Total de usuarios a notificar: ' || v_total_users);
DBMS_OUTPUT.PUT_LINE('');

-- Procesar cada PayrollXUser
FOR rec IN c_payroll_users LOOP
    BEGIN
    -- Intentar enviar correo al usuario
    PCD_GeneratePayment(rec.PRU_id);
    
    v_sent_count := v_sent_count + 1;
    
    -- Agregar PRU_id a la lista
    IF v_pru_ids IS NOT NULL THEN
        v_pru_ids := v_pru_ids || ', ';
    END IF;
    v_pru_ids := v_pru_ids || TO_CHAR(rec.PRU_id);
    
    DBMS_OUTPUT.PUT_LINE('');
    
    EXCEPTION
    WHEN OTHERS THEN
        v_failed_count := v_failed_count + 1;
        DBMS_OUTPUT.PUT_LINE('!!! ERROR al procesar PRU_id=' || rec.PRU_id || ': ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('');
        -- Continuar con el siguiente usuario
    END;
END LOOP;

-- Verificar si hubo fallos
IF v_failed_count > 0 THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20007, 
    'Proceso abortado: ' || v_failed_count || ' de ' || v_total_users || 
    ' correos fallaron. No se marcó el payroll como depositado. Revise los errores anteriores.');
END IF;

-- Marcar el Payroll como depositado
UPDATE HC_Payroll
    SET PRL_deposited = 'Y'
WHERE PRL_id = p_prl_id;

COMMIT;

-- Resumen final
DBMS_OUTPUT.PUT_LINE('');
DBMS_OUTPUT.PUT_LINE('======================================');
DBMS_OUTPUT.PUT_LINE('PROCESO COMPLETADO EXITOSAMENTE');
DBMS_OUTPUT.PUT_LINE('PRL_id: ' || p_prl_id);
DBMS_OUTPUT.PUT_LINE('Tipo: ' || v_prt_name);
DBMS_OUTPUT.PUT_LINE('Período: ' || v_prl_month || '/' || v_prl_year);
DBMS_OUTPUT.PUT_LINE('--------------------------------------');
DBMS_OUTPUT.PUT_LINE('Correos enviados: ' || v_sent_count || ' de ' || v_total_users);
DBMS_OUTPUT.PUT_LINE('Correos fallidos: ' || v_failed_count);
DBMS_OUTPUT.PUT_LINE('Estado PRL_deposited: Y');
DBMS_OUTPUT.PUT_LINE('--------------------------------------');
DBMS_OUTPUT.PUT_LINE('PRU_ids notificados:');
DBMS_OUTPUT.PUT_LINE('  ' || v_pru_ids);

EXCEPTION
WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('======================================');
    DBMS_OUTPUT.PUT_LINE('ERROR CRÍTICO EN EL PROCESO');
    DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('Se hizo ROLLBACK de todos los cambios.');
    RAISE;
END PCD_GeneratePaymentPayroll;
/