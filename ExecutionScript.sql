-- Crear la estructura de la bd
-- Insertar la información
-- Crear los triggers para las bitacoras

-- Planilla para el mes 10, año 2025 de centro de salud 1
EXEC generate_month_scale('10',2025,1);

-- Aprobar el MonthScale y Poner los Turnos de ese mes como completos.
EXEC pkg_utilities.approve_month_scale(1);

-- Planilla para el mes 10, año 2025 de tipo 1(Medicos)
EXEC generate_payroll('10',2025,1);

-- 
EXEC PCD_GeneratePayment(1);


DELETE FROM hc_payrollmovement;
DELETE FROM hc_payrollxuser;
DELETE FROM hc_payroll;

DELETE FROM hc_turnxmonthscale;
DELETE FROM hc_monthscale;
