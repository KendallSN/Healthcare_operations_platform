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
INSERT INTO HC_Turn (TRN_id, TRN_start_hour, TRN_end_hour) VALUES (3, 6, 12);
INSERT INTO HC_Turn (TRN_id, TRN_start_hour, TRN_end_hour) VALUES (4, 12, 18);
INSERT INTO HC_Turn (TRN_id, TRN_start_hour, TRN_end_hour) VALUES (5, 18, 24);
INSERT INTO HC_Turn (TRN_id, TRN_start_hour, TRN_end_hour) VALUES (6, 0, 6);

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

-- Payroll types
INSERT INTO HC_PayrollType (PRT_id, PRT_name, PRT_html, version) VALUES (1, 'Planilla - Medicos', 'Pago mensual - estándar', 1);
INSERT INTO HC_PayrollType (PRT_id, PRT_name, PRT_html, version) VALUES (2, 'Planilla - Administradores', 'Pago mensual - contrato', 1);

-- Movement types
INSERT INTO HC_MovementType (MVT_id, MVT_name, MVT_description, MVT_automatic, MVT_amount, MVT_type, MVT_amount_type, MVT_lower_limit, MVT_upper_limit, version)
  VALUES (1, 'Procedimiento', 'Movimientos referente a un procedimiento realizado por un medico', 'N', NULL, 'I', NULL, NULL, NULL, 1);
INSERT INTO HC_MovementType (MVT_id, MVT_name, MVT_description, MVT_automatic, MVT_amount, MVT_type, MVT_amount_type, MVT_lower_limit, MVT_upper_limit, version)
  VALUES (2, 'Turno', 'Movimientos referente a un turno trabajado a pagar a un medico', 'N', NULL, 'I', NULL, NULL, NULL, 1);
INSERT INTO HC_MovementType (MVT_id, MVT_name, MVT_description, MVT_automatic, MVT_amount, MVT_type, MVT_amount_type, MVT_lower_limit, MVT_upper_limit, version)
  VALUES (3, 'Salario base', 'Movimiento referente al pago del salario base a administrativos', 'N', NULL, 'I', NULL, NULL, NULL, 1);
INSERT INTO HC_MovementType (MVT_id, MVT_name, MVT_description, MVT_automatic, MVT_amount, MVT_type, MVT_amount_type, MVT_lower_limit, MVT_upper_limit, version)
  VALUES (4, 'Renta a salarios altos', 'Renta del 10% a salarios de mas de 1 millon de colones a todos los trabajadores', 'Y', 10, 'D', 'P', 1000000, NULL, 1);
INSERT INTO HC_MovementType (MVT_id, MVT_name, MVT_description, MVT_automatic, MVT_amount, MVT_type, MVT_amount_type, MVT_lower_limit, MVT_upper_limit, version)
  VALUES (5, 'Renta a salarios medios', 'Renta del 7% a salarios de mas de 400 000 y menores a 1 millon de colones a todos los trabajadores', 'Y', 7, 'D', 'P', 400000, 1000000, 1);
INSERT INTO HC_MovementType (MVT_id, MVT_name, MVT_description, MVT_automatic, MVT_amount, MVT_type, MVT_amount_type, MVT_lower_limit, MVT_upper_limit, version)
  VALUES (6, 'Extra a salarios bajos', 'Aporte de 50 000 colones a salarios de menos de 200000 colones a todos los trabajadores', 'Y', 50000, 'I', 'A', NULL, 200000, 1);

