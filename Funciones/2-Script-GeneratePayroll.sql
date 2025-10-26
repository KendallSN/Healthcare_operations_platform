CREATE OR REPLACE PROCEDURE GENERATE_PAYROLL (
  p_month  IN VARCHAR2,
  p_year   IN NUMBER,
  p_prt_id IN NUMBER
) IS
  v_month_abbr  VARCHAR2(3);
  v_first_date  DATE;
  v_last_date   DATE;
  v_prl_id      NUMBER;

  -- movement type ids
  v_mvt_proc    NUMBER;
  v_mvt_turn    NUMBER;
  v_mvt_base    NUMBER;

  CURSOR c_users IS
    SELECT USR_id, USR_type
      FROM HC_User
     WHERE PR_id = p_prt_id
       AND USR_approved = 'Y';

  CURSOR c_procs(p_usr NUMBER, p_from DATE, p_to DATE) IS
    SELECT PCD_id, PCD_medic_revenue, PCD_name
      FROM HC_Procedure
     WHERE USR_id = p_usr
       AND PCD_date BETWEEN p_from AND p_to;

  CURSOR c_turns(p_usr NUMBER, p_from DATE, p_to DATE) IS
    SELECT tms.TRN_id, tms.TMS_date, tms.TMS_partial_worked_hours, tms.TMS_hourly_payment, tms.TMS_hourly_price, tms.TSM_name
      FROM HC_TurnXMonthScale tms
     WHERE tms.USR_id = p_usr
       AND tms.TMS_date BETWEEN p_from AND p_to;

  CURSOR c_auto_mvts IS
    SELECT m.MVT_id, m.MVT_amount, m.MVT_amount_type, m.MVT_type, m.MVT_name
      FROM HC_MovementType m
      JOIN HC_MovementTypeXPayrollType mp ON mp.MVT_id = m.MVT_id
     WHERE m.MVT_automatic = 'Y'
       AND mp.PRT_id = p_prt_id;

  v_usr_rec    c_users%ROWTYPE;
  v_proc_rec   c_procs%ROWTYPE;
  v_turn_rec   c_turns%ROWTYPE;
  v_auto_rec   c_auto_mvts%ROWTYPE;

  v_bank_acc   VARCHAR2(1000);
  v_pru_amount NUMBER := 0;
  v_hours      NUMBER;
  v_amt        NUMBER;
  v_total_income NUMBER;
  v_total_ded   NUMBER;
  v_base_sal   NUMBER := 0; -- añadido: salario base disponible en todo el procedimiento
