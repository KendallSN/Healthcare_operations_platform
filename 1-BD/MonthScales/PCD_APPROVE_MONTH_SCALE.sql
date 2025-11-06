CREATE OR REPLACE PROCEDURE PCD_APPROVE_MONTH_SCALE(
    p_msc_id IN NUMBER
) IS
    v_exist_count NUMBER := 0;
    v_updated_turns NUMBER := 0;
    v_current_state VARCHAR2(1);
BEGIN
    -- Verificar si existe el MonthScale
    BEGIN
    SELECT COUNT(*), MAX(MSC_state) 
        INTO v_exist_count, v_current_state
        FROM HC_MonthScale
        WHERE MSC_id = p_msc_id;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        v_exist_count := 0;
    END;

    IF v_exist_count = 0 THEN
    RAISE_APPLICATION_ERROR(-20002, 'MonthScale con MSC_id=' || p_msc_id || ' no existe.');
    END IF;

    -- Informar el estado actual
    DBMS_OUTPUT.PUT_LINE('MonthScale MSC_id=' || p_msc_id || ' tiene estado actual: ' || v_current_state);

    -- Actualizar estado del MonthScale a 'P' (Payment/Pendiente de Pago)
    UPDATE HC_MonthScale
        SET MSC_state = 'P'
    WHERE MSC_id = p_msc_id;

    DBMS_OUTPUT.PUT_LINE('Estado del MonthScale cambiado a: P (Pendiente de Pago)');

    -- Actualizar TurnXMonthScale con diferentes compliance (F=Full, PTL=Partial)
    -- Usamos MOD para distribuir: 70% Full, 30% Partial
    DECLARE
        v_full_count NUMBER := 0;
        v_partial_count NUMBER := 0;
        v_hours NUMBER;
        v_total_hours NUMBER;
    BEGIN
        FOR turn_rec IN (
            SELECT TMS_id, TMS_start_hour, TMS_end_hour, ROWNUM as row_num
            FROM HC_TurnXMonthScale
            WHERE MSC_id = p_msc_id
                AND TMS_compliance = 'PDG'
        ) LOOP
            -- Calcular horas totales del turno
            IF turn_rec.TMS_end_hour >= turn_rec.TMS_start_hour THEN
                v_total_hours := turn_rec.TMS_end_hour - turn_rec.TMS_start_hour;
            ELSE
                -- Turno cruza medianoche
                v_total_hours := (24 - turn_rec.TMS_start_hour) + turn_rec.TMS_end_hour;
            END IF;
            
            -- 70% de los turnos se marcan como cumplidos completamente (F)
            -- 30% se marcan como cumplidos parcialmente (PTL)
            IF MOD(turn_rec.row_num, 10) <= 6 THEN
                -- Compliance Full (F)
                UPDATE HC_TurnXMonthScale
                SET TMS_compliance = 'F',
                    TMS_partial_worked_hours = NULL
                WHERE TMS_id = turn_rec.TMS_id;
                
                v_full_count := v_full_count + 1;
            ELSE
                -- Compliance Partial (PTL)
                -- Asignar horas parciales aleatorias entre 50% y 90% de las horas totales
                -- Usamos MOD para simular diferentes porcentajes
                CASE MOD(turn_rec.row_num, 5)
                    WHEN 0 THEN v_hours := ROUND(v_total_hours * 0.50, 2); -- 50%
                    WHEN 1 THEN v_hours := ROUND(v_total_hours * 0.60, 2); -- 60%
                    WHEN 2 THEN v_hours := ROUND(v_total_hours * 0.70, 2); -- 70%
                    WHEN 3 THEN v_hours := ROUND(v_total_hours * 0.80, 2); -- 80%
                    ELSE v_hours := ROUND(v_total_hours * 0.90, 2); -- 90%
                END CASE;
                
                UPDATE HC_TurnXMonthScale
                SET TMS_compliance = 'PTL',
                    TMS_partial_worked_hours = v_hours
                WHERE TMS_id = turn_rec.TMS_id;
                
                v_partial_count := v_partial_count + 1;
            END IF;
            
            v_updated_turns := v_updated_turns + 1;
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE('Turnos actualizados:');
        DBMS_OUTPUT.PUT_LINE('  - Compliance Full (F): ' || v_full_count);
        DBMS_OUTPUT.PUT_LINE('  - Compliance Partial (PTL): ' || v_partial_count);
        DBMS_OUTPUT.PUT_LINE('  - Total: ' || v_updated_turns);
    END;

    COMMIT;

    -- Mensajes
    DBMS_OUTPUT.PUT_LINE('MonthScale MSC_id=' || p_msc_id || ' aprobado exitosamente.');

EXCEPTION
    WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
    RAISE;
END PCD_APPROVE_MONTH_SCALE;