-- Movement types for payrolltypes
INSERT INTO HC_MovementTypeXPayrollType (PRT_id, MVT_id) VALUES (1, 1);
INSERT INTO HC_MovementTypeXPayrollType (PRT_id, MVT_id) VALUES (1, 2);
INSERT INTO HC_MovementTypeXPayrollType (PRT_id, MVT_id) VALUES (2, 3);
INSERT INTO HC_MovementTypeXPayrollType (PRT_id, MVT_id) VALUES (1, 4);
INSERT INTO HC_MovementTypeXPayrollType (PRT_id, MVT_id) VALUES (2, 4);
INSERT INTO HC_MovementTypeXPayrollType (PRT_id, MVT_id) VALUES (1, 5);
INSERT INTO HC_MovementTypeXPayrollType (PRT_id, MVT_id) VALUES (2, 5);
INSERT INTO HC_MovementTypeXPayrollType (PRT_id, MVT_id) VALUES (1, 6);
INSERT INTO HC_MovementTypeXPayrollType (PRT_id, MVT_id) VALUES (2, 6);

-- Users
INSERT INTO HC_User (USR_id, USR_identification, USR_f_name, USR_f_lastname, USR_s_lastname, USR_home_address, USR_work_address, USR_phone, USR_identification_type, USR_civil_status, USR_gender, USR_dateofbirth, USR_state, USR_type, USR_approved, USR_email, PR_id, version, PF_id)
  VALUES (1, '1001001', 'Ana', 'Lopez', 'Garcia', 'Calle 10 #123', 'Clinica Norte - Av. 1', '+571000001', 'N', 'S', 'F', TO_DATE('1985-02-10','YYYY-MM-DD'), 'A', 'M', 'Y', 'ana@example.com', 1, 1, 2);
INSERT INTO HC_User (USR_id, USR_identification, USR_f_name, USR_f_lastname, USR_s_lastname, USR_home_address, USR_work_address, USR_phone, USR_identification_type, USR_civil_status, USR_gender, USR_dateofbirth, USR_state, USR_type, USR_approved, USR_email, PR_id, version, PF_id)
  VALUES (2, '1001002', 'Juan', 'Perez', 'Diaz', 'Carrera 5 #45', 'Centro Salud Central - Calle 2', '+571000002', 'N', 'M', 'M', TO_DATE('1978-07-05','YYYY-MM-DD'), 'A', 'M', 'Y', 'juan@example.com', 1, 1, 2);
INSERT INTO HC_User (USR_id, USR_identification, USR_f_name, USR_f_lastname, USR_s_lastname, USR_home_address, USR_work_address, USR_phone, USR_identification_type, USR_civil_status, USR_gender, USR_dateofbirth, USR_state, USR_type, USR_approved, USR_email, PR_id, version, PF_id)
  VALUES (3, '1001003', 'Maria', 'Gomez', 'Hernandez', 'Avenida 3 #78', 'Centro Salud Central - Calle 2', '+571000003', 'N', 'S', 'F', TO_DATE('1990-11-20','YYYY-MM-DD'), 'A', 'M', 'Y', 'maria@example.com', 1, 1, 2);
INSERT INTO HC_User (USR_id, USR_identification, USR_f_name, USR_f_lastname, USR_s_lastname, USR_home_address, USR_work_address, USR_phone, USR_identification_type, USR_civil_status, USR_gender, USR_dateofbirth, USR_state, USR_type, USR_approved, USR_email, PR_id, version, PF_id)
  VALUES (4, '1001004', 'Carlos', 'Martinez', 'Lopez', 'Calle 20 #9', 'Unidad Sur - Transversal 3', '+571000004', 'N', 'M', 'M', TO_DATE('1982-03-12','YYYY-MM-DD'), 'A', 'M', 'Y', 'carlos@example.com', 1, 1, 3);
INSERT INTO HC_User (USR_id, USR_identification, USR_f_name, USR_f_lastname, USR_s_lastname, USR_home_address, USR_work_address, USR_phone, USR_identification_type, USR_civil_status, USR_gender, USR_dateofbirth, USR_state, USR_type, USR_approved, USR_email, PR_id, version, PF_id)
  VALUES (5, '1001005', 'Luisa', 'Ortega', 'Alvarez', 'Barrio Las Flores #12', 'Unidad Sur - Transversal 3', '+571000005', 'N', 'S', 'F', TO_DATE('1992-09-01','YYYY-MM-DD'), 'A', 'A', 'Y', 'luisa@example.com', 2, 1, 3);
