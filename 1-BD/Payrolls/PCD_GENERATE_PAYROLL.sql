CREATE OR REPLACE PROCEDURE PCD_GENERATE_PAYROLL (
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

  CURSOR c_procs(p_usr NUMBER, p_from DATE, p_to DATE, p_hcn_id NUMBER) IS
    SELECT PCD_id, PCD_medic_revenue, PCD_name
      FROM HC_Procedure
      WHERE USR_id = p_usr
        AND PCD_date BETWEEN p_from AND p_to
        AND HCN_id = p_hcn_id
        AND PCD_processed = 'N';

  CURSOR c_turns(p_usr NUMBER, p_msc_id NUMBER) IS
    SELECT tms.TMS_id, tms.MSC_id, tms.TMS_date, tms.TMS_partial_worked_hours, tms.TMS_hourly_payment, 
          tms.TMS_hourly_price, tms.TMS_name, tms.TMS_start_hour, tms.TMS_end_hour, tms.TMS_compliance,
          tms.TMS_payment_type, tms.TMS_price_type, tms.TMS_full_payment, tms.TMS_full_price
      FROM HC_TurnXMonthScale tms
      JOIN HC_MonthScale ms ON tms.MSC_id = ms.MSC_id
      WHERE tms.USR_id = p_usr
        AND tms.MSC_id = p_msc_id
        AND tms.TMS_processed = 'N'
        AND NVL(tms.TMS_compliance,'X') != 'PDG';
  
  CURSOR c_pending_turns(p_msc_id NUMBER) IS
    SELECT COUNT(*) as pending_count
      FROM HC_TurnXMonthScale
      WHERE MSC_id = p_msc_id
        AND TMS_compliance = 'PDG';
  
  CURSOR c_monthscales IS
    SELECT MSC_id, HCN_id
      FROM HC_MonthScale
      WHERE MSC_month = v_month_abbr
        AND MSC_year = TO_CHAR(p_year)
        AND MSC_state = 'P';

  CURSOR c_auto_mvts IS
    SELECT m.MVT_id, m.MVT_amount, m.MVT_amount_type, m.MVT_type, m.MVT_name, 
          m.MVT_lower_limit, m.MVT_upper_limit
      FROM HC_MovementType m
      JOIN HC_MovementTypeXPayrollType mp ON mp.MVT_id = m.MVT_id
      WHERE m.MVT_automatic = 'Y'
        AND mp.PRT_id = p_prt_id;

  v_usr_rec    c_users%ROWTYPE;
  v_proc_rec   c_procs%ROWTYPE;
  v_turn_rec   c_turns%ROWTYPE;
  v_auto_rec   c_auto_mvts%ROWTYPE;
  v_msc_rec    c_monthscales%ROWTYPE;

  v_bank_acc   VARCHAR2(1000);
  v_pru_amount NUMBER := 0;
  v_hours      NUMBER;
  v_amt        NUMBER;
  v_total_income NUMBER;
  v_total_ded   NUMBER;
  v_base_sal   NUMBER := 0; -- añadido: salario base disponible en todo el procedimiento
  v_msc_count  NUMBER := 0; -- contador de MonthScales procesados
  v_pending_turns NUMBER := 0; -- contador de turnos pendientes (PDG)
  v_pru_ids    VARCHAR2(4000) := ''; -- IDs de PayrollXUser creados
  v_pru_id     NUMBER; -- ID individual de PayrollXUser
BEGIN
  -- normalizar mes a abreviatura MON en inglés
  IF REGEXP_LIKE(TRIM(p_month),'^\d{1,2}$') THEN
    v_month_abbr := TO_CHAR(TO_DATE(TRIM(p_month),'MM'),'MON','NLS_DATE_LANGUAGE=ENGLISH');
  ELSE
    v_month_abbr := UPPER(SUBSTR(TRIM(p_month),1,3));
  END IF;

  v_first_date := TO_DATE('01-'||v_month_abbr||'-'||TO_CHAR(p_year),'DD-MON-YYYY','NLS_DATE_LANGUAGE=ENGLISH');
  v_last_date  := LAST_DAY(v_first_date);

  -- Verificar si ya existe un payroll para ese mes/año/tipo
  DECLARE
    v_exist_count NUMBER := 0;
  BEGIN
    SELECT COUNT(*) INTO v_exist_count
      FROM HC_Payroll
      WHERE PRT_id = p_prt_id
        AND PRL_month = v_month_abbr
        AND PRL_year = TO_CHAR(p_year);
    
    IF v_exist_count > 0 THEN
      RAISE_APPLICATION_ERROR(-20001, 'Ya existe un Payroll para el tipo PRT_id=' || p_prt_id || 
                              ', mes=' || v_month_abbr || ', año=' || p_year || 
                              '. No se puede crear un duplicado.');
    END IF;
  END;

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

  -- Primero: Procesar todos los usuarios del payroll type (Procedimientos y Salarios Base)
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
      VALUES (v_usr_rec.USR_id, v_prl_id, 0, v_bank_acc, 'N', 1)
      RETURNING PRU_id INTO v_pru_id;
    
    -- Agregar PRU_id a la lista
    IF v_pru_ids IS NOT NULL AND LENGTH(v_pru_ids) > 0 THEN
      v_pru_ids := v_pru_ids || ', ' || TO_CHAR(v_pru_id);
    ELSE
      v_pru_ids := TO_CHAR(v_pru_id);
    END IF;

    IF v_usr_rec.USR_type = 'M' THEN
      -- Médicos: Procesar procedimientos del mes (sin filtrar por HCN_id)
      DECLARE
        CURSOR c_procs_all IS
          SELECT PCD_id, PCD_medic_revenue, PCD_name
            FROM HC_Procedure
            WHERE USR_id = v_usr_rec.USR_id
              AND PCD_date BETWEEN v_first_date AND v_last_date
              AND PCD_processed = 'N';
        v_proc_all c_procs_all%ROWTYPE;
      BEGIN
        OPEN c_procs_all;
        LOOP
          FETCH c_procs_all INTO v_proc_all;
          EXIT WHEN c_procs_all%NOTFOUND;

          v_amt := NVL(v_proc_all.PCD_medic_revenue,0);

          INSERT INTO HC_PayrollMovement (PRM_amount, PRM_amount_type, PRM_name, PRM_description, PRM_date, PRM_type, MVT_id, USR_id, PRL_id, version)
          VALUES (v_amt, 'A', 'Procedimiento: '||v_proc_all.PCD_name, 'Proc generada: '||v_proc_all.PCD_name, SYSDATE, 'I', NVL(v_mvt_proc,1), v_usr_rec.USR_id, v_prl_id, 1);

          -- Marcar procedimiento como procesado
          UPDATE HC_Procedure
            SET PCD_processed = 'Y'
            WHERE PCD_id = v_proc_all.PCD_id;

        END LOOP;
        CLOSE c_procs_all;
      END;

    ELSIF v_usr_rec.USR_type = 'A' THEN
      -- Administrativos: agregar salario base si existe
      BEGIN
        SELECT NVL(USR_base_salary,0) INTO v_base_sal FROM HC_User WHERE USR_id = v_usr_rec.USR_id;
        
        IF v_base_sal > 0 THEN
          INSERT INTO HC_PayrollMovement (PRM_amount, PRM_amount_type, PRM_name, PRM_description, PRM_date, PRM_type, MVT_id, USR_id, PRL_id, version)
          VALUES (v_base_sal, 'A', 'Salario base', 'Salario base mensual', SYSDATE, 'I', NVL(v_mvt_base,3), v_usr_rec.USR_id, v_prl_id, 1);
        END IF;
      EXCEPTION WHEN NO_DATA_FOUND THEN
        NULL;
      END;
    END IF;

  END LOOP;
  CLOSE c_users;

  -- Segundo: Procesar MonthScales con estado 'P' (solo para turnos)
  OPEN c_monthscales;
  LOOP
    FETCH c_monthscales INTO v_msc_rec;
    EXIT WHEN c_monthscales%NOTFOUND;
    
    v_msc_count := v_msc_count + 1;
    
    -- Verificar si hay turnos pendientes (PDG) en este MonthScale
    DECLARE
      v_pdg_count NUMBER := 0;
    BEGIN
      SELECT COUNT(*) INTO v_pdg_count
        FROM HC_TurnXMonthScale
        WHERE MSC_id = v_msc_rec.MSC_id
          AND TMS_compliance = 'PDG';
      
      IF v_pdg_count > 0 THEN
        v_pending_turns := v_pending_turns + v_pdg_count;
        DBMS_OUTPUT.PUT_LINE('ADVERTENCIA: MonthScale MSC_id='||v_msc_rec.MSC_id||' tiene '||v_pdg_count||' turno(s) con estado PDG (Pendiente). Estos turnos no serán procesados.');
      END IF;
    END;

    -- Procesar turnos de todos los usuarios médicos en este MonthScale
    OPEN c_users;
    LOOP
      FETCH c_users INTO v_usr_rec;
      EXIT WHEN c_users%NOTFOUND;

      IF v_usr_rec.USR_type = 'M' THEN
        -- Procesar Turns -> por cada TMS del MonthScale crear movimiento
        OPEN c_turns(v_usr_rec.USR_id, v_msc_rec.MSC_id);
        LOOP
          FETCH c_turns INTO v_turn_rec;
          EXIT WHEN c_turns%NOTFOUND;

          -- Calcular el monto según el tipo de pago (H=por hora, T=turno completo)
          DECLARE
            v_description VARCHAR2(1000);
            v_total_hours NUMBER;
          BEGIN
            IF v_turn_rec.TMS_payment_type = 'H' THEN
              -- Pago por hora: calcular horas trabajadas
              -- Primero calcular horas totales del turno
              IF v_turn_rec.TMS_end_hour >= v_turn_rec.TMS_start_hour THEN
                v_total_hours := v_turn_rec.TMS_end_hour - v_turn_rec.TMS_start_hour;
              ELSE
                -- Turno cruza medianoche
                v_total_hours := (24 - v_turn_rec.TMS_start_hour) + v_turn_rec.TMS_end_hour;
              END IF;
              
              IF v_turn_rec.TMS_partial_worked_hours IS NOT NULL AND v_turn_rec.TMS_compliance = 'PTL' THEN
                -- Compliance parcial: usar horas trabajadas parciales
                v_hours := v_turn_rec.TMS_partial_worked_hours;
                v_amt := NVL(v_hours,0) * NVL(v_turn_rec.TMS_hourly_payment,0);
                v_description := 'Turno: '||v_turn_rec.TMS_name||' - '||TO_CHAR(v_turn_rec.TMS_date,'YYYY-MM-DD')||
                                ' | PARCIAL: '||TO_CHAR(v_hours,'FM990.00')||' hrs de '||TO_CHAR(v_total_hours,'FM990.00')||
                                ' hrs × ₡'||TO_CHAR(v_turn_rec.TMS_hourly_payment,'FM999,999,990')||
                                ' = ₡'||TO_CHAR(v_amt,'FM999,999,990.00');
              ELSE
                -- Compliance completo: usar horas totales
                v_hours := v_total_hours;
                v_amt := NVL(v_hours,0) * NVL(v_turn_rec.TMS_hourly_payment,0);
                v_description := 'Turno: '||v_turn_rec.TMS_name||' - '||TO_CHAR(v_turn_rec.TMS_date,'YYYY-MM-DD')||
                                ' | COMPLETO: '||TO_CHAR(v_hours,'FM990.00')||' hrs × ₡'||
                                TO_CHAR(v_turn_rec.TMS_hourly_payment,'FM999,999,990')||
                                ' = ₡'||TO_CHAR(v_amt,'FM999,999,990.00');
              END IF;
            ELSE
              -- Pago por turno completo: usar el monto fijo
              v_amt := NVL(v_turn_rec.TMS_full_payment,0);
              v_description := 'Turno: '||v_turn_rec.TMS_name||' - '||TO_CHAR(v_turn_rec.TMS_date,'YYYY-MM-DD')||
                              ' | PAGO FIJO POR TURNO: ₡'||TO_CHAR(v_amt,'FM999,999,990.00');
            END IF;

            INSERT INTO HC_PayrollMovement (PRM_amount, PRM_amount_type, PRM_name, PRM_description, PRM_date, PRM_type, MVT_id, USR_id, PRL_id, version)
            VALUES (v_amt, 'A', 'Turno: '||TO_CHAR(v_turn_rec.TMS_date,'YYYY-MM-DD'), v_description, SYSDATE, 'I', NVL(v_mvt_turn,2), v_usr_rec.USR_id, v_prl_id, 1);
          END;

          -- Marcar TurnXMonthScale como procesado
          UPDATE HC_TurnXMonthScale
            SET TMS_processed = 'Y'
            WHERE TMS_id = v_turn_rec.TMS_id;

        END LOOP;
        CLOSE c_turns;
      END IF;

    END LOOP;
    CLOSE c_users;
    
    -- Marcar MonthScale como completado
    UPDATE HC_MonthScale
        SET MSC_state = 'C'
      WHERE MSC_id = v_msc_rec.MSC_id;

  END LOOP;
  CLOSE c_monthscales;

  -- Nota: Si no hay MonthScales, aún así se procesan procedimientos y salarios base
  -- No lanzamos error, solo informamos

  -- Aplicar movimientos automáticos y calcular totales para todos los usuarios
  OPEN c_users;
  LOOP
    FETCH c_users INTO v_usr_rec;
    EXIT WHEN c_users%NOTFOUND;

    -- Aplicar movimientos automáticos que correspondan a este payroll type
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

      -- Verificar si el movimiento automático debe aplicarse según los límites
      DECLARE
        v_apply_movement BOOLEAN := TRUE;
      BEGIN
        -- Si tiene lower_limit, los ingresos deben ser mayores
        IF v_auto_rec.MVT_lower_limit IS NOT NULL THEN
          IF v_total_income <= v_auto_rec.MVT_lower_limit THEN
            v_apply_movement := FALSE;
          END IF;
        END IF;

        -- Si tiene upper_limit, los ingresos deben ser menores
        IF v_auto_rec.MVT_upper_limit IS NOT NULL THEN
          IF v_total_income >= v_auto_rec.MVT_upper_limit THEN
            v_apply_movement := FALSE;
          END IF;
        END IF;

        -- Solo aplicar el movimiento si cumple los límites
        IF v_apply_movement THEN
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
        END IF;
      END;

    END LOOP;
    CLOSE c_auto_mvts;

    -- Calcular total neto y actualizar PRU_amount
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
  
  -- Mensajes
  DBMS_OUTPUT.PUT_LINE('======================================');
  DBMS_OUTPUT.PUT_LINE('Payroll creado:');
  DBMS_OUTPUT.PUT_LINE('  - PRL_id: ' || v_prl_id);
  DBMS_OUTPUT.PUT_LINE('  - PRT_id: ' || p_prt_id);
  DBMS_OUTPUT.PUT_LINE('  - Mes/Año: ' || v_month_abbr || '/' || p_year);
  DBMS_OUTPUT.PUT_LINE('  - MonthScales con turnos procesados: ' || v_msc_count);
  DBMS_OUTPUT.PUT_LINE('--------------------------------------');
  DBMS_OUTPUT.PUT_LINE('PayrollXUser creados (PRU_ids):');
  DBMS_OUTPUT.PUT_LINE('  ' || v_pru_ids);
  DBMS_OUTPUT.PUT_LINE('======================================');
  
  IF v_pending_turns > 0 THEN
    DBMS_OUTPUT.PUT_LINE('NOTA: Se encontraron '||v_pending_turns||' turno(s) con estado PDG (Pendiente) que no fueron procesados.');
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END PCD_GENERATE_PAYROLL;
/