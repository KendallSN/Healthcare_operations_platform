-- Crear la estructura de la bd
-- Insertar la información
-- Crear PCD_INSERT_LOG
-- Crear los triggers para las bitacoras

-- Planilla para el mes 10, año 2025 de centro de salud 1
EXEC PCD_GENERATE_MONTH_SCALE('10',2025,1);

-- Crear PCD_APPROVE_MONTH_SCALE
EXEC PCD_APPROVE_MONTH_SCALE(1);

-- Crear PCD_GENERATE_PAYROLL
-- Planilla para el mes 10, año 2025 de tipo 1(Medicos)
EXEC PCD_GENERATE_PAYROLL('10',2025,1);


-- Crear PCD_APPROVE_PAYROLL
-- Aprobar el MonthScale y Poner los Turnos de ese mes como completos.
EXEC PCD_APPROVE_PAYROLL(1);



-- 
EXEC PCD_GENERATE_PAYMENT(1);


DELETE FROM hc_payrollmovement;
DELETE FROM hc_payrollxuser;
DELETE FROM hc_payroll;

DELETE FROM hc_turnxmonthscale;
DELETE FROM hc_monthscale;
