

-- TRIGGER PARA HC_Payroll

CREATE OR REPLACE TRIGGER TRG_LOGBOOK_UPDATE_PAYROLL
AFTER UPDATE ON HC_Payroll
FOR EACH ROW
DECLARE
    vAtributos VARCHAR2(4000);
    vValoresAnteriores VARCHAR2(4000);
    vValoresNuevos VARCHAR2(4000);
BEGIN
    vAtributos := '';
    vValoresAnteriores := '';
    vValoresNuevos := '';

    IF UPDATING THEN
        IF :OLD.PRL_month != :NEW.PRL_month THEN
            vAtributos := vAtributos || 'PRL_month, ';
            vValoresAnteriores := vValoresAnteriores || :OLD.PRL_month || ', ';
            vValoresNuevos := vValoresNuevos || :NEW.PRL_month || ', ';
        END IF;
        
        IF :OLD.PRL_year != :NEW.PRL_year THEN
            vAtributos := vAtributos || 'PRL_year, ';
            vValoresAnteriores := vValoresAnteriores || :OLD.PRL_year || ', ';
            vValoresNuevos := vValoresNuevos || :NEW.PRL_year || ', ';
        END IF;
        
        IF :OLD.PRL_authorized != :NEW.PRL_authorized THEN
            vAtributos := vAtributos || 'PRL_authorized, ';
            vValoresAnteriores := vValoresAnteriores || :OLD.PRL_authorized || ', ';
            vValoresNuevos := vValoresNuevos || :NEW.PRL_authorized || ', ';
        END IF;
        
        IF :OLD.PRL_deposited != :NEW.PRL_deposited THEN
            vAtributos := vAtributos || 'PRL_deposited, ';
            vValoresAnteriores := vValoresAnteriores || :OLD.PRL_deposited || ', ';
            vValoresNuevos := vValoresNuevos || :NEW.PRL_deposited || ', ';
        END IF;
        
        IF :OLD.PRT_id != :NEW.PRT_id THEN
            vAtributos := vAtributos || 'PRT_id, ';
            vValoresAnteriores := vValoresAnteriores || TO_CHAR(:OLD.PRT_id) || ', ';
            vValoresNuevos := vValoresNuevos || TO_CHAR(:NEW.PRT_id) || ', ';
        END IF;
        
        IF :OLD.version != :NEW.version THEN
            vAtributos := vAtributos || 'version, ';
            vValoresAnteriores := vValoresAnteriores || TO_CHAR(:OLD.version) || ', ';
            vValoresNuevos := vValoresNuevos || TO_CHAR(:NEW.version) || ', ';
        END IF;

        IF LENGTH(vAtributos) > 2 THEN
            vAtributos := SUBSTR(vAtributos, 1, LENGTH(vAtributos) - 2);
            vValoresAnteriores := SUBSTR(vValoresAnteriores, 1, LENGTH(vValoresAnteriores) - 2);
            vValoresNuevos := SUBSTR(vValoresNuevos, 1, LENGTH(vValoresNuevos) - 2);
        END IF;
    
        IF vAtributos IS NOT NULL THEN
            vAtributos := 'PRL_id, ' || vAtributos;
            vValoresAnteriores := TO_CHAR(:OLD.PRL_id) || ', ' || vValoresAnteriores;
            vValoresNuevos := TO_CHAR(:NEW.PRL_id) || ', ' || vValoresNuevos;
        
            PCD_INSERT_LOG(
                p_table     => 'HC_Payroll',
                p_attribute => vAtributos,
                p_operation => 'UPDATE',
                p_old_value => vValoresAnteriores,
                p_new_value => vValoresNuevos
            );
            
            DBMS_OUTPUT.PUT_LINE('Bitácora: HC_Payroll actualizado - PRL_id=' || :NEW.PRL_id);
        END IF;
    END IF;
END;
/


-- TRIGGER PARA HC_PayrollXUser

