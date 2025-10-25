CREATE OR REPLACE PACKAGE PCK_PROCEDURES_ADMINISTRATOR AUTHID DEFINER IS

  PROCEDURE CHARGE_NATIONAL_REGISTER(pFileName VARCHAR2); --The file name shut include the extention (.txt for example)

END PCK_PROCEDURES_ADMINISTRATOR;
/
CREATE OF REPLACE PACKAGE BODY PCK_PROCEDURES_ADMINISTRATOR IS

-- Procedure to read the national register file and charge it into de database
  PROCEDURE CHARGE_NATIONAL_REGISTER(pFileName VARCHAR2) IS
    v_file UTL_FILE.FILE_TYPE;
    v_line VARCHAR2(4000);
  
    v_version CONSTANT NUMBER := 1;
    v_f_name    VARCHAR2(30);
    v_s_name   VARCHAR2(30);
    v_f_lastname  VARCHAR2(30);
    v_s_lastname VARCHAR2(30);
    v_national_identification VARCHAR2(30);
    v_full_name VARCHAR2(60);
    v_pos_space     NUMBER;
  
  BEGIN
    v_file := UTL_FILE.FOPEN('DIR_NATIONAL_REGISTER', pFileName, 'R');
  
    LOOP
      BEGIN
        UTL_FILE.GET_LINE(v_file, v_line);
      
        v_national_identification := REGEXP_SUBSTR(v_line, '[^,]+', 1, 1);
        v_full_name := TRIM(REGEXP_SUBSTR(v_line, '[^,]+', 1, 6));
        v_f_lastname := TRIM(REGEXP_SUBSTR(v_line, '[^,]+', 1, 7));
        v_s_lastname := TRIM(REGEXP_SUBSTR(v_line, '[^,]+', 1, 8));
      
        v_pos_space := INSTR(v_full_name, ' ');
      
        IF v_pos_space > 0 THEN
          v_f_name := SUBSTR(v_full_name, 1, v_pos_space - 1);
          v_s_name := SUBSTR(v_full_name, v_pos_space + 1);
        ELSE
          v_f_name := v_full_name;
          v_s_name := NULL;
        END IF;
      
        INSERT INTO HC_NationalRegister
          (NRG_f_name, NRG_s_name, NRG_f_lastname, NRG_s_lastname, NRG__national_identification, version)
        VALUES
          (v_f_name, v_s_name, v_f_lastname, v_s_lastname, v_national_identification, v_version);
      
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          EXIT;
        WHEN OTHERS THEN
          DBMS_OUTPUT.PUT_LINE('Error in line: ' || v_line || ' - ' ||SQLERRM);
      END;
    END LOOP;
  
    UTL_FILE.FCLOSE(v_file);
  
    COMMIT;
  
  END CHARGE_NATIONAL_REGISTER;
END PCK_PROCEDURES_ADMINISTRATOR;
/