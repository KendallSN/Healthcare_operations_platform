FUNCTION FNC_EncryptEmailKey(pPlainPassword VARCHAR2) RETURN RAW IS
        v_EncryptedPassword RAW(1000);
        iv        RAW(16) := UTL_RAW.CAST_TO_RAW('1234567890123456');
        clave     RAW(32) := UTL_RAW.CAST_TO_RAW('12345678901234567890123456789012');
        BEGIN
        v_EncryptedPassword := DBMS_CRYPTO.ENCRYPT(src => UTL_RAW.CAST_TO_RAW(pPlainPassword),
                                            typ => DBMS_CRYPTO.ENCRYPT_AES256 +
                                                DBMS_CRYPTO.CHAIN_CBC +
                                                DBMS_CRYPTO.PAD_PKCS5,
                                            key => clave,
                                            iv  => iv);
        RETURN v_EncryptedPassword;
    EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error al encriptar el password. ' ||
                            SQLERRM);
        RAISE;
END FNC_EncryptEmailKey;