BEGIN
  -- normalizar mes a abreviatura MON en inglés
  IF REGEXP_LIKE(TRIM(p_month),'^\d{1,2}$') THEN
    v_month_abbr := TO_CHAR(TO_DATE(TRIM(p_month),'MM'),'MON','NLS_DATE_LANGUAGE=ENGLISH');
  ELSE
    v_month_abbr := UPPER(SUBSTR(TRIM(p_month),1,3));
  END IF;

  v_first_date := TO_DATE('01-'||v_month_abbr||'-'||TO_CHAR(p_year),'DD-MON-YYYY','NLS_DATE_LANGUAGE=ENGLISH');
  v_last_date  := LAST_DAY(v_first_date);

  -- obtener ids de movement types estándar (si existen) con manejo de excepciones
  BEGIN
    SELECT MVT_id INTO v_mvt_proc FROM HC_MovementType WHERE LOWER(MVT_name) LIKE '%proced%' AND ROWNUM = 1;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    v_mvt_proc := NULL;
  END;

  BEGIN
    SELECT MVT_id INTO v_mvt_turn FROM HC_MovementType WHERE LOWER(MVT_name) LIKE '%turno%' AND ROWNUM = 1;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    v_mvt_turn := NULL;
  END;

  BEGIN
    SELECT MVT_id INTO v_mvt_base FROM HC_MovementType WHERE LOWER(MVT_name) LIKE '%salario%' AND ROWNUM = 1;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    v_mvt_base := NULL;
  END;

  -- crear payroll
  INSERT INTO HC_Payroll (PRT_id, PRL_month, PRL_year, PRL_authorized, PRL_deposited, version)
  VALUES (p_prt_id, v_month_abbr, TO_CHAR(p_year), 'N', 'N', 1)
  RETURNING PRL_id INTO v_prl_id;

  -- recorrer usuarios del payroll type
  OPEN c_users;
  LOOP
    FETCH c_users INTO v_usr_rec;
    EXIT WHEN c_users%NOTFOUND;

    -- obtener cuenta principal (una de sus cuentas) para PRU_account_number
    BEGIN
      SELECT BAC_account_number INTO v_bank_acc
        FROM HC_BankAccount
       WHERE USR_id = v_usr_rec.USR_id
         AND ROWNUM = 1;
    EXCEPTION WHEN NO_DATA_FOUND THEN
      v_bank_acc := 'N/A';
    END;

    -- insertar relación payrollXuser
    INSERT INTO HC_PayrollXUser (USR_id, PRL_id, PRU_amount, PRU_account_number, PRU_notified, version)
      VALUES (v_usr_rec.USR_id, v_prl_id, 0, v_bank_acc, 'N', 1);

    -- reset counters
    v_pru_amount := 0;

    IF v_usr_rec.USR_type = 'M' THEN
      -- 1) Procedures -> un payrollmovement por procedimiento dentro del mes
      OPEN c_procs(v_usr_rec.USR_id, v_first_date, v_last_date);
      LOOP
        FETCH c_procs INTO v_proc_rec;
        EXIT WHEN c_procs%NOTFOUND;

        v_amt := NVL(v_proc_rec.PCD_medic_revenue,0);

        INSERT INTO HC_PayrollMovement (PRM_amount, PRM_amount_type, PRM_name, PRM_description, PRM_date, PRM_type, MVT_id, USR_id, PRL_id, version)
        VALUES (v_amt, 'A', 'Procedimiento: '||v_proc_rec.PCD_name, 'Proc generada: '||v_proc_rec.PCD_name, SYSDATE, 'I', NVL(v_mvt_proc,1), v_usr_rec.USR_id, v_prl_id, 1);

      END LOOP;
      CLOSE c_procs;

      -- 2) Turns -> por cada TMS del mes crear movimiento
      OPEN c_turns(v_usr_rec.USR_id, v_first_date, v_last_date);
      LOOP
        FETCH c_turns INTO v_turn_rec;
        EXIT WHEN c_turns%NOTFOUND;

        IF v_turn_rec.TMS_partial_worked_hours IS NOT NULL THEN
          v_hours := v_turn_rec.TMS_partial_worked_hours;
        ELSE
          -- intentar determinar horas completas desde tabla HC_Turn
          DECLARE
            v_trn_start NUMBER;
            v_trn_end   NUMBER;
          BEGIN
            SELECT TRN_start_hour, TRN_end_hour INTO v_trn_start, v_trn_end FROM HC_Turn WHERE TRN_id = v_turn_rec.TRN_id;
            -- calcular horas (considerando wrap a 24)
            IF v_trn_end >= v_trn_start THEN
              v_hours := v_trn_end - v_trn_start;
            ELSE
              v_hours := (24 - v_trn_start) + v_trn_end;
            END IF;
          EXCEPTION WHEN OTHERS THEN
            v_hours := 0;
          END;
        END IF;

        v_amt := NVL(v_hours,0) * NVL(v_turn_rec.TMS_hourly_payment,0);

        INSERT INTO HC_PayrollMovement (PRM_amount, PRM_amount_type, PRM_name, PRM_description, PRM_date, PRM_type, MVT_id, USR_id, PRL_id, version)
        VALUES (v_amt, 'A', 'Turno: '||TO_CHAR(v_turn_rec.TMS_date,'YYYY-MM-DD'), 'Turno: '||v_turn_rec.TSM_name||' - '||TO_CHAR(v_turn_rec.TMS_date,'YYYY-MM-DD'), SYSDATE, 'I', NVL(v_mvt_turn,2), v_usr_rec.USR_id, v_prl_id, 1);

      END LOOP;
      CLOSE c_turns;

    ELSIF v_usr_rec.USR_type = 'A' THEN
      -- Administrativos: agregar salario base si existe
      BEGIN
        SELECT NVL(USR_base_salary,0) INTO v_base_sal FROM HC_User WHERE USR_id = v_usr_rec.USR_id;
      EXCEPTION WHEN NO_DATA_FOUND THEN
        v_base_sal := 0;
      END;

      IF v_base_sal > 0 THEN
        INSERT INTO HC_PayrollMovement (PRM_amount, PRM_amount_type, PRM_name, PRM_description, PRM_date, PRM_type, MVT_id, USR_id, PRL_id, version)
        VALUES (v_base_sal, 'A', 'Salario base', 'Salario base mensual', SYSDATE, 'I', NVL(v_mvt_base,3), v_usr_rec.USR_id, v_prl_id, 1);
      END IF;
    END IF;

    -- 3) Aplicar movimientos automáticos que correspondan a este payroll type
    SELECT NVL(SUM(PRM_amount),0) INTO v_total_income
      FROM HC_PayrollMovement
     WHERE USR_id = v_usr_rec.USR_id
       AND PRL_id = v_prl_id
       AND PRM_type = 'I';

    SELECT NVL(SUM(PRM_amount),0) INTO v_total_ded
      FROM HC_PayrollMovement
     WHERE USR_id = v_usr_rec.USR_id
       AND PRL_id = v_prl_id
       AND PRM_type = 'D';

    OPEN c_auto_mvts;
    LOOP
      FETCH c_auto_mvts INTO v_auto_rec;
      EXIT WHEN c_auto_mvts%NOTFOUND;

      IF v_auto_rec.MVT_amount_type = 'P' THEN
        v_amt := ROUND(v_total_income * (NVL(v_auto_rec.MVT_amount,0) / 100),2);
      ELSE
        v_amt := NVL(v_auto_rec.MVT_amount,0);
      END IF;

      -- insertar movimiento automático (tipo I o D según MVT_type)
      INSERT INTO HC_PayrollMovement (PRM_amount, PRM_amount_type, PRM_name, PRM_description, PRM_date, PRM_type, MVT_id, USR_id, PRL_id, version)
      VALUES (v_amt,
              CASE WHEN v_auto_rec.MVT_amount_type = 'P' THEN 'P' ELSE 'A' END,
              'Auto: '||v_auto_rec.MVT_name,
              'Movimiento automático: '||v_auto_rec.MVT_name,
              SYSDATE,
              v_auto_rec.MVT_type,
              v_auto_rec.MVT_id,
              v_usr_rec.USR_id,
              v_prl_id,
              1);

    END LOOP;
    CLOSE c_auto_mvts;

    -- 4) Calcular total neto y actualizar PRU_amount
    SELECT NVL(SUM(PRM_amount),0) INTO v_total_income
      FROM HC_PayrollMovement
     WHERE USR_id = v_usr_rec.USR_id
       AND PRL_id = v_prl_id
       AND PRM_type = 'I';

    SELECT NVL(SUM(PRM_amount),0) INTO v_total_ded
      FROM HC_PayrollMovement
     WHERE USR_id = v_usr_rec.USR_id
       AND PRL_id = v_prl_id
       AND PRM_type = 'D';

    UPDATE HC_PayrollXUser
       SET PRU_amount = v_total_income - v_total_ded
     WHERE USR_id = v_usr_rec.USR_id
       AND PRL_id = v_prl_id;

  END LOOP;
  CLOSE c_users;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Payroll creado PRL_id='||v_prl_id||' para PRT_id='||p_prt_id||' mes='||v_month_abbr||'/'||p_year);
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END GENERATE_PAYROLL;
/