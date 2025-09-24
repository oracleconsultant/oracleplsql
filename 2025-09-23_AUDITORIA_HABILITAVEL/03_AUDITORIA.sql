SET DEFINE OFF;

/*
Autor: Nelson Carlson F. (nelson@oracledeveloper.com.br)
Data: 24/09/2025
*/

-- Passo 1: Criação da Tabela TB_PARAM_AUD: esta tabela irá servir para habilitar/desabilitar a auditoria em tabelas
DECLARE
    v_sql CLOB;
BEGIN
    DBMS_OUTPUT.PUT_LINE('[PASSO 01] Criação da Tabela TB_PARAM_AUD:');
    -- Verifica se a tabela já existe
    FOR t IN (SELECT table_name FROM user_tables WHERE table_name = 'TB_PARAM_AUD') 
	LOOP
        DBMS_OUTPUT.PUT_LINE('- Tabela TB_PARAM_AUD já existe. Pulando criação.');
        RETURN;
    END LOOP;
	--
    v_sql := 
		'CREATE TABLE tb_param_aud (
			id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
			nome VARCHAR2(30) NOT NULL,
			status VARCHAR2(10) DEFAULT ''N'' NOT NULL
		)';
	--
    EXECUTE IMMEDIATE v_sql;
    DBMS_OUTPUT.PUT_LINE('- Tabela TB_PARAM_AUD criada com sucesso!');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -955 THEN
            DBMS_OUTPUT.PUT_LINE('- Tabela TB_PARAM_AUD já existe e por isso não foi criada.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Erro ao criar tabela: SQLCODE: ' || NVL(TO_CHAR(SQLCODE), 'NULL'));
            RAISE;
        END IF;
END;

/

-- Passo 2: Inserção do Parâmetro para Auditoria: S já é criada habilitada / N fica pendente de ser habilitada mudando depois para S 
DECLARE
    v_qtd INTEGER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('[PASSO 02] Criação do parâmetro que habilita/desabilita auditoria:');
	--
    SELECT COUNT(*) 
	INTO v_qtd 
    FROM tb_param_aud 
    WHERE nome = 'TB_PESSOAS_EXEMPLO';
	--
    IF v_qtd = 0 THEN
        INSERT INTO tb_param_aud (nome, status)
        VALUES ('TB_PESSOAS_EXEMPLO', 'S'); -- S: a auditoria já é criada habilitada / N: a auditoria ficará pendente de ser habilitada mudando este valor para 'S'
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('- Parâmetro criado para TB_PESSOAS_EXEMPLO com status ''N''.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('- Parâmetro para TB_PESSOAS_EXEMPLO já existe.');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erro ao criar parâmetro: SQLCODE: ' || NVL(TO_CHAR(SQLCODE), 'NULL'));
        RAISE;
END;
/

-- Passo 3: Adição das Colunas de Auditoria em TB_PESSOAS_EXEMPLO
DECLARE
    TYPE arr_varchar IS TABLE OF VARCHAR2(1000) INDEX BY PLS_INTEGER;
    v_col_arr arr_varchar;
    v_col VARCHAR2(1000);
    i PLS_INTEGER;
    v_sql CLOB;
BEGIN
    DBMS_OUTPUT.PUT_LINE('[PASSO 03] Adição das colunas de auditoria em TB_PESSOAS_EXEMPLO:');
	--
    v_col_arr(1) := 'created_by NUMBER(10,0) NULL';
    v_col_arr(2) := 'created_date DATE NULL';
    v_col_arr(3) := 'modified_by NUMBER(10,0) NULL';
    v_col_arr(4) := 'modified_date DATE NULL';
    --
    i := v_col_arr.FIRST;
    WHILE i IS NOT NULL 
	LOOP
        v_col := v_col_arr(i);
        BEGIN
            v_sql := 'ALTER TABLE tb_pessoas_exemplo ADD ' || v_col;
            EXECUTE IMMEDIATE v_sql;
            DBMS_OUTPUT.PUT_LINE('- Coluna adicionada! (' || TRIM(v_col) || ')');
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLCODE = -1430 THEN
                    DBMS_OUTPUT.PUT_LINE('- Coluna não foi adicionada (' || TRIM(v_col) || ') pois já existe.');
                ELSE
                    DBMS_OUTPUT.PUT_LINE('Erro ao adicionar coluna: SQLCODE: ' || NVL(TO_CHAR(SQLCODE), 'NULL'));
                    RAISE;
                END IF;
        END;
        i := v_col_arr.NEXT(i);
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erro geral: SQLCODE: ' || NVL(TO_CHAR(SQLCODE), 'NULL'));
        RAISE;
