-- Restart the sequences 
SET DEFINE OFF;
BEGIN
  FOR seq IN (
    SELECT column_value seq_name FROM TABLE(sys.odcivarchar2list(
      'SEQ_HC_BAC_id','SEQ_HC_HCN_id','SEQ_HC_MSC_id','SEQ_HC_PRL_id','SEQ_HC_PRM_id',
      'SEQ_HC_PRT_id','SEQ_HC_PMS_id','SEQ_HC_PST_id','SEQ_HC_PCD_id','SEQ_HC_PRF_id',
      'SEQ_HC_RDC_id','SEQ_HC_SCN_id','SEQ_HC_TRN_id','SEQ_HC_USR_id','SEQ_HC_BNE_id',
      'SEQ_HC_DOT_id','SEQ_HC_BSC_id','SEQ_HC_PCT_id','SEQ_HC_MVT_id'
    ))
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP SEQUENCE ' || seq.seq_name;
    EXCEPTION WHEN OTHERS THEN
      NULL; -- ignora si no existe
    END;
    EXECUTE IMMEDIATE
      'CREATE SEQUENCE ' || seq.seq_name ||
      ' INCREMENT BY 1 START WITH 1 NOMAXVALUE MINVALUE 1 NOCACHE';
  END LOOP;
END;
/
-- Bank entities
INSERT INTO HC_BankEntity (BNE_id, BNE_name, version) VALUES (1, 'Banco Central', 1);
INSERT INTO HC_BankEntity (BNE_id, BNE_name, version) VALUES (2, 'Banco Norte', 1);
INSERT INTO HC_BankEntity (BNE_id, BNE_name, version) VALUES (3, 'Banco Sur', 1);

-- Health centers
INSERT INTO HC_HealthCenter (HCN_id, HCN_name, HCN_location, HCN_phone_number, version) VALUES (1, 'Clinica Norte', 'Av. 1 #123', '+571234567', 1);
INSERT INTO HC_HealthCenter (HCN_id, HCN_name, HCN_location, HCN_phone_number, version) VALUES (2, 'Centro Salud Central', 'Calle 2 #45', '+571112233', 1);
INSERT INTO HC_HealthCenter (HCN_id, HCN_name, HCN_location, HCN_phone_number, version) VALUES (3, 'Unidad Sur', 'Transversal 3 #67', '+571998877', 1);

-- Turns
INSERT INTO HC_Turn (TRN_id, TRN_start_hour, TRN_end_hour) VALUES (1, 8, 14);
INSERT INTO HC_Turn (TRN_id, TRN_start_hour, TRN_end_hour) VALUES (2, 14, 20);

-- Profiles
INSERT INTO HC_Profile (PRF_id, PRF_name, PRF_description, version) VALUES (1, 'Admin', 'Administrador', 1);
INSERT INTO HC_Profile (PRF_id, PRF_name, PRF_description, version) VALUES (2, 'Medic', 'Medico general', 1);
INSERT INTO HC_Profile (PRF_id, PRF_name, PRF_description, version) VALUES (3, 'Staff', 'Administrativo', 1);

-- Screens (use explicit ids so FK_SCN_id matches)
INSERT INTO HC_Screen (SCN_id, SCN_name, FK_SCN_id, version) VALUES (1, 'Dashboard', NULL, 1);
INSERT INTO HC_Screen (SCN_id, SCN_name, FK_SCN_id, version) VALUES (2, 'Turnos', 1, 1);
INSERT INTO HC_Screen (SCN_id, SCN_name, FK_SCN_id, version) VALUES (3, 'Usuarios', 1, 1);

-- Permissions
INSERT INTO HC_Permission (PMS_id, PMS_name, PMS_description, version) VALUES (1, 'VIEW', 'Ver', 1);
INSERT INTO HC_Permission (PMS_id, PMS_name, PMS_description, version) VALUES (2, 'EDIT', 'Editar', 1);
INSERT INTO HC_Permission (PMS_id, PMS_name, PMS_description, version) VALUES (3, 'ADMIN', 'Administrar', 1);
INSERT INTO HC_Permission (PMS_id, PMS_name, PMS_description, version) VALUES (4, 'CREATE', 'Crear', 1);
INSERT INTO HC_Permission (PMS_id, PMS_name, PMS_description, version) VALUES (5, 'DELETE', 'Eliminar', 1);
INSERT INTO HC_Permission (PMS_id, PMS_name, PMS_description, version) VALUES (6, 'EXPORT', 'Exportar', 1);

-- PermissionXScreen
INSERT INTO HC_PermissionXScreen (SCN_id, PMS_id) VALUES (1, 1);
INSERT INTO HC_PermissionXScreen (SCN_id, PMS_id) VALUES (1, 3);
INSERT INTO HC_PermissionXScreen (SCN_id, PMS_id) VALUES (1, 6);
INSERT INTO HC_PermissionXScreen (SCN_id, PMS_id) VALUES (2, 1);
INSERT INTO HC_PermissionXScreen (SCN_id, PMS_id) VALUES (2, 2);
INSERT INTO HC_PermissionXScreen (SCN_id, PMS_id) VALUES (2, 4);
INSERT INTO HC_PermissionXScreen (SCN_id, PMS_id) VALUES (2, 5);
INSERT INTO HC_PermissionXScreen (SCN_id, PMS_id) VALUES (3, 1);
INSERT INTO HC_PermissionXScreen (SCN_id, PMS_id) VALUES (3, 2);
INSERT INTO HC_PermissionXScreen (SCN_id, PMS_id) VALUES (3, 4);
INSERT INTO HC_PermissionXScreen (SCN_id, PMS_id) VALUES (3, 5);

-- ProfileXPermissionXScreen
INSERT INTO HC_ProfileXPermissionXScreen (PRF_id, SCN_id, PMS_id) VALUES (1, 1, 3);
INSERT INTO HC_ProfileXPermissionXScreen (PRF_id, SCN_id, PMS_id) VALUES (1, 1, 6);
INSERT INTO HC_ProfileXPermissionXScreen (PRF_id, SCN_id, PMS_id) VALUES (1, 2, 4);
INSERT INTO HC_ProfileXPermissionXScreen (PRF_id, SCN_id, PMS_id) VALUES (1, 3, 5);
INSERT INTO HC_ProfileXPermissionXScreen (PRF_id, SCN_id, PMS_id) VALUES (2, 2, 1);
INSERT INTO HC_ProfileXPermissionXScreen (PRF_id, SCN_id, PMS_id) VALUES (2, 2, 4);
INSERT INTO HC_ProfileXPermissionXScreen (PRF_id, SCN_id, PMS_id) VALUES (3, 3, 2);
INSERT INTO HC_ProfileXPermissionXScreen (PRF_id, SCN_id, PMS_id) VALUES (3, 3, 4);

-- Users (PF_id assigned)
INSERT INTO HC_User (USR_id, USR_identification, USR_f_name, USR_identification_type, USR_civil_status, USR_gender, USR_dateofbirth, USR_state, USR_type, USR_approved, USR_email, version, USR_f_lastname, PF_id)
  VALUES (1, '1001001', 'Ana', 'N', 'S', 'F', TO_DATE('1985-02-10','YYYY-MM-DD'), 'A', 'M', 'Y', 'ana@example.com', 1, 'Lopez', 2);
INSERT INTO HC_User (USR_id, USR_identification, USR_f_name, USR_identification_type, USR_civil_status, USR_gender, USR_dateofbirth, USR_state, USR_type, USR_approved, USR_email, version, USR_f_lastname, PF_id)
  VALUES (2, '1001002', 'Juan', 'N', 'M', 'M', TO_DATE('1978-07-05','YYYY-MM-DD'), 'A', 'M', 'Y', 'juan@example.com', 1, 'Perez', 2);
INSERT INTO HC_User (USR_id, USR_identification, USR_f_name, USR_identification_type, USR_civil_status, USR_gender, USR_dateofbirth, USR_state, USR_type, USR_approved, USR_email, version, USR_f_lastname, PF_id)
  VALUES (3, '1001003', 'Maria', 'N', 'S', 'F', TO_DATE('1990-11-20','YYYY-MM-DD'), 'A', 'M', 'Y', 'maria@example.com', 1, 'Gomez', 2);
INSERT INTO HC_User (USR_id, USR_identification, USR_f_name, USR_identification_type, USR_civil_status, USR_gender, USR_dateofbirth, USR_state, USR_type, USR_approved, USR_email, version, USR_f_lastname, PF_id)
  VALUES (4, '1001004', 'Carlos', 'N', 'M', 'M', TO_DATE('1982-03-12','YYYY-MM-DD'), 'A', 'M', 'Y', 'carlos@example.com', 1, 'Martinez', 3);
INSERT INTO HC_User (USR_id, USR_identification, USR_f_name, USR_identification_type, USR_civil_status, USR_gender, USR_dateofbirth, USR_state, USR_type, USR_approved, USR_email, version, USR_f_lastname, PF_id)
  VALUES (5, '1001005', 'Luisa', 'N', 'S', 'F', TO_DATE('1992-09-01','YYYY-MM-DD'), 'A', 'M', 'Y', 'luisa@example.com', 1, 'Ortega', 3);
INSERT INTO HC_User (USR_id, USR_identification, USR_f_name, USR_identification_type, USR_civil_status, USR_gender, USR_dateofbirth, USR_state, USR_type, USR_approved, USR_email, version, USR_f_lastname, PF_id)
  VALUES (6, '1001006', 'Diego', 'N', 'S', 'M', TO_DATE('1995-05-15','YYYY-MM-DD'), 'A', 'A', 'Y', 'diego@example.com', 1, 'Rios', 1);

-- Bank accounts
INSERT INTO HC_BankAccount (BAC_id, BAC_account_number, USR_id, BNE_id, version) VALUES (1, 'BC-0001', 1, 1, 1);
INSERT INTO HC_BankAccount (BAC_id, BAC_account_number, USR_id, BNE_id, version) VALUES (2, 'BN-1002', 2, 2, 1);
INSERT INTO HC_BankAccount (BAC_id, BAC_account_number, USR_id, BNE_id, version) VALUES (3, 'BS-2003', 3, 3, 1);
INSERT INTO HC_BankAccount (BAC_id, BAC_account_number, USR_id, BNE_id, version) VALUES (4, 'BC-0004', 4, 1, 1);
INSERT INTO HC_BankAccount (BAC_id, BAC_account_number, USR_id, BNE_id, version) VALUES (5, 'BN-1005', 5, 2, 1);
INSERT INTO HC_BankAccount (BAC_id, BAC_account_number, USR_id, BNE_id, version) VALUES (6, 'BS-2006', 6, 3, 1);

-- Positions
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, version) VALUES (1, 'Medicina General - Matutino', 'Atencion general', 'MON', 1, 1, 1, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, version) VALUES (2, 'Medicina General - Vespertino', 'Atencion general', 'TUE', 1, 2, 2, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, version) VALUES (3, 'Pediatria', 'Pediatria', 'WED', 2, 3, 1, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, version) VALUES (4, 'Urgencias', 'Guardia', 'FRI', 3, 4, 2, 1);

