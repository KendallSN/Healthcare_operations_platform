BEGIN

-- Desactivación de cuentas inactivas (Mensualmente)
DBMS_SCHEDULER.create_job(job_name        => 'JOB_DEACTIVATE_ACCOUNTS',
                            job_type        => 'PLSQL_BLOCK',
                            job_action      => 'BEGIN PKG_FUNCTIONS_JOBS.PCD_DEACTIVATE_INACTIVE_ACCOUNTS; END;',
                            start_date      => TRUNC(SYSDATE) + INTERVAL '1' MONTH,
                            repeat_interval => 'FREQ=MONTHLY; BYMONTHDAY=1',
                            enabled         => TRUE);

-- Verificación de tablespaces (Diariamente)
DBMS_SCHEDULER.create_job(job_name        => 'JOB_VERIFY_TABLESPACES',
                            job_type        => 'PLSQL_BLOCK',
                            job_action      => 'BEGIN PKG_FUNCTIONS_JOBS.PCD_VERIFY_TABLESPACE_SIZES; END;',
                            start_date      => SYSTIMESTAMP,
                            repeat_interval => 'FREQ=DAILY; INTERVAL=1; BYHOUR=0; BYMINUTE=0',
                            enabled         => TRUE);

-- Verificación de objetos inválidos (Diariamente)
DBMS_SCHEDULER.create_job(job_name        => 'JOB_VERIFY_INVALID_OBJECTS',
                            job_type        => 'PLSQL_BLOCK',
                            job_action      => 'BEGIN PKG_FUNCTIONS_JOBS.PCD_VERIFY_INVALID_OBJECTS; END;',
                            start_date      => SYSTIMESTAMP,
                            repeat_interval => 'FREQ=DAILY; INTERVAL=1; BYHOUR=0; BYMINUTE=0',
                            enabled         => TRUE);

-- Verificación de índices dañados (Diariamente)
DBMS_SCHEDULER.create_job(job_name        => 'JOB_VERIFY_DAMAGED_INDEXES',
                            job_type        => 'PLSQL_BLOCK',
                            job_action      => 'BEGIN PKG_FUNCTIONS_JOBS.PCD_VERIFY_DAMAGED_INDEXES; END;',
                            start_date      => SYSTIMESTAMP,
                            repeat_interval => 'FREQ=DAILY; INTERVAL=1; BYHOUR=0; BYMINUTE=0',
                            enabled         => TRUE);

END;
/