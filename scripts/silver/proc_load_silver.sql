/*
===============================================================================
Stored Procedure: Carga da camada Silver (Bronze -> Silver) - PostgreSQL
===============================================================================
Objetivo do script:
    Cria a procedure 'silver.load_silver', que lê as tabelas do schema
    'bronze', limpa e padroniza os dados e grava nas tabelas do schema
    'silver'. Para cada tabela, ela:
      - Esvazia a tabela antes da carga (TRUNCATE), para que rodar a
        procedure várias vezes não duplique dados;
      - Insere os dados já tratados (deduplicação, trim, padronização de
        valores, conversão de datas e tratamento de valores inválidos);
      - Mostra mensagens de progresso, a quantidade de linhas carregadas
        e o tempo gasto em cada etapa, além da duração total.

    Em caso de erro, mostra a mensagem e o código do erro e desfaz toda a
    carga (rollback): a Silver volta ao estado anterior à execução.

    A coluna técnica 'dwh_create_date' não é preenchida aqui: ela recebe
    now() pelo DEFAULT definido em ddl_silver.sql.

Pré-requisitos:
    - Tabelas da Bronze carregadas (CALL bronze.load_bronze();)
    - Tabelas da Silver criadas (scripts/silver/ddl_silver.sql)

Como usar:
    CALL silver.load_silver();

Observação:
    Este arquivo apenas cria (ou atualiza) a procedure; a carga só acontece
    quando você executa o CALL acima.
===============================================================================
*/

CREATE OR REPLACE PROCEDURE silver.load_silver()
LANGUAGE plpgsql
AS $$
DECLARE
    v_inicio        TIMESTAMP;
    v_inicio_total  TIMESTAMP;
    v_linhas        BIGINT;