-- MonthScale
INSERT INTO HC_MonthScale (MSC_id, MSC_state, MSC_month, MSC_year, HCN_id, MSC_processed, version) VALUES (1, 'B', 'OCT', '2025', 1, 'N', 1);
INSERT INTO HC_MonthScale (MSC_id, MSC_state, MSC_month, MSC_year, HCN_id, MSC_processed, version) VALUES (2, 'B', 'OCT', '2025', 2, 'N', 1);
INSERT INTO HC_MonthScale (MSC_id, MSC_state, MSC_month, MSC_year, HCN_id, MSC_processed, version) VALUES (3, 'B', 'OCT', '2025', 3, 'N', 1);

-- TurnXMonthScale
INSERT INTO HC_TurnXMonthScale (MSC_id, TRN_id, TMS_compliance, TMS_partial_worked_hours, TMS_date, USR_id, TMS_hourly_price, TMS_hourly_payment, TSM_name, TSM_description, TMS_processed, version) VALUES (1,1,'F',NULL,TO_DATE('2025-10-05','YYYY-MM-DD'),1,50,40,'Medicina General','Turno matutino','N',1);
INSERT INTO HC_TurnXMonthScale (MSC_id, TRN_id, TMS_compliance, TMS_partial_worked_hours, TMS_date, USR_id, TMS_hourly_price, TMS_hourly_payment, TSM_name, TSM_description, TMS_processed, version) VALUES (1,2,'F',NULL,TO_DATE('2025-10-05','YYYY-MM-DD'),2,50,40,'Medicina General','Turno vespertino','N',1);
INSERT INTO HC_TurnXMonthScale (MSC_id, TRN_id, TMS_compliance, TMS_partial_worked_hours, TMS_date, USR_id, TMS_hourly_price, TMS_hourly_payment, TSM_name, TSM_description, TMS_processed, version) VALUES (2,1,'F',NULL,TO_DATE('2025-10-06','YYYY-MM-DD'),3,55,44,'Pediatria','Turno matutino','N',1);
INSERT INTO HC_TurnXMonthScale (MSC_id, TRN_id, TMS_compliance, TMS_partial_worked_hours, TMS_date, USR_id, TMS_hourly_price, TMS_hourly_payment, TSM_name, TSM_description, TMS_processed, version) VALUES (3,2,'F',NULL,TO_DATE('2025-10-07','YYYY-MM-DD'),4,60,48,'Urgencias','Turno vespertino','N',1);

COMMIT;