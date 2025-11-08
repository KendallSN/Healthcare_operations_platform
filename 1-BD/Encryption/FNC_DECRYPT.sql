CREATE OR REPLACE FUNCTION FNC_DECRYPT(pCryptedValue RAW) RETURN VARCHAR2 IS
        v_DecryptedValue RAW(1000);
        iv              RAW(16) := UTL_RAW.CAST_TO_RAW('6523914685326978');
        decrypt_key     RAW(32) := UTL_RAW.CAST_TO_RAW('71369854216329432615948756321563');
        BEGIN
        v_DecryptedValue := DBMS_CRYPTO.DECRYPT(src => pCryptedValue,
                                            typ => DBMS_CRYPTO.ENCRYPT_AES256 +
                                                DBMS_CRYPTO.CHAIN_CBC +
                                                DBMS_CRYPTO.PAD_PKCS5,
                                            key => decrypt_key,
                                            iv  => iv);
        RETURN UTL_RAW.cast_to_varchar2(v_DecryptedValue);
    EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error al desencriptar. ' ||
                            SQLERRM);
        RAISE;
END FNC_DECRYPT;