END;

/

-- Passo 4: Criação da Tabela de Auditoria TB_PESSOAS_EXEMPLO_AUD
DECLARE
    v_sql CLOB;
BEGIN
    DBMS_OUTPUT.PUT_LINE('[PASSO 04] Criação da Tabela TB_PESSOAS_EXEMPLO_AUD:');
	--
    FOR t IN (SELECT table_name FROM user_tables WHERE table_name = 'TB_PESSOAS_EXEMPLO_AUD') 
	LOOP
        DBMS_OUTPUT.PUT_LINE('- Tabela TB_PESSOAS_EXEMPLO_AUD já existe. Pulando criação.');
        RETURN;
    END LOOP;
    -- Do campo created_by em diante são os campos da auditoria
    v_sql := 
		'CREATE TABLE tb_pessoas_exemplo_aud (
			id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
			id_pessoa NUMBER,
			nome VARCHAR2(100),
			nascimento DATE,
			email VARCHAR2(255),
			cep VARCHAR2(10), 
			created_by NUMBER(10,0),
			created_date DATE,
			modified_by NUMBER(10,0),
			modified_date DATE,
			audit_date DATE DEFAULT SYSDATE NOT NULL,
			operation_type VARCHAR2(10) NOT NULL,
			operation_step VARCHAR2(20),
			username VARCHAR2(100),
			osuser VARCHAR2(100),
			machine VARCHAR2(100),
			module VARCHAR2(100),
			program VARCHAR2(100),
			inserted_by_app VARCHAR2(100),
			aux_data CLOB
		)';
	--
    EXECUTE IMMEDIATE v_sql;
    DBMS_OUTPUT.PUT_LINE('- Tabela TB_PESSOAS_EXEMPLO_AUD criada com sucesso!');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -955 THEN
            DBMS_OUTPUT.PUT_LINE('- Tabela TB_PESSOAS_EXEMPLO_AUD já existe e por isso não foi criada.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Erro ao criar tabela: SQLCODE: ' || NVL(TO_CHAR(SQLCODE), 'NULL'));
            RAISE;
        END IF;
END;
/

-- Passo 5: Garantir Colunas na Tabela de Auditoria
DECLARE
    TYPE arr_varchar IS TABLE OF VARCHAR2(1000) INDEX BY PLS_INTEGER;
    v_col_arr arr_varchar;
    v_col VARCHAR2(1000);
    i PLS_INTEGER;
    v_sql CLOB;
    v_idx INTEGER := 0;
	--
    FUNCTION Inc RETURN INTEGER IS
    BEGIN
        v_idx := v_idx + 1;
        RETURN v_idx;
    END;
	--
    PROCEDURE AddCol(p_col VARCHAR2, p_type VARCHAR2) IS
    BEGIN
        v_col_arr(Inc()) := TRIM(p_col) || ' ' || TRIM(p_type);
    END;
