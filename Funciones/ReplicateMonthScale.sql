CREATE OR REPLACE PROCEDURE GENERATE_MONTH_SCALE(
  p_month IN VARCHAR2,
  p_year  IN NUMBER,
  p_hcn_id IN NUMBER
) IS
  v_month_abbr  VARCHAR2(3);
  v_first_date  DATE;
  v_last_date   DATE;
  v_msc_id      NUMBER;
  v_exist_count NUMBER;
  v_inserted    NUMBER := 0;

  CURSOR c_pos IS
    SELECT PST_id,
           PST_name,
           PST_description,
           PST_day_of_week,
           TRN_id,
           USR_id,
           PST_base_hourly_price,
           PST_base_hourly_payment
      FROM HC_Position
     WHERE HCN_id = p_hcn_id
       AND TRN_id IS NOT NULL; -- sólo posiciones que ya tienen turno asignado

  v_pos_rec c_pos%ROWTYPE;
  v_date DATE;
BEGIN
  -- Normalizar mes a abreviatura de 3 letras en inglés (JAN..DEC)
  IF REGEXP_LIKE(TRIM(p_month),'^\d{1,2}$') THEN
    v_month_abbr := TO_CHAR(TO_DATE(TRIM(p_month),'MM'),'MON','NLS_DATE_LANGUAGE=ENGLISH');
  ELSE
    v_month_abbr := UPPER(SUBSTR(TRIM(p_month),1,3));
  END IF;

  -- Verificar si ya existe la escala para HCN/month/year
  SELECT COUNT(*) INTO v_exist_count
    FROM HC_MonthScale
   WHERE HCN_id = p_hcn_id
     AND MSC_month = v_month_abbr
     AND MSC_year = TO_CHAR(p_year);

  IF v_exist_count > 0 THEN
    RAISE_APPLICATION_ERROR(-20001,'MonthScale ya existe para ese healthcenter/mes/año.');
  END IF;

  -- Insertar MonthScale (el trigger rellenará MSC_id desde la secuencia)
  INSERT INTO HC_MonthScale (HCN_id, MSC_month, MSC_year, MSC_state, MSC_processed, version)
  VALUES (p_hcn_id, v_month_abbr, TO_CHAR(p_year), 'B', 'N', 1)
  RETURNING MSC_id INTO v_msc_id;

  -- Calcular primer y último día del mes
  v_first_date := TO_DATE('01-'||v_month_abbr||'-'||TO_CHAR(p_year),'DD-MON-YYYY','NLS_DATE_LANGUAGE=ENGLISH');
  v_last_date  := LAST_DAY(v_first_date);

  -- Recorrer posiciones del healthcenter y crear entradas por cada fecha del mes que coincida con el día de la semana
  OPEN c_pos;
  LOOP
    FETCH c_pos INTO v_pos_rec;
    EXIT WHEN c_pos%NOTFOUND;

    v_date := v_first_date;
    WHILE v_date <= v_last_date LOOP
      -- comparar abreviatura del día en inglés (MON,TUE,...)
      IF TO_CHAR(v_date,'DY','NLS_DATE_LANGUAGE=ENGLISH') = v_pos_rec.PST_day_of_week THEN
        INSERT INTO HC_TurnXMonthScale (
          MSC_id, TRN_id, TMS_compliance, TMS_partial_worked_hours, TMS_date,
          USR_id, TMS_hourly_price, TMS_hourly_payment, TSM_name,
          TSM_description, TMS_processed, version
        ) VALUES (
          v_msc_id,
          v_pos_rec.TRN_id,
          'PDG', -- pendiente por defecto
          NULL,
          v_date,
          v_pos_rec.USR_id,
          v_pos_rec.PST_base_hourly_price,
          v_pos_rec.PST_base_hourly_payment,
          v_pos_rec.PST_name,
          v_pos_rec.PST_description,
          'N',
          1
        );
        v_inserted := v_inserted + 1;
      END IF;
      v_date := v_date + 1;
    END LOOP;
  END LOOP;
  CLOSE c_pos;

  COMMIT;

  -- Mensaje resumido (se puede ver con DBMS_OUTPUT.ENABLE en cliente)
  DBMS_OUTPUT.PUT_LINE('MonthScale creada (MSC_id=' || v_msc_id || '). TurnXMonthScale insertados: ' || v_inserted);

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END GENERATE_MONTH_SCALE;
/