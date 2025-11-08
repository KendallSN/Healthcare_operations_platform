CREATE OR REPLACE PROCEDURE PCD_GENERATE_PAYMENT (
p_pru_id IN NUMBER
) IS
v_receiver_email VARCHAR2(500);
v_sender_email   VARCHAR2(500);
v_email_key      VARCHAR2(1000);
v_subject        VARCHAR2(500);
v_html_template  CLOB;
v_html_final     CLOB;

-- Variables del usuario
v_usr_id         NUMBER;
v_usr_name       VARCHAR2(500);
v_usr_email      VARCHAR2(500);
v_usr_identification VARCHAR2(100);

-- Variables del payroll
v_prl_id         NUMBER;
v_prl_month      VARCHAR2(10);
v_prl_year       VARCHAR2(10);
v_prt_name       VARCHAR2(500);

-- Variables del PayrollXUser
v_pru_amount     NUMBER;
v_pru_account    VARCHAR2(1000);
v_pru_notified   VARCHAR2(1);

-- Calcular ingresos y deducciones
v_total_income   NUMBER := 0;
v_total_ded      NUMBER := 0;

-- Variables para desglose de movimientos
v_income_detail  CLOB := '';
v_deduction_detail CLOB := '';

v_exist_count    NUMBER := 0;

BEGIN
-- Verificar que existe el PayrollXUser
SELECT COUNT(*) INTO v_exist_count
    FROM HC_PayrollXUser
WHERE PRU_id = p_pru_id;

IF v_exist_count = 0 THEN
    RAISE_APPLICATION_ERROR(-20002, 'PayrollXUser con PRU_id=' || p_pru_id || ' no existe.');
END IF;

-- Obtener información del PayrollXUser, Payroll y User
SELECT 
    pru.USR_id,
    pru.PRL_id,
    pru.PRU_amount,
    pru.PRU_account_number,
    pru.PRU_notified,
    u.USR_email,
    u.USR_f_name || ' ' || u.USR_f_lastname || ' ' || NVL(u.USR_s_lastname, ''),
    u.USR_identification,
    p.PRL_month,
    p.PRL_year,
    pt.PRT_name,
    pt.PRT_html
INTO
    v_usr_id,
    v_prl_id,
    v_pru_amount,
    v_pru_account,
    v_pru_notified,
    v_usr_email,
    v_usr_name,
    v_usr_identification,
    v_prl_month,
    v_prl_year,
    v_prt_name,
    v_html_template
FROM HC_PayrollXUser pru
JOIN HC_User u ON pru.USR_id = u.USR_id
JOIN HC_Payroll p ON pru.PRL_id = p.PRL_id
JOIN HC_PayrollType pt ON p.PRT_id = pt.PRT_id
WHERE pru.PRU_id = p_pru_id;

-- Verificar si ya fue notificado
IF v_pru_notified = 'Y' THEN
    DBMS_OUTPUT.PUT_LINE('ADVERTENCIA: El usuario ' || v_usr_name || ' ya fue notificado anteriormente para este payroll.');
END IF;

-- Calcular totales y desglose de ingresos
FOR mov_inc IN (
    SELECT 
        mt.MVT_name,
        COUNT(*) as cantidad,
        SUM(pm.PRM_amount) as total_tipo
    FROM HC_PayrollMovement pm
    JOIN HC_MovementType mt ON pm.MVT_id = mt.MVT_id
    WHERE pm.USR_id = v_usr_id
        AND pm.PRL_id = v_prl_id
        AND pm.PRM_type = 'I'
    GROUP BY mt.MVT_name
    ORDER BY SUM(pm.PRM_amount) DESC
) LOOP
    v_total_income := v_total_income + mov_inc.total_tipo;
    v_income_detail := v_income_detail || 
        '<div style="margin:5px 0;padding:8px;background:#f0f9ff;border-radius:4px">' ||
        '<strong>' || mov_inc.MVT_name || '</strong>: ' ||
        mov_inc.cantidad || ' movimiento(s) = &#8353; ' || 
        TO_CHAR(mov_inc.total_tipo, 'FM999,999,990.00') ||
        '</div>';
END LOOP;

-- Calcular totales y desglose de deducciones
FOR mov_ded IN (
    SELECT 
        mt.MVT_name,
        COUNT(*) as cantidad,
        SUM(pm.PRM_amount) as total_tipo
    FROM HC_PayrollMovement pm
    JOIN HC_MovementType mt ON pm.MVT_id = mt.MVT_id
    WHERE pm.USR_id = v_usr_id
        AND pm.PRL_id = v_prl_id
        AND pm.PRM_type = 'D'
    GROUP BY mt.MVT_name
    ORDER BY SUM(pm.PRM_amount) DESC
) LOOP
    v_total_ded := v_total_ded + mov_ded.total_tipo;
    v_deduction_detail := v_deduction_detail || 
        '<div style="margin:5px 0;padding:8px;background:#fff3f3;border-radius:4px">' ||
        '<strong>' || mov_ded.MVT_name || '</strong>: ' ||
        mov_ded.cantidad || ' movimiento(s) = &#8353; ' || 
        TO_CHAR(mov_ded.total_tipo, 'FM999,999,990.00') ||
        '</div>';
