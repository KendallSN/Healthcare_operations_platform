-- El usuario debe activar su rol en cada inicio de sesión para poder utilizar los elementos de HC_SCHEME
-- Previo a activarlo una consulta no debe funcionar.
SELECT * FROM HC_SCHEME.HC_USER;
BEGIN
    HC_SCHEME.PCD_ACTIVATE_ROLE('Administrator');
END;
/

SELECT * FROM HC_SCHEME.HC_NATIONALREGISTER;
EXEC HC_SCHEME.PCD_CHARGE_NATIONAL_REGISTER('PADRON_COMPLETO.txt');

SELECT * FROM HC_SCHEME.HC_MONTHSCALE;
SELECT * FROM HC_SCHEME.HC_TURNXMONTHSCALE;
-- Planilla para el mes 10, año 2025 de centro de salud 1
EXEC HC_SCHEME.PCD_GENERATE_MONTH_SCALE('10',2025,1);

-- Cambia el estado de la escala mensual a P (Lista para pago)para que se pueda generar planilla.
-- Cambia los estados de completado de los turnos de la escala mensual a 
-- F(Trabajados completos) o P(Trabajados Parcialmente rellenando horas parciales trabajadas) de forma aleatoria.
EXEC HC_SCHEME.PCD_APPROVE_MONTH_SCALE(1);

-- Al modificar Escalas mensuales y turnos de la escala mensual se crearon registros en la bitacora.
SELECT * FROM HC_SCHEME.HC_LOGBOOK;

SELECT * FROM HC_SCHEME.HC_PAYROLL;
SELECT * FROM HC_SCHEME.HC_PAYROLLMOVEMENT;
SELECT * FROM HC_SCHEME.HC_PAYROLLXUSER;
-- Generar planilla para el mes 10, año 2025 de tipo 1(Medicos)
EXEC HC_SCHEME.PCD_GENERATE_PAYROLL('10',2025,1);

SELECT * FROM HC_SCHEME.HC_PAYROLL;
-- Aprobar la planilla para poder generar y enviar el comprobando de pago.
EXEC HC_SCHEME.PCD_APPROVE_PAYROLL(1);

-- Ver antes y despues de generar pago de planilla, notar variable Notified y Deposited
SELECT * FROM HC_SCHEME.HC_PAYROLL;
SELECT * FROM HC_SCHEME.HC_PAYROLLXUSER;
-- Generar el pago de la planilla con id 1, genera y envia comprobantes a todos los PayrollXUser marca como notificados y la planilla como depositada
EXEC HC_SCHEME.PCD_GENERATE_PAYMENT_PAYROLL(1);

-- Probar funciones de los Jobs
-- 1 Desactivar cuentas inactivas hace mas de 3 meses y notifica (Mensual)
EXEC HC_SCHEME.PKG_FUNCTIONS_JOBS.PCD_DEACTIVATE_INACTIVE_ACCOUNTS;
-- 2 Verifica y notifica si los tablespace superan el 85% de capacidad (Diario)
EXEC HC_SCHEME.PKG_FUNCTIONS_JOBS.PCD_VERIFY_TABLESPACE_SIZES;
-- 3 Verifica y notifica si hay objetos invalidos (Diario)
-- Crea un procedimiento con invalido
CREATE OR REPLACE PROCEDURE X IS BEGIN SELECT * FROM NO_EXISTE; END;
/
EXEC HC_SCHEME.PKG_FUNCTIONS_JOBS.PCD_VERIFY_INVALID_OBJECTS;
DROP PROCEDURE X;
-- 4 Verifica y notifica si hay indices dañados (Diario)

CREATE INDEX idx_test ON HC_SCHEME.HC_SCREEN(SCN_NAME);
ALTER INDEX idx_test UNUSABLE;

EXEC HC_SCHEME.PKG_FUNCTIONS_JOBS.PCD_VERIFY_DAMAGED_INDEXES;

DROP INDEX idx_test;