BEGIN
    DBMS_OUTPUT.PUT_LINE('[PASSO 05] Adição das colunas em TB_PESSOAS_EXEMPLO_AUD (se necessário):');
	--
    AddCol('id_pessoa', 'NUMBER');
    AddCol('nome', 'VARCHAR2(100)');
    AddCol('nascimento', 'DATE');
    AddCol('email', 'VARCHAR2(255)');
    AddCol('cep', 'VARCHAR2(10)');
    AddCol('created_by', 'NUMBER(10,0)');
    AddCol('created_date', 'DATE');
    AddCol('modified_by', 'NUMBER(10,0)');
    AddCol('modified_date', 'DATE');
    AddCol('audit_date', 'DATE DEFAULT SYSDATE NOT NULL');
    AddCol('operation_type', 'VARCHAR2(10) NOT NULL');
    AddCol('operation_step', 'VARCHAR2(20)');
    AddCol('username', 'VARCHAR2(100)');
    AddCol('osuser', 'VARCHAR2(100)');
    AddCol('machine', 'VARCHAR2(100)');
    AddCol('module', 'VARCHAR2(100)');
    AddCol('program', 'VARCHAR2(100)');
    AddCol('inserted_by_app', 'VARCHAR2(100)');
    AddCol('aux_data', 'CLOB');
	--
    i := v_col_arr.FIRST;
    WHILE i IS NOT NULL 
	LOOP
        v_col := v_col_arr(i);
        BEGIN
            v_sql := 'ALTER TABLE tb_pessoas_exemplo_aud ADD ' || v_col;
            EXECUTE IMMEDIATE v_sql;
            DBMS_OUTPUT.PUT_LINE('- Coluna adicionada! (' || TRIM(v_col) || ')');
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLCODE = -1430 THEN
                    DBMS_OUTPUT.PUT_LINE('- Coluna não foi adicionada (' || TRIM(v_col) || ') pois já existe.');
                ELSE
                    DBMS_OUTPUT.PUT_LINE('Erro ao adicionar coluna: SQLCODE: ' || NVL(TO_CHAR(SQLCODE), 'NULL'));
                    RAISE;
                END IF;
        END;
        i := v_col_arr.NEXT(i);
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erro geral: SQLCODE: ' || NVL(TO_CHAR(SQLCODE), 'NULL'));
        RAISE;
END;

/

-- Passo 6: Criação da Trigger de Auditoria
CREATE OR REPLACE TRIGGER tb_pessoas_exemplo_aiud
BEFORE INSERT OR UPDATE OR DELETE
ON tb_pessoas_exemplo
FOR EACH ROW
DECLARE
    CURSOR c_activar 
	IS
	SELECT status
	FROM tb_param_aud
	WHERE 
		nome = 'TB_PESSOAS_EXEMPLO';
	--
    v_aud_activa tb_param_aud.status%TYPE := 'N';
    v_date DATE := SYSDATE;
    v_oper VARCHAR2(10);
    v_changed BOOLEAN := TRUE;
    v_session_user VARCHAR2(100);
    v_os_user VARCHAR2(100);
    v_host VARCHAR2(100);
    v_module VARCHAR2(100);
    v_program VARCHAR2(100);
    v_cli_ident VARCHAR2(100);
	--
    v_login_code_user NUMBER := 0; -- Placeholder, ao invés de 0 substitua por sua lógica de identificação do usuário a variável de ambiente que joga nesta var