END LOOP;

-- Si no hay detalles, mostrar mensaje
IF v_income_detail IS NULL OR LENGTH(v_income_detail) = 0 THEN
    v_income_detail := '<div style="margin:5px 0;padding:8px;color:#666">No hay movimientos de ingreso</div>';
END IF;

IF v_deduction_detail IS NULL OR LENGTH(v_deduction_detail) = 0 THEN
    v_deduction_detail := '<div style="margin:5px 0;padding:8px;color:#666">No hay movimientos de deducción</div>';
END IF;

-- Obtener parámetros de correo
SELECT GP_value INTO v_sender_email
    FROM GeneralParameters
WHERE GP_name = 'SENDER_EMAIL';

SELECT GP_value INTO v_email_key
    FROM GeneralParameters
WHERE GP_name = 'EMAIL_KEY';

-- Configurar destinatario y asunto
v_receiver_email := v_usr_email;
v_subject := 'Detalle de Planilla - ' || v_prl_month || '/' || v_prl_year || ' - ' || v_prt_name;
-- Reemplazar variables en el HTML
v_html_final := v_html_template;
v_html_final := REPLACE(v_html_final, '{{USR_NAME}}', v_usr_name);
v_html_final := REPLACE(v_html_final, '{{USR_IDENTIFICATION}}', v_usr_identification);
v_html_final := REPLACE(v_html_final, '{{USR_EMAIL}}', v_usr_email);
v_html_final := REPLACE(v_html_final, '{{PRL_MONTH}}', v_prl_month);
v_html_final := REPLACE(v_html_final, '{{PRL_YEAR}}', v_prl_year);
v_html_final := REPLACE(v_html_final, '{{PRT_NAME}}', v_prt_name);
v_html_final := REPLACE(v_html_final, '{{PRU_AMOUNT}}', '&#8353; ' || TO_CHAR(v_pru_amount, 'FM999,999,990.00'));
v_html_final := REPLACE(v_html_final, '{{PRU_ACCOUNT}}', v_pru_account);
v_html_final := REPLACE(v_html_final, '{{TOTAL_INCOME}}', '&#8353; ' || TO_CHAR(v_total_income, 'FM999,999,990.00'));
v_html_final := REPLACE(v_html_final, '{{TOTAL_DEDUCTIONS}}', '&#8353; ' || TO_CHAR(v_total_ded, 'FM999,999,990.00'));
v_html_final := REPLACE(v_html_final, '{{INCOME_DETAIL}}', v_income_detail);
v_html_final := REPLACE(v_html_final, '{{DEDUCTION_DETAIL}}', v_deduction_detail);
v_html_final := REPLACE(v_html_final, '{{PRL_ID}}', TO_CHAR(v_prl_id));
v_html_final := REPLACE(v_html_final, '{{PRU_ID}}', TO_CHAR(p_pru_id));

-- Enviar correo
DBMS_OUTPUT.PUT_LINE('======================================');
DBMS_OUTPUT.PUT_LINE('Enviando correo de planilla');
DBMS_OUTPUT.PUT_LINE('======================================');
DBMS_OUTPUT.PUT_LINE('Destinatario: ' || v_receiver_email);
DBMS_OUTPUT.PUT_LINE('Usuario: ' || v_usr_name);
DBMS_OUTPUT.PUT_LINE('Período: ' || v_prl_month || '/' || v_prl_year);
DBMS_OUTPUT.PUT_LINE('Monto neto: ₡' || TO_CHAR(v_pru_amount, 'FM999,999,990.00'));
DBMS_OUTPUT.PUT_LINE('--------------------------------------');

PKG_EMAILS.PCD_SEND_EMAIL(
    pReceiverEmail => v_receiver_email,
    pSenderEmail   => v_sender_email,
    pEmailKey      => FNC_DECRYPT(v_email_key),
    pSubject       => v_subject,
    pHTML          => v_html_final
);

-- Actualizar estado de notificación
UPDATE HC_PayrollXUser
    SET PRU_notified = 'Y'
WHERE PRU_id = p_pru_id;

COMMIT;

DBMS_OUTPUT.PUT_LINE('Correo enviado exitosamente.');
DBMS_OUTPUT.PUT_LINE('Estado PRU_notified actualizado a Y.');
DBMS_OUTPUT.PUT_LINE('======================================');

EXCEPTION
WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('ERROR: No se encontró información necesaria.');
    RAISE;
WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('ERROR al enviar correo: ' || SQLERRM);
    RAISE;
END PCD_GENERATE_PAYMENT;
/
