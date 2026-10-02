/*
===============================================================================
Testes de qualidade: camada Silver (Bronze -> Silver) - PostgreSQL
===============================================================================
Objetivo do script:
Valida a qualidade dos dados da camada Silver depois da carga
(CALL silver.load_silver();), conferindo o que o DDL e a procedure de carga
prometem:
- Chaves primárias nulas ou duplicadas;
- Espaços indesejados no início/fim de textos;
- Padronização e consistência dos valores (domínios permitidos);
- Intervalos de datas inválidos;
- Consistência entre colunas (ex.: vendas = quantidade x preço);
- Integridade entre tabelas (chaves que se conectam);
- Quantidade de linhas Bronze x Silver.

Como executar:
Conectado ao banco 'datawarehouse', DEPOIS de carregar a Silver, rode o
script inteiro.

Como ler o resultado:
Cada linha é um teste. A coluna 'falhas' mostra quantos registros violam
a regra; 'status' é OK quando falhas = 0 e FALHA caso contrário.
Quando um teste falha, use as consultas da seção "Investigação" no fim
do arquivo para ver os registros problemáticos e encontrar a causa.
===============================================================================
*/

WITH testes AS (
-- =========================================================================
-- silver.crm_cust_info
-- =========================================================================
SELECT 'crm_cust_info' AS tabela, 'cst_id nulo ou duplicado' AS teste, COUNT(*) AS falhas
FROM (
        SELECT cst_id
        FROM silver.crm_cust_info
        GROUP BY
            cst_id
        HAVING
            COUNT(*) > 1
            OR cst_id IS NULL
    ) t
UNION ALL
SELECT 'crm_cust_info', 'espaços indesejados (key/nome/sobrenome)', COUNT(*)
FROM silver.crm_cust_info
WHERE
    cst_key != TRIM(cst_key)
    OR cst_firstname != TRIM(cst_firstname)
    OR cst_lastname != TRIM(cst_lastname)
UNION ALL
SELECT 'crm_cust_info', 'estado civil fora de Single/Married/n/a', COUNT(*)
FROM silver.crm_cust_info
WHERE
    cst_marital_status IS NULL
    OR cst_marital_status NOT IN ('Single', 'Married', 'n/a')
UNION ALL
SELECT 'crm_cust_info', 'gênero fora de Male/Female/n/a', COUNT(*)
FROM silver.crm_cust_info
WHERE
    cst_gndr IS NULL
    OR cst_gndr NOT IN ('Male', 'Female', 'n/a')
UNION ALL
SELECT 'crm_cust_info', 'cst_key nulo ou duplicado', COUNT(*)
FROM (
        SELECT cst_key
        FROM silver.crm_cust_info
        GROUP BY
            cst_key
        HAVING
            COUNT(*) > 1
            OR cst_key IS NULL
    ) t
-- =========================================================================
-- silver.crm_prd_info
-- =========================================================================
UNION ALL
SELECT 'crm_prd_info', 'prd_id nulo ou duplicado', COUNT(*)
FROM (
        SELECT prd_id
        FROM silver.crm_prd_info
        GROUP BY
            prd_id
        HAVING
            COUNT(*) > 1
            OR prd_id IS NULL
    ) t
UNION ALL
SELECT 'crm_prd_info', 'espaços indesejados (cat_id/prd_key/prd_nm)', COUNT(*)
FROM silver.crm_prd_info
WHERE
    cat_id != TRIM(cat_id)
    OR prd_key != TRIM(prd_key)
    OR prd_nm != TRIM(prd_nm)
UNION ALL
SELECT 'crm_prd_info', 'custo nulo ou negativo', COUNT(*)
FROM silver.crm_prd_info
WHERE
    prd_cost IS NULL
    OR prd_cost < 0
UNION ALL
SELECT 'crm_prd_info', 'linha de produto fora do padrão', COUNT(*)
FROM silver.crm_prd_info
WHERE
    prd_line IS NULL
    OR prd_line NOT IN (
        'Road',
        'Mountain',
        'Other sales',
        'Touring',
        'n/a'
    )
UNION ALL
SELECT 'crm_prd_info', 'data de fim anterior à de início', COUNT(*)
FROM silver.crm_prd_info
WHERE
    prd_end_dt < prd_start_dt
UNION ALL
SELECT 'crm_prd_info', 'data de início nula', COUNT(*)
FROM silver.crm_prd_info
WHERE
    prd_start_dt IS NULL
UNION ALL
SELECT 'crm_prd_info', 'versões do produto com períodos sobrepostos', COUNT(*)
FROM (
        SELECT prd_end_dt, LEAD(prd_start_dt) OVER (
                PARTITION BY
                    prd_key
                ORDER BY prd_start_dt
            ) AS prox_inicio
        FROM silver.crm_prd_info
    ) t
WHERE
    prd_end_dt >= prox_inicio
UNION ALL
SELECT 'crm_prd_info', 'cat_id com hífen (esperado "_")', COUNT(*)
FROM silver.crm_prd_info
WHERE
    cat_id LIKE '%-%'
-- =========================================================================
-- silver.crm_sales_details
-- =========================================================================
UNION ALL
SELECT 'crm_sales_details', 'pedido+produto nulo ou duplicado', COUNT(*)
FROM (
        SELECT sls_ord_num, sls_prd_key
        FROM silver.crm_sales_details
        GROUP BY
            sls_ord_num, sls_prd_key
        HAVING
            COUNT(*) > 1
            OR sls_ord_num IS NULL
            OR sls_prd_key IS NULL
    ) t
UNION ALL
SELECT 'crm_sales_details', 'espaços indesejados (pedido/produto)', COUNT(*)
FROM silver.crm_sales_details
WHERE
    sls_ord_num != TRIM(sls_ord_num)
    OR sls_prd_key != TRIM(sls_prd_key)
UNION ALL
SELECT 'crm_sales_details', 'datas fora do intervalo 1900-2050', COUNT(*)
FROM silver.crm_sales_details
WHERE
    sls_order_dt NOT BETWEEN DATE '1900-01-01' AND DATE  '2050-01-01'
    OR sls_ship_dt NOT BETWEEN DATE '1900-01-01' AND DATE  '2050-01-01'
    OR sls_due_dt NOT BETWEEN DATE '1900-01-01' AND DATE  '2050-01-01'
UNION ALL
SELECT 'crm_sales_details', 'data do pedido nula', COUNT(*)
FROM silver.crm_sales_details
WHERE
    sls_order_dt IS NULL
UNION ALL
SELECT 'crm_sales_details', 'pedido posterior ao envio ou ao vencimento', COUNT(*)
FROM silver.crm_sales_details
WHERE
    sls_order_dt > sls_ship_dt
    OR sls_order_dt > sls_due_dt
UNION ALL
SELECT 'crm_sales_details', 'venda, quantidade ou preço nulo/não positivo', COUNT(*)
FROM silver.crm_sales_details
WHERE
    sls_sales IS NULL
    OR sls_sales <= 0
    OR sls_quantity IS NULL
    OR sls_quantity <= 0
    OR sls_price IS NULL
    OR sls_price <= 0
UNION ALL
SELECT 'crm_sales_details', 'venda diferente de quantidade x preço', COUNT(*)
FROM silver.crm_sales_details
WHERE
    sls_sales != sls_quantity * sls_price
UNION ALL
SELECT 'crm_sales_details', 'produto sem correspondência em crm_prd_info', COUNT(*)
FROM silver.crm_sales_details s
WHERE
    NOT EXISTS (
        SELECT 1
        FROM silver.crm_prd_info p
        WHERE
            p.prd_key = s.sls_prd_key
    )
UNION ALL
SELECT 'crm_sales_details', 'cliente sem correspondência em crm_cust_info', COUNT(*)
FROM silver.crm_sales_details s
WHERE
    NOT EXISTS (
        SELECT 1
        FROM silver.crm_cust_info c
        WHERE
            c.cst_id = s.sls_cust_id
    )
-- =========================================================================
-- silver.erp_cust_az12
-- =========================================================================
UNION ALL
SELECT 'erp_cust_az12', 'cid nulo ou duplicado', COUNT(*)
FROM (
        SELECT cid
        FROM silver.erp_cust_az12
        GROUP BY
            cid
        HAVING
            COUNT(*) > 1
            OR cid IS NULL
    ) t
UNION ALL
SELECT 'erp_cust_az12', 'espaços indesejados (cid)', COUNT(*)
FROM silver.erp_cust_az12
WHERE
    cid != TRIM(cid)
UNION ALL
SELECT 'erp_cust_az12', 'cid ainda com prefixo NAS', COUNT(*)
FROM silver.erp_cust_az12
WHERE
    cid LIKE 'NAS%'
UNION ALL
SELECT 'erp_cust_az12', 'gênero fora de Male/Female/n/a', COUNT(*)
FROM silver.erp_cust_az12
WHERE
    gen IS NULL
    OR gen NOT IN ('Male', 'Female', 'n/a')
UNION ALL
SELECT 'erp_cust_az12', 'nascimento fora de 1924-01-01 a hoje', COUNT(*)
FROM silver.erp_cust_az12
WHERE
    bdate < DATE '1924-01-01'
    OR bdate > CURRENT_DATE
UNION ALL
SELECT 'erp_cust_az12', 'cid sem correspondência em crm_cust_info', COUNT(*)
FROM silver.erp_cust_az12 e
WHERE
    NOT EXISTS (
        SELECT 1
        FROM silver.crm_cust_info c
        WHERE
            c.cst_key = e.cid
    )
-- =========================================================================
-- silver.erp_loc_a101
-- =========================================================================
UNION ALL
SELECT 'erp_loc_a101', 'cid nulo ou duplicado', COUNT(*)
FROM (
        SELECT cid
        FROM silver.erp_loc_a101
        GROUP BY
            cid
        HAVING
            COUNT(*) > 1
            OR cid IS NULL
    ) t
UNION ALL
SELECT 'erp_loc_a101', 'espaços indesejados (cid/cntry)', COUNT(*)
FROM silver.erp_loc_a101
WHERE
    cid != TRIM(cid)
    OR cntry != TRIM(cntry)
UNION ALL
SELECT 'erp_loc_a101', 'cid com hífen', COUNT(*)
FROM silver.erp_loc_a101
WHERE
    cid LIKE '%-%'
UNION ALL
SELECT 'erp_loc_a101', 'país nulo, vazio ou com sigla (DE/US/USA)', COUNT(*)
FROM silver.erp_loc_a101
WHERE
    cntry IS NULL
    OR cntry = ''
    OR cntry IN ('DE', 'US', 'USA')
UNION ALL
SELECT 'erp_loc_a101', 'cid sem correspondência em crm_cust_info', COUNT(*)
FROM silver.erp_loc_a101 l
WHERE
    NOT EXISTS (
        SELECT 1
        FROM silver.crm_cust_info c
        WHERE
            c.cst_key = l.cid
    )
-- =========================================================================
-- silver.erp_px_cat_g1v2
-- =========================================================================
UNION ALL
SELECT 'erp_px_cat_g1v2', 'id nulo ou duplicado', COUNT(*)
FROM (
        SELECT id
        FROM silver.erp_px_cat_g1v2
        GROUP BY
            id
        HAVING
            COUNT(*) > 1
            OR id IS NULL
    ) t
UNION ALL
SELECT 'erp_px_cat_g1v2', 'espaços indesejados', COUNT(*)
FROM silver.erp_px_cat_g1v2
WHERE
    id != TRIM(id)
    OR cat != TRIM(cat)
    OR subcat != TRIM(subcat)
    OR maintenance != TRIM(maintenance)
UNION ALL
SELECT 'erp_px_cat_g1v2', 'manutenção fora de Yes/No', COUNT(*)
FROM silver.erp_px_cat_g1v2
WHERE
    maintenance IS NULL
    OR maintenance NOT IN ('Yes', 'No')
UNION ALL
SELECT 'erp_px_cat_g1v2', 'categoria, subcategoria nula ou vazia', COUNT(*)
FROM silver.erp_px_cat_g1v2
WHERE
    COALESCE(cat, '') = ''
    OR COALESCE(subcat, '') = ''
UNION ALL
SELECT 'crm_prd_info', 'cat_id sem correspondência em erp_px_cat_g1v2', COUNT(*)
FROM silver.crm_prd_info p
WHERE
    NOT EXISTS (
        SELECT 1
        FROM silver.erp_px_cat_g1v2 c
        WHERE
            c.id = p.cat_id
    )
-- =========================================================================
-- Quantidade de linhas: Bronze x Silver
--   (a Silver só pode ter menos linhas onde há deduplicação)
-- =========================================================================
UNION ALL
    SELECT 'crm_cust_info', 'linhas Silver != clientes distintos da Bronze', ABS(
        (SELECT COUNT(*) FROM silver.crm_cust_info)
      - (SELECT COUNT(DISTINCT cst_id) FROM bronze.crm_cust_info WHERE cst_id IS NOT NULL))
    UNION ALL
    SELECT 'crm_prd_info', 'linhas Silver != Bronze', ABS(
        (SELECT COUNT(*) FROM silver.crm_prd_info) - (SELECT COUNT(*) FROM bronze.crm_prd_info))
    UNION ALL
    SELECT 'crm_sales_details', 'linhas Silver != Bronze', ABS(
        (SELECT COUNT(*) FROM silver.crm_sales_details) - (SELECT COUNT(*) FROM bronze.crm_sales_details))
    UNION ALL
    SELECT 'erp_cust_az12', 'linhas Silver != Bronze', ABS(
        (SELECT COUNT(*) FROM silver.erp_cust_az12) - (SELECT COUNT(*) FROM bronze.erp_cust_az12))
    UNION ALL
    SELECT 'erp_loc_a101', 'linhas Silver != Bronze', ABS(
        (SELECT COUNT(*) FROM silver.erp_loc_a101) - (SELECT COUNT(*) FROM bronze.erp_loc_a101))
    UNION ALL
    SELECT 'erp_px_cat_g1v2', 'linhas Silver != Bronze', ABS(
        (SELECT COUNT(*) FROM silver.erp_px_cat_g1v2) - (SELECT COUNT(*) FROM bronze.erp_px_cat_g1v2))
)
SELECT
    tabela,
    teste,
    falhas,
    CASE WHEN falhas = 0 THEN 'OK' ELSE 'FALHA' END AS status
