-- Delete HC user if it already exists
DECLARE
    v_cnt NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_cnt FROM dba_users WHERE username = 'HC';
    IF v_cnt > 0 THEN
        EXECUTE IMMEDIATE 'DROP USER HC CASCADE';
    END IF;
END;
/

-- Delete tablespace HC_TS if it already exists (including content and datafiles)
DECLARE
    v_cnt NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_cnt FROM dba_tablespaces WHERE tablespace_name = 'HC_TS';
    IF v_cnt > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLESPACE HC_TS INCLUDING CONTENTS AND DATAFILES';
    END IF;
END;
/