BEGIN
    -- clock_timestamp() mede o horário real; NOW() ficaria parado
    -- no início da transação e todas as durações dariam zero.
    v_inicio_total := clock_timestamp();

    RAISE NOTICE '================================================';
    RAISE NOTICE 'Carregando a camada Silver';
    RAISE NOTICE '================================================';

    RAISE NOTICE '------------------------------------------------';
    RAISE NOTICE 'Carregando tabelas do CRM';
    RAISE NOTICE '------------------------------------------------';

    -- =========================================================================
    -- silver.crm_cust_info
    -- =========================================================================
    v_inicio := clock_timestamp();
    RAISE NOTICE '>> Truncando tabela: silver.crm_cust_info';
    TRUNCATE TABLE silver.crm_cust_info;
    RAISE NOTICE '>> Inserindo dados em: silver.crm_cust_info';

    INSERT INTO silver.crm_cust_info (
        cst_id,
        cst_key,
        cst_firstname,
        cst_lastname,
        cst_marital_status,
        cst_gndr,
        cst_create_date
    )
    SELECT
        cst_id,
        cst_key,
        TRIM(cst_firstname),
        TRIM(cst_lastname),
        CASE UPPER(TRIM(cst_marital_status))
            WHEN 'S' THEN 'Single'
            WHEN 'M' THEN 'Married'
            ELSE 'n/a'
        END,
        CASE UPPER(TRIM(cst_gndr))
            WHEN 'F' THEN 'Female'
            WHEN 'M' THEN 'Male'
            ELSE 'n/a'
        END,
        cst_create_date
    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY cst_id
                ORDER BY cst_create_date DESC
            ) AS row_num
        FROM bronze.crm_cust_info
        WHERE cst_id IS NOT NULL
    ) t
    WHERE row_num = 1;

    GET DIAGNOSTICS v_linhas = ROW_COUNT;
    RAISE NOTICE '>> % linhas carregadas em % segundos', v_linhas,
        ROUND(EXTRACT(EPOCH FROM (clock_timestamp() - v_inicio))::NUMERIC, 2);
    RAISE NOTICE '>> -------------';

    -- =========================================================================
    -- silver.crm_prd_info
    -- =========================================================================
    v_inicio := clock_timestamp();
    RAISE NOTICE '>> Truncando tabela: silver.crm_prd_info';
    TRUNCATE TABLE silver.crm_prd_info;
    RAISE NOTICE '>> Inserindo dados em: silver.crm_prd_info';

    INSERT INTO silver.crm_prd_info (
        prd_id,
        cat_id,
        prd_key,
        prd_nm,
        prd_cost,
        prd_line,
        prd_start_dt,
        prd_end_dt
    )
    SELECT
        prd_id,
        -- 'CO-PE' (pedais) não existe em erp_px_cat_g1v2, onde a categoria de
        -- pedais é 'CO_PD': corrigido aqui para que o produto ache a categoria.
        CASE REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_')
            WHEN 'CO_PE' THEN 'CO_PD'
            ELSE REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_')
        END,
        SUBSTRING(prd_key, 7, LENGTH(prd_key)),
        prd_nm,
        COALESCE(prd_cost, 0),
        CASE UPPER(TRIM(prd_line))
            WHEN 'R' THEN 'Road'
            WHEN 'M' THEN 'Mountain'
            WHEN 'S' THEN 'Other sales'
            WHEN 'T' THEN 'Touring'
            ELSE 'n/a'
        END,
        CAST(prd_start_dt AS DATE),
        CAST(
            LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt)
            - INTERVAL '1 day'
            AS DATE
        )
    FROM bronze.crm_prd_info;

    GET DIAGNOSTICS v_linhas = ROW_COUNT;
    RAISE NOTICE '>> % linhas carregadas em % segundos', v_linhas,
        ROUND(EXTRACT(EPOCH FROM (clock_timestamp() - v_inicio))::NUMERIC, 2);
    RAISE NOTICE '>> -------------';

    -- =========================================================================
    -- silver.crm_sales_details
    -- =========================================================================
    v_inicio := clock_timestamp();
    RAISE NOTICE '>> Truncando tabela: silver.crm_sales_details';
    TRUNCATE TABLE silver.crm_sales_details;
    RAISE NOTICE '>> Inserindo dados em: silver.crm_sales_details';

    INSERT INTO silver.crm_sales_details (
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        sls_order_dt,
        sls_ship_dt,
        sls_due_dt,
        sls_sales,
        sls_quantity,
        sls_price
    )
    SELECT
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        -- Data do pedido inválida (0 ou fora do padrão): em 100% das vendas com
        -- data válida o envio ocorre exatamente 7 dias depois do pedido, então
        -- a data é recuperada como (data de envio - 7 dias).
        CASE
            WHEN LENGTH(sls_order_dt::TEXT) = 8
             AND sls_order_dt BETWEEN 19000101 AND 20500101
            THEN TO_DATE(sls_order_dt::TEXT, 'YYYYMMDD')
            WHEN LENGTH(sls_ship_dt::TEXT) = 8
             AND sls_ship_dt BETWEEN 19000101 AND 20500101
            THEN TO_DATE(sls_ship_dt::TEXT, 'YYYYMMDD') - 7
        END,
        CASE
            WHEN LENGTH(sls_ship_dt::TEXT) = 8
             AND sls_ship_dt BETWEEN 19000101 AND 20500101
            THEN TO_DATE(sls_ship_dt::TEXT, 'YYYYMMDD')
        END,
        CASE
            WHEN LENGTH(sls_due_dt::TEXT) = 8
             AND sls_due_dt BETWEEN 19000101 AND 20500101
            THEN TO_DATE(sls_due_dt::TEXT, 'YYYYMMDD')
        END,
        CASE
            WHEN sls_sales IS NULL
              OR sls_sales <= 0
              OR sls_sales != sls_quantity * ABS(sls_price)
            THEN sls_quantity * ABS(sls_price)
            ELSE sls_sales
        END,
        CASE
            WHEN sls_quantity IS NULL
              OR sls_quantity <= 0
            THEN sls_sales / NULLIF(sls_price, 0)
            ELSE sls_quantity
        END,
        CASE
            WHEN sls_price IS NULL
              OR sls_price <= 0
            THEN sls_sales / NULLIF(sls_quantity, 0)
            ELSE sls_price
        END
    FROM bronze.crm_sales_details;

    GET DIAGNOSTICS v_linhas = ROW_COUNT;
    RAISE NOTICE '>> % linhas carregadas em % segundos', v_linhas,
        ROUND(EXTRACT(EPOCH FROM (clock_timestamp() - v_inicio))::NUMERIC, 2);
    RAISE NOTICE '>> -------------';

    RAISE NOTICE '------------------------------------------------';
    RAISE NOTICE 'Carregando tabelas do ERP';
    RAISE NOTICE '------------------------------------------------';

    -- =========================================================================
    -- silver.erp_cust_az12
    --   - cid: remove o prefixo 'NAS' para casar com crm_cust_info.cst_key
    --   - bdate: datas fora de 1924-01-01 a 2024-12-31 viram NULL
    --   - gen: padroniza (M/Male -> Male, F/Female -> Female, demais -> n/a)
    -- =========================================================================
    v_inicio := clock_timestamp();
    RAISE NOTICE '>> Truncando tabela: silver.erp_cust_az12';
    TRUNCATE TABLE silver.erp_cust_az12;
    RAISE NOTICE '>> Inserindo dados em: silver.erp_cust_az12';

    INSERT INTO silver.erp_cust_az12 (
        cid,
        bdate,
        gen
    )
    SELECT
        CASE
            WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LENGTH(cid))
            ELSE cid
        END,
        CASE
            WHEN bdate < DATE '1924-01-01' THEN NULL
            WHEN bdate > DATE '2024-12-31' THEN NULL
            ELSE bdate
        END,
        CASE
            WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
            WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
            ELSE 'n/a'
        END
    FROM bronze.erp_cust_az12;

    GET DIAGNOSTICS v_linhas = ROW_COUNT;
    RAISE NOTICE '>> % linhas carregadas em % segundos', v_linhas,
        ROUND(EXTRACT(EPOCH FROM (clock_timestamp() - v_inicio))::NUMERIC, 2);
    RAISE NOTICE '>> -------------';

    -- =========================================================================
    -- silver.erp_loc_a101
    --   - cid: remove os hífens para casar com crm_cust_info.cst_key
    --   - cntry: trim e padronização (DE -> Germany, US/USA -> United States,
    --     nulo/vazio -> n/a)
    -- =========================================================================
    v_inicio := clock_timestamp();
    RAISE NOTICE '>> Truncando tabela: silver.erp_loc_a101';
    TRUNCATE TABLE silver.erp_loc_a101;
    RAISE NOTICE '>> Inserindo dados em: silver.erp_loc_a101';

    INSERT INTO silver.erp_loc_a101 (
        cid,
        cntry
    )
    SELECT
        REPLACE(cid, '-', ''),
        CASE
            WHEN COALESCE(TRIM(cntry), '') = '' THEN 'n/a'
            WHEN TRIM(cntry) = 'DE' THEN 'Germany'
            WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
            ELSE TRIM(cntry)
        END
    FROM bronze.erp_loc_a101;

    GET DIAGNOSTICS v_linhas = ROW_COUNT;
    RAISE NOTICE '>> % linhas carregadas em % segundos', v_linhas,
        ROUND(EXTRACT(EPOCH FROM (clock_timestamp() - v_inicio))::NUMERIC, 2);
    RAISE NOTICE '>> -------------';

    -- =========================================================================
    -- silver.erp_px_cat_g1v2
    --   Dados já limpos na Bronze (sem nulos, vazios, espaços extras ou
    --   duplicidades de id): carga direta, sem transformação.
    -- =========================================================================
    v_inicio := clock_timestamp();
    RAISE NOTICE '>> Truncando tabela: silver.erp_px_cat_g1v2';
    TRUNCATE TABLE silver.erp_px_cat_g1v2;
    RAISE NOTICE '>> Inserindo dados em: silver.erp_px_cat_g1v2';

    INSERT INTO silver.erp_px_cat_g1v2 (
        id,
        cat,
        subcat,
        maintenance
    )
    SELECT
        id,
        cat,
        subcat,
        maintenance
    FROM bronze.erp_px_cat_g1v2;

    GET DIAGNOSTICS v_linhas = ROW_COUNT;
    RAISE NOTICE '>> % linhas carregadas em % segundos', v_linhas,
        ROUND(EXTRACT(EPOCH FROM (clock_timestamp() - v_inicio))::NUMERIC, 2);
    RAISE NOTICE '>> -------------';

    RAISE NOTICE '================================================';
    RAISE NOTICE 'Carga da camada Silver concluída';
    RAISE NOTICE '   - Duração total: % segundos',
        ROUND(EXTRACT(EPOCH FROM (clock_timestamp() - v_inicio_total))::NUMERIC, 2);
    RAISE NOTICE '================================================';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '================================================';
        RAISE NOTICE 'ERRO DURANTE A CARGA DA CAMADA SILVER';
        RAISE NOTICE 'Mensagem: %', SQLERRM;
        RAISE NOTICE 'Código do erro: %', SQLSTATE;
        RAISE NOTICE '================================================';
        -- Repassa o erro adiante: toda a carga é desfeita (rollback)
        -- e a Silver volta ao estado anterior à execução.
        RAISE;
END;
$$;

-- Para executar a carga:
-- CALL silver.load_silver();