CREATE OR REPLACE TRIGGER TRG_LOGBOOK_UPDATE_PAYROLLXUSER
AFTER UPDATE ON HC_PayrollXUser
FOR EACH ROW
DECLARE
    vAtributos VARCHAR2(4000);
    vValoresAnteriores VARCHAR2(4000);
    vValoresNuevos VARCHAR2(4000);
BEGIN
    vAtributos := '';
    vValoresAnteriores := '';
    vValoresNuevos := '';

    IF UPDATING THEN
        IF :OLD.PRU_amount != :NEW.PRU_amount THEN
            vAtributos := vAtributos || 'PRU_amount, ';
            vValoresAnteriores := vValoresAnteriores || TO_CHAR(:OLD.PRU_amount) || ', ';
            vValoresNuevos := vValoresNuevos || TO_CHAR(:NEW.PRU_amount) || ', ';
        END IF;
        
        IF :OLD.PRU_account_number != :NEW.PRU_account_number THEN
            vAtributos := vAtributos || 'PRU_account_number, ';
            vValoresAnteriores := vValoresAnteriores || :OLD.PRU_account_number || ', ';
            vValoresNuevos := vValoresNuevos || :NEW.PRU_account_number || ', ';
        END IF;
        
        IF :OLD.PRU_notified != :NEW.PRU_notified THEN
            vAtributos := vAtributos || 'PRU_notified, ';
            vValoresAnteriores := vValoresAnteriores || :OLD.PRU_notified || ', ';
            vValoresNuevos := vValoresNuevos || :NEW.PRU_notified || ', ';
        END IF;
        
        IF :OLD.version != :NEW.version THEN
            vAtributos := vAtributos || 'version, ';
            vValoresAnteriores := vValoresAnteriores || TO_CHAR(:OLD.version) || ', ';
            vValoresNuevos := vValoresNuevos || TO_CHAR(:NEW.version) || ', ';
        END IF;

        IF LENGTH(vAtributos) > 2 THEN
            vAtributos := SUBSTR(vAtributos, 1, LENGTH(vAtributos) - 2);
            vValoresAnteriores := SUBSTR(vValoresAnteriores, 1, LENGTH(vValoresAnteriores) - 2);
            vValoresNuevos := SUBSTR(vValoresNuevos, 1, LENGTH(vValoresNuevos) - 2);
        END IF;
    
        IF vAtributos IS NOT NULL THEN
            vAtributos := 'USR_id, PRL_id, ' || vAtributos;
            vValoresAnteriores := TO_CHAR(:OLD.USR_id) || ', ' || TO_CHAR(:OLD.PRL_id) || ', ' || vValoresAnteriores;
            vValoresNuevos := TO_CHAR(:NEW.USR_id) || ', ' || TO_CHAR(:NEW.PRL_id) || ', ' || vValoresNuevos;
        
            PCD_INSERT_LOG(
                p_table     => 'HC_PayrollXUser',
                p_attribute => vAtributos,
                p_operation => 'UPDATE',
                p_old_value => vValoresAnteriores,
                p_new_value => vValoresNuevos
            );
            
            DBMS_OUTPUT.PUT_LINE('Bitácora: HC_PayrollXUser actualizado - USR_id=' || :NEW.USR_id || ', PRL_id=' || :NEW.PRL_id);
        END IF;
    END IF;
END;
/


-- TRIGGER PARA HC_PayrollMovement

CREATE OR REPLACE TRIGGER TRG_LOGBOOK_UPDATE_PAYROLLMOVEMENT
AFTER UPDATE ON HC_PayrollMovement
FOR EACH ROW
DECLARE
    vAtributos VARCHAR2(4000);
    vValoresAnteriores VARCHAR2(4000);
    vValoresNuevos VARCHAR2(4000);
