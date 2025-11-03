CREATE OR REPLACE PROCEDURE PCD_Send_Mail(
                        pSubject    IN VARCHAR2,
                        pBody    IN VARCHAR2,
                        pRecipient IN VARCHAR2) IS
    c                    UTL_SMTP.connection;
    v_username           VARCHAR2(100);
    v_password           VARCHAR2(100);
    v_encrypted_password VARCHAR2(100);
    v_sender             VARCHAR2(100);
    v_reply_to           VARCHAR2(100);
    v_html               VARCHAR2(4000);

BEGIN
    SELECT valor
    INTO v_username
    FROM GeneralParametes
    WHERE GP_name = 'USUARIO_CORREO';

    SELECT valor
    INTO v_encrypted_password
    FROM GeneralParametes
    WHERE GP_name = 'CLAVE_CORREO';

    SELECT valor
    INTO v_sender
    FROM GeneralParametes
    WHERE GP_name = 'REMITENTE';

    v_reply_to := v_sender;

    -- Descencripta la clave del correo
    v_password := FNC_DESENCRIPTAR_CLAVE(v_encrypted_password);

    -- Estilo HTML para el correo
    v_html := UTL_RAW.cast_to_varchar2(UTL_I18N.string_to_raw('
    <html>
    <head>
        <title>' ||
                                                                    pSubject ||
                                                                    '</title>
        <style>
            body { font-family: Arial, sans-serif; background-color: #d1d1d1; padding: 20px; margin: 0; }
            .container { background-color: #333333; padding: 20px; border-radius: 10px; max-width: 600px; margin: 0 auto; color: white; }
            h1 { color: #ffffff; }
            p { color: #cccccc; }
            footer { margin-top: 20px; font-size: 12px; text-align: center; color: #aaaaaa; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>' ||
                                                                    pSubject ||
                                                                    '</h1>
            ' ||
                                                                    pBody || '
            <footer>
                2024 Proyecto de Administraci�n de Bases de Datos. Todos los derechos reservados.<br>
                Direcci�n: Universidad Nacional SRB, P�rez Zeled�n, Costa Rica<br>
                Tel�fono: +506 8538 1034 | +506 6262 3615 | +506 8393 5021<br>
                Correo: <a href="mailto:jousten.blanco.fonseca@est.una.ac.cr" style="color: #ffffff;">jousten.blanco.fonseca@est.una.ac.cr</a> |
                <a href="mailto:sebastian.granados.barrantes@est.una.ac.cr" style="color: #ffffff;">sebastian.granados.barrantes@est.una.ac.cr</a> |
                <a href="mailto:raul.bejarano.mora@est.una.ac.cr" style="color: #ffffff;">raul.bejarano.mora@est.una.ac.cr</a>
            </footer>
        </div>
    </body>
    </html>',
                                                                    'AL32UTF8'));

    -- Proceso de conexi�n y env�o de correo
    DBMS_OUTPUT.put_line('Iniciando conexi�n SMTP...');
    c := UTL_SMTP.open_connection('smtp-relay.brevo.com', 587);
    DBMS_OUTPUT.put_line('Conexi�n SMTP establecida.');

    DBMS_OUTPUT.put_line('Enviando HELO...');
    UTL_SMTP.helo(c, 'localhost');
    DBMS_OUTPUT.put_line('HELO enviado.');

    DBMS_OUTPUT.put_line('Autenticando...');
    UTL_SMTP.command(c, 'AUTH LOGIN');
    UTL_SMTP.command(c, encode_base64(v_username));
    UTL_SMTP.command(c, encode_base64(v_password));
    DBMS_OUTPUT.put_line('Autenticaci�n exitosa.');

    DBMS_OUTPUT.put_line('Configurando remitente...');
    UTL_SMTP.mail(c, v_sender);
    DBMS_OUTPUT.put_line('Remitente configurado.');

    DBMS_OUTPUT.put_line('Configurando destinatario...');
    UTL_SMTP.rcpt(c, pRecipient);
    DBMS_OUTPUT.put_line('Destinatario configurado.');

    DBMS_OUTPUT.put_line('Enviando datos del correo...');
    UTL_SMTP.data(c,
                'From: ' || v_sender || UTL_TCP.crlf || 'Reply-To: ' ||
                v_reply_to || UTL_TCP.crlf || 'To: ' || pRecipient ||
                UTL_TCP.crlf || 'Subject: ' || pSubject || UTL_TCP.crlf ||
                'MIME-Version: 1.0' || UTL_TCP.crlf ||
                'Content-Type: text/html; charset=UTF-8' || UTL_TCP.crlf ||
                UTL_TCP.crlf || v_html);
    DBMS_OUTPUT.put_line('Correo enviado.');

    UTL_SMTP.quit(c);
    DBMS_OUTPUT.put_line('Conexi�n cerrada correctamente.');

EXCEPTION
    WHEN OTHERS THEN
    DBMS_OUTPUT.put_line('Error al enviar el correo: ' || SQLERRM);
    BEGIN
        UTL_SMTP.quit(c);
    EXCEPTION
        WHEN OTHERS THEN
        NULL;
    END;
END PCD_Send_Mail;