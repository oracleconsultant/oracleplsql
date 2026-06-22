-- Implementação prática do Processamento Paralelo usando DBMS_PARALLEL_EXECUTE
-- Autor: Nelson Carlson F.
-- Data: 22-06-2026

DECLARE
    v_task_name VARCHAR2(100) := 'TASK_ATUALIZACAO_MASSA';
    v_sql_stmt  CLOB;
    v_status    NUMBER;
    v_try_count NUMBER := 0;
    v_chunk_size NUMBER := 10000;  -- tamanho de cada chunk de dados (em registros)
    v_parallel_level NUMBER := 4; -- quantidade de threads paralelas (jobs concurrentes)
BEGIN
    DBMS_OUTPUT.PUT_LINE('Iniciando rotina de Processamento Paralelo...');
    
    -- PASSO 1: Garantir que nenhuma task com o mesmo nome esteja ativa
    BEGIN
        DBMS_PARALLEL_EXECUTE.DROP_TASK(task_name => v_task_name);
        DBMS_OUTPUT.PUT_LINE('- Task antiga removida da memória.');
    EXCEPTION
        WHEN OTHERS THEN
            NULL; -- Ignorar se a task não existir
    END;

    -- PASSO 2: Criar a tarefa (Task)
    DBMS_PARALLEL_EXECUTE.CREATE_TASK(task_name => v_task_name);
    DBMS_OUTPUT.PUT_LINE('- Task "' || v_task_name || '" criada com sucesso.');

    -- PASSO 3:  Fragmentar (Chunking) a tabela por ROWID
    --  Isso divide a tabela fisicamente em pedaços lógicos baseados em blocos de dados
    DBMS_PARALLEL_EXECUTE.CREATE_CHUNKS_BY_ROWID(
        task_name   => v_task_name
        ,table_owner => USER
        ,table_name  => 'TB_PROCESSAMENTO_MASSA'
        ,by_row      => TRUE
        ,chunk_size  => v_chunk_size
    );
    DBMS_OUTPUT.PUT_LINE('- Tabela fragmentada em chunks de no máximo ' || v_chunk_size || ' registros.');

    -- PASSO 4: Definir a query DML que será executada em paralelo
    -- OBSERVAÇÃO CRÍTICA: Os placeholders :start_id e :end_id são obrigatórios 
    --   e mapeiam dinamicamente o intervalo de ROWID de cada chunk.
    v_sql_stmt := '
        UPDATE tb_processamento_massa 
        SET 
            valor_atualizado = valor_base * 1.10
            ,status_processo = ''PROCESSADO''
            ,data_processamento = SYSDATE
            ,processado_por_session = ''JOB_PARALELO_'' || SYS_CONTEXT(''USERENV'', ''SESSIONID'')
        WHERE 
            rowid BETWEEN :start_id AND :end_id
        ';

    -- PASSO 5: Executar a task
    -- Isso disparará jobs via DBMS_SCHEDULER rodando concorrentemente de acordo com parallel_level
    DBMS_OUTPUT.PUT_LINE('- Executando chunks em paralelo (Level: ' || v_parallel_level || ')...');
    DBMS_PARALLEL_EXECUTE.RUN_TASK(
        task_name      => v_task_name
        ,sql_stmt       => v_sql_stmt
        ,language_flag  => DBMS_SQL.NATIVE
        ,parallel_level => v_parallel_level
    );

    -- PASSO 6: Verificar status da execução
    -- Se algum chunk falhar por conta de locks ou erros inesperados, tentamos reprocessar os falhos
    v_status := DBMS_PARALLEL_EXECUTE.TASK_STATUS(task_name => v_task_name);
    
    WHILE (v_status != DBMS_PARALLEL_EXECUTE.FINISHED AND v_try_count < 3) 
    LOOP
        v_try_count := v_try_count + 1;
        DBMS_OUTPUT.PUT_LINE('[WARNING] Task não finalizou com sucesso na tentativa ' || v_try_count || '. Status: ' || v_status || '. Tentando retomar...');
        -- Retomar apenas os chunks que falharam (CRITICAL)
        DBMS_PARALLEL_EXECUTE.RESUME_TASK(task_name => v_task_name);
        v_status := DBMS_PARALLEL_EXECUTE.TASK_STATUS(task_name => v_task_name);
    END LOOP;

    IF v_status = DBMS_PARALLEL_EXECUTE.FINISHED THEN
        DBMS_OUTPUT.PUT_LINE('[SUCCESS] Processamento paralelo concluído com sucesso!');
        -- PASSO 7: Limpar a tarefa da memória do banco
        DBMS_PARALLEL_EXECUTE.DROP_TASK(task_name => v_task_name);
        DBMS_OUTPUT.PUT_LINE('- Task deletada com sucesso.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[ERROR] Processamento paralelo falhou ou ficou inacabado. Verifique a view USER_PARALLEL_EXECUTE_CHUNKS.');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('[CRITICAL ERROR] Falha geral no bloco: ' || SQLERRM);
        BEGIN
            DBMS_PARALLEL_EXECUTE.DROP_TASK(task_name => v_task_name);
        EXCEPTION
            WHEN OTHERS THEN 
                NULL;
        END;
        RAISE;
END;
/
