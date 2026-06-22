-- Script para popular a tabela com uma volumetria considerável de dados de teste (100.000 registros)
-- Autor: Nelson Carlson F.
-- Data: 22-06-2026

DECLARE
    v_rows NUMBER := 100000;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Iniciando geração de dados de teste...');
    
    -- Limpa a tabela caso já contenha dados de execuções anteriores
    EXECUTE IMMEDIATE 'TRUNCATE TABLE tb_processamento_massa';
    
    -- Inserção em massa ultra rápida usando CONNECT BY e DUAL
    INSERT /*+ APPEND */ INTO tb_processamento_massa (descricao, valor_base, status_processo)
    SELECT 
        'Transação Financeira #' || LEVEL,
        ROUND(DBMS_RANDOM.VALUE(10, 10000), 2),
        'PENDENTE'
    FROM DUAL
    CONNECT BY LEVEL <= v_rows;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Tabela tb_processamento_massa populada com ' || v_rows || ' registros com sucesso!');
END;
/