BEGIN
    vAtributos := '';
    vValoresAnteriores := '';
    vValoresNuevos := '';

    IF UPDATING THEN
        IF :OLD.PRM_amount != :NEW.PRM_amount THEN
            vAtributos := vAtributos || 'PRM_amount, ';
            vValoresAnteriores := vValoresAnteriores || TO_CHAR(:OLD.PRM_amount) || ', ';
            vValoresNuevos := vValoresNuevos || TO_CHAR(:NEW.PRM_amount) || ', ';
        END IF;
        
        IF :OLD.PRM_amount_type != :NEW.PRM_amount_type THEN
            vAtributos := vAtributos || 'PRM_amount_type, ';
            vValoresAnteriores := vValoresAnteriores || :OLD.PRM_amount_type || ', ';
            vValoresNuevos := vValoresNuevos || :NEW.PRM_amount_type || ', ';
        END IF;
        
        IF :OLD.PRM_name != :NEW.PRM_name THEN
            vAtributos := vAtributos || 'PRM_name, ';
            vValoresAnteriores := vValoresAnteriores || :OLD.PRM_name || ', ';
            vValoresNuevos := vValoresNuevos || :NEW.PRM_name || ', ';
        END IF;
        
        IF :OLD.PRM_description != :NEW.PRM_description THEN
            vAtributos := vAtributos || 'PRM_description, ';
            vValoresAnteriores := vValoresAnteriores || :OLD.PRM_description || ', ';
            vValoresNuevos := vValoresNuevos || :NEW.PRM_description || ', ';
        END IF;
        
        IF :OLD.PRM_date != :NEW.PRM_date THEN
            vAtributos := vAtributos || 'PRM_date, ';
            vValoresAnteriores := vValoresAnteriores || TO_CHAR(:OLD.PRM_date, 'YYYY-MM-DD HH24:MI:SS') || ', ';
            vValoresNuevos := vValoresNuevos || TO_CHAR(:NEW.PRM_date, 'YYYY-MM-DD HH24:MI:SS') || ', ';
        END IF;
        
        IF :OLD.PRM_type != :NEW.PRM_type THEN
            vAtributos := vAtributos || 'PRM_type, ';
            vValoresAnteriores := vValoresAnteriores || :OLD.PRM_type || ', ';
            vValoresNuevos := vValoresNuevos || :NEW.PRM_type || ', ';
        END IF;
        
        IF NVL(:OLD.MVT_id, -1) != NVL(:NEW.MVT_id, -1) THEN
            vAtributos := vAtributos || 'MVT_id, ';
            vValoresAnteriores := vValoresAnteriores || TO_CHAR(:OLD.MVT_id) || ', ';
            vValoresNuevos := vValoresNuevos || TO_CHAR(:NEW.MVT_id) || ', ';
        END IF;
        
        IF :OLD.USR_id != :NEW.USR_id THEN
            vAtributos := vAtributos || 'USR_id, ';
            vValoresAnteriores := vValoresAnteriores || TO_CHAR(:OLD.USR_id) || ', ';
            vValoresNuevos := vValoresNuevos || TO_CHAR(:NEW.USR_id) || ', ';
        END IF;
        
        IF :OLD.PRL_id != :NEW.PRL_id THEN
            vAtributos := vAtributos || 'PRL_id, ';
            vValoresAnteriores := vValoresAnteriores || TO_CHAR(:OLD.PRL_id) || ', ';
            vValoresNuevos := vValoresNuevos || TO_CHAR(:NEW.PRL_id) || ', ';
        END IF;
        
        IF :OLD.version != :NEW.version THEN
            vAtributos := vAtributos || 'version, ';
            vValoresAnteriores := vValoresAnteriores || TO_CHAR(:OLD.version) || ', ';
            vValoresNuevos := vValoresNuevos || TO_CHAR(:NEW.version) || ', ';
        END IF;

        IF LENGTH(vAtributos) > 2 THEN
            vAtributos := SUBSTR(vAtributos, 1, LENGTH(vAtributos) - 2);
            vValoresAnteriores := SUBSTR(vValoresAnteriores, 1, LENGTH(vValoresAnteriores) - 2);
            vValoresNuevos := SUBSTR(vValoresNuevos, 1, LENGTH(vValoresNuevos) - 2);
        END IF;
    
        IF vAtributos IS NOT NULL THEN
            vAtributos := 'PRM_id, ' || vAtributos;
            vValoresAnteriores := TO_CHAR(:OLD.PRM_id) || ', ' || vValoresAnteriores;
            vValoresNuevos := TO_CHAR(:NEW.PRM_id) || ', ' || vValoresNuevos;
        
            PCD_INSERT_LOG(
                p_table     => 'HC_PayrollMovement',
                p_attribute => vAtributos,
                p_operation => 'UPDATE',
                p_old_value => vValoresAnteriores,
                p_new_value => vValoresNuevos
            );
            
            DBMS_OUTPUT.PUT_LINE('Bitácora: HC_PayrollMovement actualizado - PRM_id=' || :NEW.PRM_id);
        END IF;
    END IF;