BEGIN
    DBMS_OUTPUT.PUT_LINE('[PASSO 06] Criação/atualização da trigger TB_PESSOAS_EXEMPLO_AIUD:');
    -- Atualiza colunas de auditoria na própria tabela
    IF INSERTING THEN
        :NEW.created_by := v_login_code_user;
        :NEW.created_date := SYSDATE;
        :NEW.modified_by := v_login_code_user;
        :NEW.modified_date := SYSDATE;
    ELSIF UPDATING THEN
        :NEW.modified_by := v_login_code_user;
        :NEW.modified_date := SYSDATE;
    END IF;
    -- Verifica se a auditoria está ativa
    OPEN c_activar;
    FETCH c_activar INTO v_aud_activa;
    CLOSE c_activar;
	--
    IF NVL(v_aud_activa, 'N') NOT IN ('S', '1', 'TRUE', 'SIM', 'YES') THEN
        DBMS_OUTPUT.PUT_LINE('Auditoria desativada para TB_PESSOAS_EXEMPLO.');
        RETURN;
    END IF;
    -- Captura informações de contexto
    BEGIN v_session_user := SYS_CONTEXT('USERENV', 'SESSION_USER'); EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN v_os_user := SYS_CONTEXT('USERENV', 'OS_USER'); EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN v_host := SYS_CONTEXT('USERENV', 'HOST'); EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN v_module := SYS_CONTEXT('USERENV', 'MODULE'); EXCEPTION WHEN OTHERS THEN NULL; END; -- Se os dados estiverem sendo manipulados no Oracle Forms aqui você poderá ver o form em questão
    BEGIN v_cli_ident := SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'); EXCEPTION WHEN OTHERS THEN NULL; END;
    --
	BEGIN 
        SELECT program INTO v_program 
        FROM v$session 
        WHERE audsid = USERENV('SESSIONID') AND ROWNUM <= 1;
    EXCEPTION 
		WHEN OTHERS THEN NULL; 
	END;
    -- Define a operação
    IF INSERTING THEN
        v_oper := 'INSERT';
    ELSIF UPDATING THEN
        v_oper := 'UPDATE';
    ELSIF DELETING THEN
        v_oper := 'DELETE';
    ELSE
        v_oper := 'UNKNOWN';
    END IF;
    -- Verifica se houve alterações em UPDATE
    IF UPDATING THEN
        IF NVL(TO_CHAR(:OLD.id), '@!#$') = NVL(TO_CHAR(:NEW.id), '@!#$')
           AND NVL(:OLD.nome, '@!#$') = NVL(:NEW.nome, '@!#$')
           AND NVL(TO_CHAR(:OLD.nascimento, 'DD-MM-YYYY'), '@!#$') = NVL(TO_CHAR(:NEW.nascimento, 'DD-MM-YYYY'), '@!#$')
           AND NVL(:OLD.email, '@!#$') = NVL(:NEW.email, '@!#$')
           AND NVL(:OLD.cep, '@!#$') = NVL(:NEW.cep, '@!#$')
           AND NVL(TO_CHAR(:OLD.created_by), '@!#$') = NVL(TO_CHAR(:NEW.created_by), '@!#$')
           AND NVL(TO_CHAR(:OLD.created_date, 'DD-MM-YYYY'), '@!#$') = NVL(TO_CHAR(:NEW.created_date, 'DD-MM-YYYY'), '@!#$')
           AND NVL(TO_CHAR(:OLD.modified_by), '@!#$') = NVL(TO_CHAR(:NEW.modified_by), '@!#$')
           AND NVL(TO_CHAR(:OLD.modified_date, 'DD-MM-YYYY'), '@!#$') = NVL(TO_CHAR(:NEW.modified_date, 'DD-MM-YYYY'), '@!#$')
        THEN
            v_changed := FALSE;
        END IF;
    END IF;
    -- Registra na auditoria se houve alterações
    IF v_changed THEN
        DBMS_OUTPUT.PUT_LINE('TB_PESSOAS_EXEMPLO_AIUD: Houveram alterações! Operação: ' || v_oper);
		--
        IF INSERTING THEN
            INSERT INTO tb_pessoas_exemplo_aud (
                id_pessoa, nome, nascimento, email, cep,
                created_by, created_date, modified_by, modified_date,
                audit_date, operation_type, operation_step,
                username, osuser, machine, module, program, inserted_by_app
            ) VALUES (
                :NEW.id, :NEW.nome, :NEW.nascimento, :NEW.email, :NEW.cep,
                :NEW.created_by, :NEW.created_date, :NEW.modified_by, :NEW.modified_date,
                v_date, v_oper, NULL,
                v_session_user, v_os_user, v_host, v_module, v_program, v_cli_ident
            );
        ELSIF UPDATING OR DELETING THEN
            INSERT INTO tb_pessoas_exemplo_aud (
                id_pessoa, nome, nascimento, email, cep,
                created_by, created_date, modified_by, modified_date,
                audit_date, operation_type, operation_step,
                username, osuser, machine, module, program, inserted_by_app
            ) VALUES (
                :OLD.id, :OLD.nome, :OLD.nascimento, :OLD.email, :OLD.cep,
                :OLD.created_by, :OLD.created_date, :OLD.modified_by, :OLD.modified_date,
                v_date, v_oper, NULL,
                v_session_user, v_os_user, v_host, v_module, v_program, v_cli_ident
            );
        END IF;
    ELSE
        DBMS_OUTPUT.PUT_LINE('TB_PESSOAS_EXEMPLO_AIUD: Não houveram alterações. Operação: ' || v_oper);
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erro na trigger: SQLCODE: ' || NVL(TO_CHAR(SQLCODE), 'NULL'));
        NULL; -- Em produção, considere logar em uma tabela de erros
END;

/

-- Passo 7: Finalização
BEGIN
    DBMS_OUTPUT.PUT_LINE('[FIM DO SCRIPT]');
END;

/