INSERT INTO HC_User (USR_id, USR_identification, USR_f_name, USR_f_lastname, USR_s_lastname, USR_home_address, USR_work_address, USR_phone, USR_identification_type, USR_civil_status, USR_gender, USR_dateofbirth, USR_state, USR_type, USR_approved, USR_email, PR_id, version, PF_id)
  VALUES (6, '1001006', 'Diego', 'Rios', 'Santos', 'Urbanizacion Sol #5', 'Clinica Norte - Av. 1', '+571000006', 'N', 'S', 'M', TO_DATE('1995-05-15','YYYY-MM-DD'), 'A', 'A', 'Y', 'diego@example.com', 2, 1, 1);

-- Bank accounts
INSERT INTO HC_BankAccount (BAC_id, BAC_account_number, USR_id, BNE_id, version) VALUES (1, 'BC-0001', 1, 1, 1);
INSERT INTO HC_BankAccount (BAC_id, BAC_account_number, USR_id, BNE_id, version) VALUES (2, 'BN-1002', 1, 2, 1);
INSERT INTO HC_BankAccount (BAC_id, BAC_account_number, USR_id, BNE_id, version) VALUES (3, 'BS-2003', 2, 1, 1);
INSERT INTO HC_BankAccount (BAC_id, BAC_account_number, USR_id, BNE_id, version) VALUES (4, 'BC-0004', 2, 2, 1);
INSERT INTO HC_BankAccount (BAC_id, BAC_account_number, USR_id, BNE_id, version) VALUES (5, 'BN-1005', 3, 3, 1);
INSERT INTO HC_BankAccount (BAC_id, BAC_account_number, USR_id, BNE_id, version) VALUES (6, 'BS-2006', 3, 1, 1);
INSERT INTO HC_BankAccount (BAC_id, BAC_account_number, USR_id, BNE_id, version) VALUES (7, 'BN-1005', 4, 2, 1);
INSERT INTO HC_BankAccount (BAC_id, BAC_account_number, USR_id, BNE_id, version) VALUES (8, 'BS-2006', 4, 3, 1);
INSERT INTO HC_BankAccount (BAC_id, BAC_account_number, USR_id, BNE_id, version) VALUES (9, 'BN-1005', 5, 2, 1);
INSERT INTO HC_BankAccount (BAC_id, BAC_account_number, USR_id, BNE_id, version) VALUES (10, 'BS-2006', 5, 1, 1);
INSERT INTO HC_BankAccount (BAC_id, BAC_account_number, USR_id, BNE_id, version) VALUES (11, 'BN-1005', 6, 3, 1);
INSERT INTO HC_BankAccount (BAC_id, BAC_account_number, USR_id, BNE_id, version) VALUES (12, 'BS-2006', 6, 2, 1);

UPDATE HC_User SET BAC_id = 1 WHERE USR_id = 1;
UPDATE HC_User SET BAC_id = 3 WHERE USR_id = 2;
UPDATE HC_User SET BAC_id = 5 WHERE USR_id = 3;
UPDATE HC_User SET BAC_id = 7 WHERE USR_id = 4;
UPDATE HC_User SET BAC_id = 9 WHERE USR_id = 5;
UPDATE HC_User SET BAC_id = 11 WHERE USR_id = 6;

