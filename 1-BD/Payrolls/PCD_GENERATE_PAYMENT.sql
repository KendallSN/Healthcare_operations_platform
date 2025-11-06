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

-- Calcular totales de ingresos y deducciones
SELECT NVL(SUM(PRM_amount), 0) INTO v_total_income
    FROM HC_PayrollMovement
WHERE USR_id = v_usr_id
    AND PRL_id = v_prl_id
    AND PRM_type = 'I';

SELECT NVL(SUM(PRM_amount), 0) INTO v_total_ded
    FROM HC_PayrollMovement
WHERE USR_id = v_usr_id
    AND PRL_id = v_prl_id
    AND PRM_type = 'D';

-- Obtener parámetros de correo
SELECT GP_value INTO v_sender_email
    FROM GeneralParameters
WHERE GP_name = 'SENDER_EMAIL';

SELECT GP_value INTO v_email_key
    FROM GeneralParameters
WHERE GP_name = 'EMAILKEY';

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
    pEmailKey      => FNC_DecryptEmailKey(v_email_key),
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