END;
/


-- TRIGGER PARA HC_MonthScale

CREATE OR REPLACE TRIGGER TRG_LOGBOOK_UPDATE_MONTHSCALE
AFTER UPDATE ON HC_MonthScale
FOR EACH ROW
DECLARE
    vAtributos VARCHAR2(4000);
    vValoresAnteriores VARCHAR2(4000);
    vValoresNuevos VARCHAR2(4000);
BEGIN
    vAtributos := '';
    vValoresAnteriores := '';
    vValoresNuevos := '';

    IF UPDATING THEN
        IF :OLD.MSC_month != :NEW.MSC_month THEN
            vAtributos := vAtributos || 'MSC_month, ';
            vValoresAnteriores := vValoresAnteriores || :OLD.MSC_month || ', ';
            vValoresNuevos := vValoresNuevos || :NEW.MSC_month || ', ';
        END IF;
        
        IF :OLD.MSC_year != :NEW.MSC_year THEN
            vAtributos := vAtributos || 'MSC_year, ';
            vValoresAnteriores := vValoresAnteriores || :OLD.MSC_year || ', ';
            vValoresNuevos := vValoresNuevos || :NEW.MSC_year || ', ';
        END IF;
        
        IF :OLD.MSC_state != :NEW.MSC_state THEN
            vAtributos := vAtributos || 'MSC_state, ';
            vValoresAnteriores := vValoresAnteriores || :OLD.MSC_state || ', ';
            vValoresNuevos := vValoresNuevos || :NEW.MSC_state || ', ';
        END IF;
        
        IF :OLD.HCN_id != :NEW.HCN_id THEN
            vAtributos := vAtributos || 'HCN_id, ';
            vValoresAnteriores := vValoresAnteriores || TO_CHAR(:OLD.HCN_id) || ', ';
            vValoresNuevos := vValoresNuevos || TO_CHAR(:NEW.HCN_id) || ', ';
        END IF;
        
        IF :OLD.version != :NEW.version THEN
            vAtributos := vAtributos || 'version, ';
            vValoresAnteriores := vValoresAnteriores || TO_CHAR(:OLD.version) || ', ';
            vValoresNuevos := vValoresNuevos || TO_CHAR(:NEW.version) || ', ';
        END IF;

        IF LENGTH(vAtributos) > 2 THEN
            vAtributos := SUBSTR(vAtributos, 1, LENGTH(vAtributos) - 2);
            vValoresAnteriores := SUBSTR(vValoresAnteriores, 1, LENGTH(vValoresAnteriores) - 2);
            vValoresNuevos := SUBSTR(vValoresNuevos, 1, LENGTH(vValoresNuevos) - 2);
        END IF;
    
        IF vAtributos IS NOT NULL THEN
            vAtributos := 'MSC_id, ' || vAtributos;
            vValoresAnteriores := TO_CHAR(:OLD.MSC_id) || ', ' || vValoresAnteriores;
            vValoresNuevos := TO_CHAR(:NEW.MSC_id) || ', ' || vValoresNuevos;
        
            PCD_INSERT_LOG(
                p_table     => 'HC_MonthScale',
                p_attribute => vAtributos,
                p_operation => 'UPDATE',
                p_old_value => vValoresAnteriores,
                p_new_value => vValoresNuevos
            );
            
            DBMS_OUTPUT.PUT_LINE('Bitácora: HC_MonthScale actualizado - MSC_id=' || :NEW.MSC_id);
        END IF;
    END IF;