-- Positions
-- HealthCenter 1 (Clinica Norte)
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, PST_base_hourly_payment, PST_base_hourly_price, version)
  VALUES (1, 'Medicina - Turno Mañana HC1', 'Atencion general mañanas', 'MON', 1, 1, 1, 8000, 12000, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, PST_base_hourly_payment, PST_base_hourly_price, version)
  VALUES (2, 'Medicina - Turno Tarde HC1', 'Atencion general tardes', 'TUE', 1, 2, 2, 7500, 11000, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, PST_base_hourly_payment, PST_base_hourly_price, version)
  VALUES (3, 'Consulta - Mañana HC1', 'Consultas generales', 'WED', 1, 3, 3, 7000, 10000, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, PST_base_hourly_payment, PST_base_hourly_price, version)
  VALUES (4, 'Consulta - Mediodía HC1', 'Consultas mediodía', 'THU', 1, 1, 4, 7200, 10400, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, PST_base_hourly_payment, PST_base_hourly_price, version)
  VALUES (5, 'Guardia - Noche HC1', 'Guardia nocturna', 'FRI', 1, 2, 5, 9000, 14000, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, PST_base_hourly_payment, PST_base_hourly_price, version)
  VALUES (6, 'Turno Madrugada HC1', 'Atencion madrugada', 'SAT', 1, 4, 6, 10000, 15000, 1);

-- HealthCenter 2 (Centro Salud Central)
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, PST_base_hourly_payment, PST_base_hourly_price, version)
  VALUES (7, 'Medicina - Mañana HC2', 'Atencion general mañanas', 'TUE', 2, 3, 1, 8000, 12000, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, PST_base_hourly_payment, PST_base_hourly_price, version)
  VALUES (8, 'Medicina - Tarde HC2', 'Atencion general tardes', 'WED', 2, 3, 2, 7500, 11000, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, PST_base_hourly_payment, PST_base_hourly_price, version)
  VALUES (9, 'Pediatria - Mañana HC2', 'Pediatria mañanas', 'THU', 2, 2, 3, 6800, 9600, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, PST_base_hourly_payment, PST_base_hourly_price, version)
  VALUES (10, 'Pediatria - Tarde HC2', 'Pediatria tardes', 'FRI', 2, 4, 4, 7200, 11200, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, PST_base_hourly_payment, PST_base_hourly_price, version)
  VALUES (11, 'Urgencias - Noche HC2', 'Urgencias nocturna', 'SAT', 2, 2, 5, 8800, 13600, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, PST_base_hourly_payment, PST_base_hourly_price, version)
  VALUES (12, 'Turno Madrugada HC2', 'Atencion madrugada', 'SUN', 2, 3, 6, 9600, 14400, 1);

-- HealthCenter 3 (Unidad Sur)
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, PST_base_hourly_payment, PST_base_hourly_price, version)
  VALUES (13, 'Urgencias - Mañana HC3', 'Urgencias diurna', 'WED', 3, 4, 1, 8000, 12000, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, PST_base_hourly_payment, PST_base_hourly_price, version)
  VALUES (14, 'Urgencias - Tarde HC3', 'Urgencias vespertina', 'THU', 3, 3, 2, 7500, 11000, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, PST_base_hourly_payment, PST_base_hourly_price, version)
  VALUES (15, 'Guardia - Noche HC3', 'Guardia nocturna', 'FRI', 3, 2, 3, 9000, 14000, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, PST_base_hourly_payment, PST_base_hourly_price, version)
  VALUES (16, 'Consulta - Mediodía HC3', 'Consultas mediodía', 'SAT', 3, 1, 4, 7200, 11200, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, PST_base_hourly_payment, PST_base_hourly_price, version)
  VALUES (17, 'Consulta - Tarde HC3', 'Consultas vespertinas', 'SUN', 3, 3, 5, 7600, 11600, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, PST_base_hourly_payment, PST_base_hourly_price, version)
  VALUES (18, 'Turno Madrugada HC3', 'Atencion madrugada', 'MON', 3, 4, 6, 10000, 15000, 1);