FROM testes
ORDER BY (falhas = 0), tabela, teste;
/*
===============================================================================
Investigação (rode manualmente quando um teste acima falhar)
===============================================================================
-- Chaves duplicadas em crm_cust_info: mostra as linhas repetidas
SELECT * FROM silver.crm_cust_info
WHERE cst_id IN (SELECT cst_id FROM silver.crm_cust_info GROUP BY cst_id HAVING COUNT(*) > 1);

-- Produtos cuja categoria não existe em erp_px_cat_g1v2
SELECT p.prd_id, p.cat_id, p.prd_key, p.prd_nm
FROM silver.crm_prd_info p
WHERE NOT EXISTS (SELECT 1 FROM silver.erp_px_cat_g1v2 c WHERE c.id = p.cat_id);
-- ... e as categorias que existem no mesmo grupo, para achar o código correto:
SELECT id, cat, subcat FROM bronze.erp_px_cat_g1v2 ORDER BY id;

-- Vendas com data de pedido nula: valores originais na Bronze
SELECT sls_ord_num, sls_order_dt, sls_ship_dt, sls_due_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt = 0 OR LENGTH(sls_order_dt::TEXT) != 8;

-- Intervalo entre pedido e envio (regra usada para recuperar datas nulas)
SELECT (sls_ship_dt - sls_order_dt) AS dias_envio, COUNT(*)
FROM silver.crm_sales_details
WHERE sls_order_dt IS NOT NULL
GROUP BY 1 ORDER BY 2 DESC;

-- Vendas diferentes de quantidade x preço
SELECT * FROM silver.crm_sales_details WHERE sls_sales != sls_quantity * sls_price;

-- Chaves do ERP sem par no CRM
SELECT e.cid FROM silver.erp_cust_az12 e
WHERE NOT EXISTS (SELECT 1 FROM silver.crm_cust_info c WHERE c.cst_key = e.cid);
===============================================================================
*/