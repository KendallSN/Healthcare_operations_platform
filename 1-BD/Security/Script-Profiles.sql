-- Perfil para Administradores: contraseñas cambian cada 180 días, 10 intentos fallidos
CREATE PROFILE admin_profile LIMIT
    PASSWORD_LIFE_TIME 365
    FAILED_LOGIN_ATTEMPTS 10
    PASSWORD_LOCK_TIME 1
    SESSIONS_PER_USER UNLIMITED;

-- Perfil para Médicos: contraseñas cambian cada 365 días, 15 intentos fallidos
CREATE PROFILE medic_profile LIMIT
    PASSWORD_LIFE_TIME 365
    FAILED_LOGIN_ATTEMPTS 15
    PASSWORD_LOCK_TIME 0.5
    SESSIONS_PER_USER 3;

-- Perfil para Administrativos: contraseñas cambian cada 180 días, 8 intentos fallidos
CREATE PROFILE staff_profile LIMIT
    PASSWORD_LIFE_TIME 180
    FAILED_LOGIN_ATTEMPTS 8
    PASSWORD_LOCK_TIME 0.5
    SESSIONS_PER_USER 2;