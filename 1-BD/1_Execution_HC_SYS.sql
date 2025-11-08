--! previo a crear los esquemas es necesario importar en la base de datos los componentes para emails. (Seguir los pasos de la guia 1 al 3)
-- Crear Esquemas y Tablespace con sys
-- HC_SCHEME es el dueño de la base de datos (Tablas/Procedimiento/Funciones)
-- HC_ADMIN es un usuario que luego tendra rol Administrador
@Script_SchemeTableSpace.sql

--!cada vez que se cree el HC_SCHEME se debe volver a crear el ACL

BEGIN
DBMS_NETWORK_ACL_ADMIN.drop_acl(
    acl => 'smtp_acl.xml'
);
END;
/
BEGIN
    DBMS_NETWORK_ACL_ADMIN.create_acl(
        acl          => 'smtp_acl.xml',
        description  => 'Permitir acceso SMTP a smtp-relay.brevo.com',
        principal    => 'HC_SCHEME',
        is_grant     => TRUE,
        privilege    => 'connect'
    );
END;
/
BEGIN
    DBMS_NETWORK_ACL_ADMIN.add_privilege(
        acl         => 'smtp_acl.xml',
        principal   => 'HC_SCHEME',
        is_grant    => TRUE,
        privilege   => 'resolve'
    );
END;
/
BEGIN
    DBMS_NETWORK_ACL_ADMIN.assign_acl(
        acl        => 'smtp_acl.xml',
        host       => 'smtp-relay.brevo.com',  --Servidor SMTP
        lower_port => 587,  -- Puerto
        upper_port => 587   -- Puerto
    );
END;
/