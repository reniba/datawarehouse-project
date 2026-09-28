/*
===============================================================================
Stored Procedure: Carga da camada Bronze (Origem -> Bronze) - PostgreSQL
===============================================================================
Objetivo do script:
    Cria a procedure 'bronze.load_bronze', que carrega os arquivos CSV
    de origem nas tabelas do schema 'bronze'. Para cada tabela, ela:
      - Esvazia a tabela antes da carga (TRUNCATE);
      - Carrega o CSV com o comando COPY (equivalente ao BULK INSERT);
      - Mostra a quantidade de linhas carregadas e o tempo gasto.

Parâmetro:
    p_caminho_base: pasta onde ficam 'source_crm' e 'source_erp'.
    O caminho é lido pelo SERVIDOR PostgreSQL (não pelo cliente psql/pgAdmin),
    então precisa ser um caminho absoluto e válido na máquina onde o
    servidor roda (não há caminho relativo confiável nesse cenário, já que
    ele seria resolvido em relação ao diretório de trabalho do processo do
    servidor, não ao repositório). No Windows, use barras normais: 'C:/datasets'.
    Cada pessoa que rodar a procedure deve ajustar o valor padrão abaixo
    para a sua própria máquina, ou informar o caminho na chamada (ver abaixo).

    Em muitas distros Linux, o serviço 'postgresql' roda em sandbox do
    systemd com 'ProtectHome=true', que torna TODO o /home invisível para
    o processo do servidor (mesmo com as permissões de arquivo corretas).
    Por isso o caminho padrão aqui aponta para fora do /home
    (/srv/datawarehouse-datasets) em vez de para a pasta 'datasets/' do
    repositório. Veja instruções para copiar os CSVs para lá no README.

Como usar:
    CALL bronze.load_bronze();                   -- usa o caminho padrão
    CALL bronze.load_bronze('/outro/caminho');   -- usa outro caminho

===============================================================================
*/