-- Procedure types
INSERT INTO HC_ProcedureType (PCT_id, PCT_name, PCT_description, version) VALUES (1, 'Consulta', 'Consulta general', 1);
INSERT INTO HC_ProcedureType (PCT_id, PCT_name, PCT_description, version) VALUES (2, 'Pediatria', 'Atencion pediatrica', 1);
INSERT INTO HC_ProcedureType (PCT_id, PCT_name, PCT_description, version) VALUES (3, 'Urgencia', 'Atencion de urgencias', 1);

-- Procedures
-- HCN 1
INSERT INTO HC_Procedure (PCD_name, PCD_description, PCD_health_center_price, PCD_medic_revenue, USR_id, PCD_date, PCT_id, HCN_id, PCD_processed, version)
  VALUES ('Consulta General HC1 - Ana', 'Consulta general en Clinica Norte', 15000, 6000, 1, TO_DATE('2025-10-05','YYYY-MM-DD'), 1, 1, 'N', 1);
INSERT INTO HC_Procedure (PCD_name, PCD_description, PCD_health_center_price, PCD_medic_revenue, USR_id, PCD_date, PCT_id, HCN_id, PCD_processed, version)
  VALUES ('Urgencia Leve HC1 - Juan', 'Urgencia leve en Clinica Norte', 22000, 9000, 2, TO_DATE('2025-10-12','YYYY-MM-DD'), 3, 1, 'N', 1);

-- HCN 2
INSERT INTO HC_Procedure (PCD_name, PCD_description, PCD_health_center_price, PCD_medic_revenue, USR_id, PCD_date, PCT_id, HCN_id, PCD_processed, version)
  VALUES ('Consulta Pediatria HC2 - Maria', 'Consulta pediatria en Centro Salud Central', 16000, 6500, 3, TO_DATE('2025-10-07','YYYY-MM-DD'), 2, 2, 'N', 1);
INSERT INTO HC_Procedure (PCD_name, PCD_description, PCD_health_center_price, PCD_medic_revenue, USR_id, PCD_date, PCT_id, HCN_id, PCD_processed, version)
  VALUES ('Procedimiento Menor HC2 - Carlos', 'Procedimiento menor en Centro Salud Central', 18000, 7000, 4, TO_DATE('2025-10-15','YYYY-MM-DD'), 1, 2, 'N', 1);
INSERT INTO HC_Procedure (PCD_name, PCD_description, PCD_health_center_price, PCD_medic_revenue, USR_id, PCD_date, PCT_id, HCN_id, PCD_processed, version)
  VALUES ('Urgencia HC2 - Luisa', 'Atencion de urgencia en Centro Salud Central', 24000, 10000, 2, TO_DATE('2025-10-20','YYYY-MM-DD'), 3, 2, 'N', 1);

-- HCN 3
INSERT INTO HC_Procedure (PCD_name, PCD_description, PCD_health_center_price, PCD_medic_revenue, USR_id, PCD_date, PCT_id, HCN_id, PCD_processed, version)
  VALUES ('Consulta General HC3 - Carlos', 'Consulta general en Unidad Sur', 15000, 6000, 4, TO_DATE('2025-10-03','YYYY-MM-DD'), 1, 3, 'N', 1);
INSERT INTO HC_Procedure (PCD_name, PCD_description, PCD_health_center_price, PCD_medic_revenue, USR_id, PCD_date, PCT_id, HCN_id, PCD_processed, version)
  VALUES ('Consulta Pediatria HC3 - Luisa', 'Consulta pediatria en Unidad Sur', 16500, 7000, 1, TO_DATE('2025-10-09','YYYY-MM-DD'), 2, 3, 'N', 1);
INSERT INTO HC_Procedure (PCD_name, PCD_description, PCD_health_center_price, PCD_medic_revenue, USR_id, PCD_date, PCT_id, HCN_id, PCD_processed, version)
  VALUES ('Urgencia HC3 - Diego', 'Atencion de urgencia en Unidad Sur', 26000, 10500, 2, TO_DATE('2025-10-22','YYYY-MM-DD'), 3, 3, 'N', 1);

COMMIT;