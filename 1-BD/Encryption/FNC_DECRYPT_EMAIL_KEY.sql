CREATE OR REPLACE FUNCTION FNC_DECRYPT_EMAIL_KEY(pCryptedPassword RAW) RETURN VARCHAR2 IS
        v_DecryptedPassword RAW(1000);
        iv        RAW(16) := UTL_RAW.CAST_TO_RAW('1234567890123456');
        clave     RAW(32) := UTL_RAW.CAST_TO_RAW('12345678901234567890123456789012');
        BEGIN
        v_DecryptedPassword := DBMS_CRYPTO.DECRYPT(src => pCryptedPassword,
                                            typ => DBMS_CRYPTO.ENCRYPT_AES256 +
                                                DBMS_CRYPTO.CHAIN_CBC +
                                                DBMS_CRYPTO.PAD_PKCS5,
                                            key => clave,
                                            iv  => iv);
        RETURN UTL_RAW.cast_to_varchar2(v_DecryptedPassword);
    EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error al desencriptar el password. ' ||
                            SQLERRM);
        RAISE;
END FNC_DECRYPT_EMAIL_KEY;