CREATE OR REPLACE FUNCTION FNC_ENCRYPT(pPlainValue VARCHAR2) RETURN RAW IS
        v_CryptedValue RAW(1000);
        iv              RAW(16) := UTL_RAW.CAST_TO_RAW('6523914685326978');
        encrypt_key     RAW(32) := UTL_RAW.CAST_TO_RAW('71369854216329432615948756321563');
        BEGIN
        v_CryptedValue := DBMS_CRYPTO.ENCRYPT(src => UTL_RAW.CAST_TO_RAW(pPlainValue),
                                            typ => DBMS_CRYPTO.ENCRYPT_AES256 +
                                                DBMS_CRYPTO.CHAIN_CBC +
                                                DBMS_CRYPTO.PAD_PKCS5,
                                            key => encrypt_key,
                                            iv  => iv);
        RETURN v_CryptedValue;
    EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error al encriptar. ' ||
                            SQLERRM);
        RAISE;
END FNC_ENCRYPT;