END;
/


-- TRIGGER PARA HC_TurnXMonthScale

CREATE OR REPLACE TRIGGER TRG_LOGBOOK_UPDATE_TURNXMONTHSCALE
AFTER UPDATE ON HC_TurnXMonthScale
FOR EACH ROW
DECLARE
    vAtributos VARCHAR2(4000);
    vValoresAnteriores VARCHAR2(4000);
    vValoresNuevos VARCHAR2(4000);
BEGIN
    vAtributos := '';
    vValoresAnteriores := '';
    vValoresNuevos := '';

    IF UPDATING THEN
        IF :OLD.TMS_compliance != :NEW.TMS_compliance THEN
            vAtributos := vAtributos || 'TMS_compliance, ';
            vValoresAnteriores := vValoresAnteriores || :OLD.TMS_compliance || ', ';
            vValoresNuevos := vValoresNuevos || :NEW.TMS_compliance || ', ';
        END IF;
        
        IF NVL(:OLD.TMS_partial_worked_hours, -1) != NVL(:NEW.TMS_partial_worked_hours, -1) THEN
            vAtributos := vAtributos || 'TMS_partial_worked_hours, ';
            vValoresAnteriores := vValoresAnteriores || TO_CHAR(:OLD.TMS_partial_worked_hours) || ', ';
            vValoresNuevos := vValoresNuevos || TO_CHAR(:NEW.TMS_partial_worked_hours) || ', ';
        END IF;
        
        IF :OLD.TMS_date != :NEW.TMS_date THEN
            vAtributos := vAtributos || 'TMS_date, ';
            vValoresAnteriores := vValoresAnteriores || TO_CHAR(:OLD.TMS_date, 'YYYY-MM-DD') || ', ';
            vValoresNuevos := vValoresNuevos || TO_CHAR(:NEW.TMS_date, 'YYYY-MM-DD') || ', ';
        END IF;
        
        IF :OLD.TMS_hourly_price != :NEW.TMS_hourly_price THEN
            vAtributos := vAtributos || 'TMS_hourly_price, ';
            vValoresAnteriores := vValoresAnteriores || TO_CHAR(:OLD.TMS_hourly_price) || ', ';
            vValoresNuevos := vValoresNuevos || TO_CHAR(:NEW.TMS_hourly_price) || ', ';
        END IF;
        
        IF :OLD.TMS_hourly_payment != :NEW.TMS_hourly_payment THEN
            vAtributos := vAtributos || 'TMS_hourly_payment, ';
            vValoresAnteriores := vValoresAnteriores || TO_CHAR(:OLD.TMS_hourly_payment) || ', ';
            vValoresNuevos := vValoresNuevos || TO_CHAR(:NEW.TMS_hourly_payment) || ', ';
        END IF;
        
        IF :OLD.TMS_name != :NEW.TMS_name THEN
            vAtributos := vAtributos || 'TMS_name, ';
            vValoresAnteriores := vValoresAnteriores || :OLD.TMS_name || ', ';
            vValoresNuevos := vValoresNuevos || :NEW.TMS_name || ', ';
        END IF;
        
        IF NVL(:OLD.TMS_description, 'NULL') != NVL(:NEW.TMS_description, 'NULL') THEN
            vAtributos := vAtributos || 'TMS_description, ';
            vValoresAnteriores := vValoresAnteriores || :OLD.TMS_description || ', ';
            vValoresNuevos := vValoresNuevos || :NEW.TMS_description || ', ';
        END IF;
        
        IF :OLD.TMS_processed != :NEW.TMS_processed THEN
            vAtributos := vAtributos || 'TMS_processed, ';
            vValoresAnteriores := vValoresAnteriores || :OLD.TMS_processed || ', ';
            vValoresNuevos := vValoresNuevos || :NEW.TMS_processed || ', ';
        END IF;
        
        IF :OLD.TMS_start_hour != :NEW.TMS_start_hour THEN
            vAtributos := vAtributos || 'TMS_start_hour, ';
            vValoresAnteriores := vValoresAnteriores || TO_CHAR(:OLD.TMS_start_hour) || ', ';
            vValoresNuevos := vValoresNuevos || TO_CHAR(:NEW.TMS_start_hour) || ', ';
        END IF;
        
        IF :OLD.TMS_end_hour != :NEW.TMS_end_hour THEN
            vAtributos := vAtributos || 'TMS_end_hour, ';
            vValoresAnteriores := vValoresAnteriores || TO_CHAR(:OLD.TMS_end_hour) || ', ';
            vValoresNuevos := vValoresNuevos || TO_CHAR(:NEW.TMS_end_hour) || ', ';
        END IF;
        
        IF :OLD.MSC_id != :NEW.MSC_id THEN
            vAtributos := vAtributos || 'MSC_id, ';
            vValoresAnteriores := vValoresAnteriores || TO_CHAR(:OLD.MSC_id) || ', ';
            vValoresNuevos := vValoresNuevos || TO_CHAR(:NEW.MSC_id) || ', ';
        END IF;
        
        IF :OLD.USR_id != :NEW.USR_id THEN
            vAtributos := vAtributos || 'USR_id, ';
            vValoresAnteriores := vValoresAnteriores || TO_CHAR(:OLD.USR_id) || ', ';
            vValoresNuevos := vValoresNuevos || TO_CHAR(:NEW.USR_id) || ', ';
        END IF;
        
        IF :OLD.version != :NEW.version THEN
            vAtributos := vAtributos || 'version, ';
            vValoresAnteriores := vValoresAnteriores || TO_CHAR(:OLD.version) || ', ';
            vValoresNuevos := vValoresNuevos || TO_CHAR(:NEW.version) || ', ';
        END IF;

        IF LENGTH(vAtributos) > 2 THEN
            vAtributos := SUBSTR(vAtributos, 1, LENGTH(vAtributos) - 2);
            vValoresAnteriores := SUBSTR(vValoresAnteriores, 1, LENGTH(vValoresAnteriores) - 2);
            vValoresNuevos := SUBSTR(vValoresNuevos, 1, LENGTH(vValoresNuevos) - 2);
        END IF;
    
        IF vAtributos IS NOT NULL THEN
            vAtributos := 'TMS_id, ' || vAtributos;
            vValoresAnteriores := TO_CHAR(:OLD.TMS_id) || ', ' || vValoresAnteriores;
            vValoresNuevos := TO_CHAR(:NEW.TMS_id) || ', ' || vValoresNuevos;
        
            PCD_INSERT_LOG(
                p_table     => 'HC_TurnXMonthScale',
                p_attribute => vAtributos,
                p_operation => 'UPDATE',
                p_old_value => vValoresAnteriores,
                p_new_value => vValoresNuevos
            );
            
            DBMS_OUTPUT.PUT_LINE('Bitácora: HC_TurnXMonthScale actualizado - TMS_id=' || :NEW.TMS_id);
        END IF;
    END IF;
END;
/


-- MENSAJES DE CONFIRMACIÓN

PROMPT
PROMPT =====================================================
PROMPT Triggers de bitácora creados exitosamente:
PROMPT - TRG_LOGBOOK_UPDATE_PAYROLL
PROMPT - TRG_LOGBOOK_UPDATE_PAYROLLXUSER
PROMPT - TRG_LOGBOOK_UPDATE_PAYROLLMOVEMENT
PROMPT - TRG_LOGBOOK_UPDATE_MONTHSCALE
PROMPT - TRG_LOGBOOK_UPDATE_TURNXMONTHSCALE
PROMPT =====================================================
PROMPT
