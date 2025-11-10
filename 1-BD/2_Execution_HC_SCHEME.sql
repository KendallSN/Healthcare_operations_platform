    --1. La estructura de BD
@ScriptProyectoBD.sql;
    --2. Insertar Data
@ScriptData.sql;
    --3. Insertar Parametros generales
@Script_Parameters.sql;
    --4. Crear Paquetes, Procedimientos, Funciones y Jobs
@Emails\PKG_EMAILS.pkg;
@LogBooks\PCD_INSERT_LOG.sql;
@MonthScales\PCD_GENERATE_MONTH_SCALE.sql;
@NationalRegister\Script_Directory_National_Register.sql
@NationalRegister\PCD_CHARGE_NATIONAL_REGISTER.sql;
@Encryption\FNC_ENCRYPT.sql;
@Encryption\FNC_DECRYPT.sql;
@Notifications\PKG_FUNCTIONS_JOBS.pkg;
@Notifications\Script_Jobs.sql;
@Payrolls\PCD_APPROVE_PAYROLL.sql;
@Payrolls\PCD_GENERATE_PAYMENT.sql;
@Payrolls\PCD_GENERATE_PAYMENT_PAYROLL.sql;
@Payrolls\PCD_GENERATE_PAYROLL.sql;
@MonthScales\PCD_APPROVE_MONTH_SCALE.sql;
@Security\FNC_GET_ROLE_PASSWORD.sql
@Security\PCD_ACTIVATE_ROLE.sql;
    --5.Los triggers para las bitacoras
@Logbooks\Script_Logbook_Triggers.sql;
    --6.Crear los roles
@Security\Script_Roles.sql


Grant Administrator TO HC_ADMIN;
GRANT EXECUTE ON PCD_ACTIVATE_ROLE TO HC_ADMIN;
GRANT READ, WRITE ON DIRECTORY National_Register_Dir TO HC_ADMIN;