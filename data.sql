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

-- Users (PF_id assigned)
INSERT INTO HC_User (USR_id, USR_identification, USR_f_name, USR_f_lastname, USR_s_lastname, USR_identification_type, USR_civil_status, USR_gender, USR_dateofbirth, USR_state, USR_type, USR_approved, USR_email, version, PF_id)
  VALUES (1, '1001001', 'Ana', 'Lopez', 'Garcia', 'N', 'S', 'F', TO_DATE('1985-02-10','YYYY-MM-DD'), 'A', 'M', 'Y', 'ana@example.com', 1, 2);
INSERT INTO HC_User (USR_id, USR_identification, USR_f_name, USR_f_lastname, USR_s_lastname, USR_identification_type, USR_civil_status, USR_gender, USR_dateofbirth, USR_state, USR_type, USR_approved, USR_email, version, PF_id)
  VALUES (2, '1001002', 'Juan', 'Perez', 'Diaz', 'N', 'M', 'M', TO_DATE('1978-07-05','YYYY-MM-DD'), 'A', 'M', 'Y', 'juan@example.com', 1, 2);
INSERT INTO HC_User (USR_id, USR_identification, USR_f_name, USR_f_lastname, USR_s_lastname, USR_identification_type, USR_civil_status, USR_gender, USR_dateofbirth, USR_state, USR_type, USR_approved, USR_email, version, PF_id)
  VALUES (3, '1001003', 'Maria', 'Gomez', 'Hernandez', 'N', 'S', 'F', TO_DATE('1990-11-20','YYYY-MM-DD'), 'A', 'M', 'Y', 'maria@example.com', 1, 2);
INSERT INTO HC_User (USR_id, USR_identification, USR_f_name, USR_f_lastname, USR_s_lastname, USR_identification_type, USR_civil_status, USR_gender, USR_dateofbirth, USR_state, USR_type, USR_approved, USR_email, version, PF_id)
  VALUES (4, '1001004', 'Carlos', 'Martinez', 'Lopez', 'N', 'M', 'M', TO_DATE('1982-03-12','YYYY-MM-DD'), 'A', 'M', 'Y', 'carlos@example.com', 1, 3);
INSERT INTO HC_User (USR_id, USR_identification, USR_f_name, USR_f_lastname, USR_s_lastname, USR_identification_type, USR_civil_status, USR_gender, USR_dateofbirth, USR_state, USR_type, USR_approved, USR_email, version, PF_id)
  VALUES (5, '1001005', 'Luisa', 'Ortega', 'Alvarez', 'N', 'S', 'F', TO_DATE('1992-09-01','YYYY-MM-DD'), 'A', 'M', 'Y', 'luisa@example.com', 1, 3);
INSERT INTO HC_User (USR_id, USR_identification, USR_f_name, USR_f_lastname, USR_s_lastname, USR_identification_type, USR_civil_status, USR_gender, USR_dateofbirth, USR_state, USR_type, USR_approved, USR_email, version, PF_id)
  VALUES (6, '1001006', 'Diego', 'Rios', 'Santos', 'N', 'S', 'M', TO_DATE('1995-05-15','YYYY-MM-DD'), 'A', 'A', 'Y', 'diego@example.com', 1, 1);

-- Bank accounts
INSERT INTO HC_BankAccount (BAC_id, BAC_account_number, USR_id, BNE_id, version) VALUES (1, 'BC-0001', 1, 1, 1);
INSERT INTO HC_BankAccount (BAC_id, BAC_account_number, USR_id, BNE_id, version) VALUES (2, 'BN-1002', 2, 2, 1);
INSERT INTO HC_BankAccount (BAC_id, BAC_account_number, USR_id, BNE_id, version) VALUES (3, 'BS-2003', 3, 3, 1);
INSERT INTO HC_BankAccount (BAC_id, BAC_account_number, USR_id, BNE_id, version) VALUES (4, 'BC-0004', 4, 1, 1);
INSERT INTO HC_BankAccount (BAC_id, BAC_account_number, USR_id, BNE_id, version) VALUES (5, 'BN-1005', 5, 2, 1);
INSERT INTO HC_BankAccount (BAC_id, BAC_account_number, USR_id, BNE_id, version) VALUES (6, 'BS-2006', 6, 3, 1);

-- Positions
-- HealthCenter 1 (Clinica Norte)
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, version)
  VALUES (1, 'Medicina - Turno Mañana HC1', 'Atencion general mañanas', 'MON', 1, 1, 1, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, version)
  VALUES (2, 'Medicina - Turno Tarde HC1', 'Atencion general tardes', 'TUE', 1, 2, 2, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, version)
  VALUES (3, 'Consulta - Mañana HC1', 'Consultas generales', 'WED', 1, 6, 3, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, version)
  VALUES (4, 'Consulta - Mediodía HC1', 'Consultas mediodía', 'THU', 1, 1, 4, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, version)
  VALUES (5, 'Guardia - Noche HC1', 'Guardia nocturna', 'FRI', 1, 2, 5, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, version)
  VALUES (6, 'Turno Madrugada HC1', 'Atencion madrugada', 'SAT', 1, 6, 6, 1);

-- HealthCenter 2 (Centro Salud Central)
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, version)
  VALUES (7, 'Medicina - Mañana HC2', 'Atencion general mañanas', 'TUE', 2, 3, 1, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, version)
  VALUES (8, 'Medicina - Tarde HC2', 'Atencion general tardes', 'WED', 2, 3, 2, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, version)
  VALUES (9, 'Pediatria - Mañana HC2', 'Pediatria mañanas', 'THU', 2, 2, 3, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, version)
  VALUES (10, 'Pediatria - Tarde HC2', 'Pediatria tardes', 'FRI', 2, 4, 4, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, version)
  VALUES (11, 'Urgencias - Noche HC2', 'Urgencias nocturna', 'SAT', 2, 5, 5, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, version)
  VALUES (12, 'Turno Madrugada HC2', 'Atencion madrugada', 'SUN', 2, 3, 6, 1);

-- HealthCenter 3 (Unidad Sur)
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, version)
  VALUES (13, 'Urgencias - Mañana HC3', 'Urgencias diurna', 'WED', 3, 4, 1, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, version)
  VALUES (14, 'Urgencias - Tarde HC3', 'Urgencias vespertina', 'THU', 3, 5, 2, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, version)
  VALUES (15, 'Guardia - Noche HC3', 'Guardia nocturna', 'FRI', 3, 6, 3, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, version)
  VALUES (16, 'Consulta - Mediodía HC3', 'Consultas mediodía', 'SAT', 3, 4, 4, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, version)
  VALUES (17, 'Consulta - Tarde HC3', 'Consultas vespertinas', 'SUN', 3, 5, 5, 1);
INSERT INTO HC_Position (PST_id, PST_name, PST_description, PST_day_of_week, HCN_id, USR_id, TRN_id, version)
  VALUES (18, 'Turno Madrugada HC3', 'Atencion madrugada', 'MON', 3, 6, 6, 1);

COMMIT;