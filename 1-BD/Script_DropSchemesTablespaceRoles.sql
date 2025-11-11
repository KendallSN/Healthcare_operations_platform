-- Borrar el usuario dueño de las tablas
DROP USER HC_SCHEME CASCADE;
-- Borrar el usuario Administrador
DROP USER HC_ADMIN CASCADE;
-- Borrar Tablespace con contenido y datafiles
DROP TABLESPACE HC_TS INCLUDING CONTENTS AND DATAFILES CASCADE CONSTRAINTS;

-- Borrar los Roles
DROP ROLE Administrator;
DROP ROLE Medic;
DROP ROLE Administrative;

-- Eliminar perfiles y reasignar usuarios al perfil DEFAULT
DROP PROFILE admin_profile CASCADE;
DROP PROFILE medic_profile CASCADE;
DROP PROFILE staff_profile CASCADE;