CREATE OR REPLACE PROCEDURE bronze.load_bronze(
    p_caminho_base TEXT DEFAULT '/srv/datawarehouse-datasets'   -- ajuste para a sua pasta
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_inicio        TIMESTAMP;
    v_fim           TIMESTAMP;
    v_inicio_total  TIMESTAMP;
    v_linhas        BIGINT;
BEGIN
    -- clock_timestamp() mede o horário real; NOW() ficaria parado
    -- no início da transação e todas as durações dariam zero.
    v_inicio_total := clock_timestamp();

    RAISE NOTICE '================================================';
    RAISE NOTICE 'Carregando a camada Bronze';
    RAISE NOTICE '================================================';

    -- =========================================================================
    -- Tabelas do CRM
    -- =========================================================================
    RAISE NOTICE '------------------------------------------------';
    RAISE NOTICE 'Carregando tabelas do CRM';
    RAISE NOTICE '------------------------------------------------';

    -- bronze.crm_cust_info
    v_inicio := clock_timestamp();
    RAISE NOTICE '>> Truncando tabela: bronze.crm_cust_info';
    TRUNCATE TABLE bronze.crm_cust_info;
    RAISE NOTICE '>> Inserindo dados em: bronze.crm_cust_info';
    EXECUTE format(
        'COPY bronze.crm_cust_info FROM %L WITH (FORMAT csv, HEADER true, DELIMITER %L)',
        p_caminho_base || '/source_crm/cust_info.csv', ','
    );
    SELECT COUNT(*) INTO v_linhas FROM bronze.crm_cust_info;
    v_fim := clock_timestamp();
    RAISE NOTICE '>> % linhas carregadas em % segundos', v_linhas,
        ROUND(EXTRACT(EPOCH FROM (v_fim - v_inicio))::NUMERIC, 2);
    RAISE NOTICE '>> -------------';

    -- bronze.crm_prd_info
    v_inicio := clock_timestamp();
    RAISE NOTICE '>> Truncando tabela: bronze.crm_prd_info';
    TRUNCATE TABLE bronze.crm_prd_info;
    RAISE NOTICE '>> Inserindo dados em: bronze.crm_prd_info';
    EXECUTE format(
        'COPY bronze.crm_prd_info FROM %L WITH (FORMAT csv, HEADER true, DELIMITER %L)',
        p_caminho_base || '/source_crm/prd_info.csv', ','
    );
    SELECT COUNT(*) INTO v_linhas FROM bronze.crm_prd_info;
    v_fim := clock_timestamp();
    RAISE NOTICE '>> % linhas carregadas em % segundos', v_linhas,
        ROUND(EXTRACT(EPOCH FROM (v_fim - v_inicio))::NUMERIC, 2);
    RAISE NOTICE '>> -------------';

    -- bronze.crm_sales_details
    v_inicio := clock_timestamp();
    RAISE NOTICE '>> Truncando tabela: bronze.crm_sales_details';
    TRUNCATE TABLE bronze.crm_sales_details;
    RAISE NOTICE '>> Inserindo dados em: bronze.crm_sales_details';
    EXECUTE format(
        'COPY bronze.crm_sales_details FROM %L WITH (FORMAT csv, HEADER true, DELIMITER %L)',
        p_caminho_base || '/source_crm/sales_details.csv', ','
    );
    SELECT COUNT(*) INTO v_linhas FROM bronze.crm_sales_details;
    v_fim := clock_timestamp();
    RAISE NOTICE '>> % linhas carregadas em % segundos', v_linhas,
        ROUND(EXTRACT(EPOCH FROM (v_fim - v_inicio))::NUMERIC, 2);
    RAISE NOTICE '>> -------------';

    -- =========================================================================
    -- Tabelas do ERP
    -- =========================================================================
    RAISE NOTICE '------------------------------------------------';
    RAISE NOTICE 'Carregando tabelas do ERP';
    RAISE NOTICE '------------------------------------------------';

    -- bronze.erp_cust_az12
    v_inicio := clock_timestamp();
    RAISE NOTICE '>> Truncando tabela: bronze.erp_cust_az12';
    TRUNCATE TABLE bronze.erp_cust_az12;
    RAISE NOTICE '>> Inserindo dados em: bronze.erp_cust_az12';
    EXECUTE format(
        'COPY bronze.erp_cust_az12 FROM %L WITH (FORMAT csv, HEADER true, DELIMITER %L)',
        p_caminho_base || '/source_erp/CUST_AZ12.csv', ','
    );
    SELECT COUNT(*) INTO v_linhas FROM bronze.erp_cust_az12;
    v_fim := clock_timestamp();
    RAISE NOTICE '>> % linhas carregadas em % segundos', v_linhas,
        ROUND(EXTRACT(EPOCH FROM (v_fim - v_inicio))::NUMERIC, 2);
    RAISE NOTICE '>> -------------';

    -- bronze.erp_loc_a101
    v_inicio := clock_timestamp();
    RAISE NOTICE '>> Truncando tabela: bronze.erp_loc_a101';
    TRUNCATE TABLE bronze.erp_loc_a101;
    RAISE NOTICE '>> Inserindo dados em: bronze.erp_loc_a101';
    EXECUTE format(
        'COPY bronze.erp_loc_a101 FROM %L WITH (FORMAT csv, HEADER true, DELIMITER %L)',
        p_caminho_base || '/source_erp/LOC_A101.csv', ','
    );
    SELECT COUNT(*) INTO v_linhas FROM bronze.erp_loc_a101;
    v_fim := clock_timestamp();
    RAISE NOTICE '>> % linhas carregadas em % segundos', v_linhas,
        ROUND(EXTRACT(EPOCH FROM (v_fim - v_inicio))::NUMERIC, 2);
    RAISE NOTICE '>> -------------';

    -- bronze.erp_px_cat_g1v2
    v_inicio := clock_timestamp();
    RAISE NOTICE '>> Truncando tabela: bronze.erp_px_cat_g1v2';
    TRUNCATE TABLE bronze.erp_px_cat_g1v2;
    RAISE NOTICE '>> Inserindo dados em: bronze.erp_px_cat_g1v2';
    EXECUTE format(
        'COPY bronze.erp_px_cat_g1v2 FROM %L WITH (FORMAT csv, HEADER true, DELIMITER %L)',
        p_caminho_base || '/source_erp/PX_CAT_G1V2.csv', ','
    );
    SELECT COUNT(*) INTO v_linhas FROM bronze.erp_px_cat_g1v2;
    v_fim := clock_timestamp();
    RAISE NOTICE '>> % linhas carregadas em % segundos', v_linhas,
        ROUND(EXTRACT(EPOCH FROM (v_fim - v_inicio))::NUMERIC, 2);
    RAISE NOTICE '>> -------------';

    RAISE NOTICE '================================================';
    RAISE NOTICE 'Carga da camada Bronze concluída';
    RAISE NOTICE '   - Duração total: % segundos',
        ROUND(EXTRACT(EPOCH FROM (clock_timestamp() - v_inicio_total))::NUMERIC, 2);
    RAISE NOTICE '================================================';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '================================================';
        RAISE NOTICE 'ERRO DURANTE A CARGA DA CAMADA BRONZE';
        RAISE NOTICE 'Mensagem: %', SQLERRM;
        RAISE NOTICE 'Código do erro: %', SQLSTATE;
        RAISE NOTICE '================================================';
        -- Repassa o erro adiante: toda a carga é desfeita (rollback)
        -- e a Bronze volta ao estado anterior à execução.
        RAISE;
END;
$$;

-- select * from bronze.crm_cust_info;