
/*
Autor: Nelson Carlson F. 
Data: 22-09-2025
--
Estas fun��es do bloco an�nimo voc� tamb�m pode jogar em um package, ou diretamento na BD atrav�s de um 
CREATE OR REPLACE FUNCTION Format_SQL ... e um CREATE OR REPLACE PROCEDURE Show_Qry_Values
*/

DECLARE
	v_sql CLOB;
	
	-- Fun��o para formatar c�digos SQL passando query e par�metros
	FUNCTION Format_Sql( p_template IN VARCHAR2, p_values IN SYS.ODCIVARCHAR2LIST ) 
	RETURN CLOB 
	IS
		v_result CLOB := p_template;
	BEGIN
		--
		FOR i IN 1 .. p_values.COUNT LOOP
			v_result := REGEXP_REPLACE(v_result, '\?', p_values(i), 1, 1);
		END LOOP;
		--
		RETURN v_result;
	END;
	
	-- Proc que ir� produzir a extra��o
	PROCEDURE Show_Qry_Values(p_sql CLOB)
	IS
		v_cursor	INTEGER;
		v_col_cnt	INTEGER;
		v_desc_tab	Dbms_Sql.desc_tab;
		v_val_vc	VARCHAR2(4000);
		v_val_dt	DATE;
		v_rowid		INTEGER;
		v_rownum	INTEGER := 0;
		V_ASPA		VARCHAR2(1) := '''';
	BEGIN
		v_cursor := Dbms_Sql.open_cursor;
		Dbms_Sql.parse(v_cursor, v_sql, DBMS_SQL.NATIVE); -- atribuindo o texto da query ao cursor
		Dbms_Sql.describe_columns(v_cursor, v_col_cnt, v_desc_tab); -- obtendo o n�mero de campos (v_col_cnt) e a descri��o dos campos (vari�vel v_desc_tab)
		-- 
		FOR i IN 1 .. v_col_cnt LOOP
			IF v_desc_tab(i).col_type = 12 THEN -- tipo DATE
				Dbms_Sql.define_column(v_cursor, i, v_val_dt);
			ELSE -- outros tipos
				Dbms_Sql.define_column(v_cursor, i, v_val_vc, 4000);
			END IF;
		END LOOP;
		--
		v_rowid := Dbms_Sql.execute(v_cursor);
		WHILE Dbms_Sql.fetch_rows(v_cursor) > 0 
		LOOP
			v_rownum := v_rownum + 1;
			Dbms_Output.put_line('ROWNUM = ' || v_rownum);
			FOR i IN 1 .. v_col_cnt LOOP
				IF v_desc_tab(i).col_type = 12 THEN	-- coluna do tipo DATE
					Dbms_Sql.column_value(v_cursor, i, v_val_dt);
					Dbms_Output.put_line('    ' || v_desc_tab(i).col_name || ' = ' || V_ASPA || TO_CHAR(v_val_dt, 'dd-mm-yyyy hh24:mi') || V_ASPA);
				ELSIF v_desc_tab(i).col_type IN (1, 96) THEN -- coluna do tipo VARCHAR2, ou CHAR
					Dbms_Sql.column_value(v_cursor, i, v_val_vc);
					Dbms_Output.put_line('    ' || v_desc_tab(i).col_name || ' = ' || V_ASPA || v_val_vc || V_ASPA);
				ELSE -- outros tipos
					Dbms_Sql.column_value(v_cursor, i, v_val_vc);
					Dbms_Output.put_line('    ' || v_desc_tab(i).col_name || ' = ' || v_val_vc);
				END IF;
    		END LOOP;
			Dbms_Output.put_line('---');
		END LOOP;
		--
		Dbms_Sql.close_cursor(v_cursor);
	END;
BEGIN

	-- Passando o c�digo SQL para a vari�vel
  	v_sql := 
		' SELECT InitCap(nome) nome, nascimento, email, CEP '
		|| ' FROM tb_pessoas_exemplo '
		|| ' WHERE nascimento BETWEEN To_Date(''?'', ''dd-mm-yyyy'') AND To_Date(''?'', ''dd-mm-yyyy'') ';
	
	-- Mudando o c�digo passado com os par�metros passados atrav�s da fun��o que est� acima, a Format_Sql (que voc� pode colocar num package ou no banco)
	v_sql := Format_Sql( v_sql, SYS.ODCIVARCHAR2LIST( '01-01-1995', '01-01-2020' ) );
	
	-- Executando a extra��o de dados
	Show_Qry_Values( v_sql );
	--
	
	-- Obs.: 
	-- Isto tudo evita que voc� tenha que abrir um cursor, que verifique se h� dados no cursor, depois tenha que concatenar vari�veis, para 
	-- obter uma sa�da de dados via DBMS.
END; 
--