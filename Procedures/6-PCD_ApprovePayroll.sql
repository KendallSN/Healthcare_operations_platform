CREATE OR REPLACE PROCEDURE PCD_ApprovePayroll (
  p_prl_id IN NUMBER
) IS
  v_exist_count NUMBER := 0;
  v_authorized VARCHAR2(1);
  v_prl_month VARCHAR2(10);
  v_prl_year VARCHAR2(10);
  v_prt_name VARCHAR2(500);
BEGIN
  -- Verificar si existe el Payroll
  SELECT COUNT(*), MAX(PRL_authorized), MAX(PRL_month), MAX(PRL_year)
    INTO v_exist_count, v_authorized, v_prl_month, v_prl_year
    FROM HC_Payroll
   WHERE PRL_id = p_prl_id;

  IF v_exist_count = 0 THEN
    RAISE_APPLICATION_ERROR(-20003, 'Payroll con PRL_id=' || p_prl_id || ' no existe.');
  END IF;

  -- Obtener nombre del tipo de planilla
  SELECT pt.PRT_name INTO v_prt_name
    FROM HC_Payroll p
    JOIN HC_PayrollType pt ON p.PRT_id = pt.PRT_id
   WHERE p.PRL_id = p_prl_id;

  -- Verificar si ya está autorizado
  IF v_authorized = 'Y' THEN
    DBMS_OUTPUT.PUT_LINE('======================================');
    DBMS_OUTPUT.PUT_LINE('ADVERTENCIA: Payroll ya autorizado');
    DBMS_OUTPUT.PUT_LINE('PRL_id: ' || p_prl_id);
    DBMS_OUTPUT.PUT_LINE('Tipo: ' || v_prt_name);
    DBMS_OUTPUT.PUT_LINE('Período: ' || v_prl_month || '/' || v_prl_year);
    DBMS_OUTPUT.PUT_LINE('Estado: Ya está autorizado (PRL_authorized = Y)');
    RETURN;
  END IF;

  -- Autorizar el Payroll
  UPDATE HC_Payroll
     SET PRL_authorized = 'Y'
   WHERE PRL_id = p_prl_id;

  COMMIT;

  DBMS_OUTPUT.PUT_LINE('======================================');
  DBMS_OUTPUT.PUT_LINE('Payroll autorizado exitosamente');
  DBMS_OUTPUT.PUT_LINE('PRL_id: ' || p_prl_id);
  DBMS_OUTPUT.PUT_LINE('Tipo: ' || v_prt_name);
  DBMS_OUTPUT.PUT_LINE('Período: ' || v_prl_month || '/' || v_prl_year);
  DBMS_OUTPUT.PUT_LINE('Estado: PRL_authorized cambiado a Y');

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('ERROR al autorizar payroll: ' || SQLERRM);
    RAISE;
END PCD_ApprovePayroll;
/