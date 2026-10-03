/*
===============================================================================
Testes de qualidade: camada Gold (Silver -> Gold) - PostgreSQL
===============================================================================
Objetivo do script:
    Valida o modelo analítico da camada Gold (gold.dim_customers,
    gold.dim_products e gold.fact_sales), conferindo:
      - Chaves substitutas nulas ou duplicadas;
      - Chaves de negócio duplicadas nas dimensões;
      - Espaços indesejados e padronização dos valores;
      - Intervalos e ordem das datas;
      - Consistência entre colunas (venda = quantidade x preço);
      - Integridade referencial da fato com as dimensões;
      - Reconciliação com a Silver (nenhuma linha perdida ou duplicada nos
        JOINs e mesma receita total).

Como executar:
    Conectado ao banco 'datawarehouse', DEPOIS de carregar a Silver e criar as
    views (scripts/gold/ddl_gold.sql), rode o script inteiro.

Como ler o resultado:
    Cada linha é um teste. A coluna 'falhas' mostra quantos registros violam
    a regra; 'status' é OK quando falhas = 0 e FALHA caso contrário.
    Quando um teste falha, use as consultas da seção "Investigação" no fim
    do arquivo para ver os registros problemáticos.
===============================================================================
*/

WITH testes AS (
    -- =========================================================================
    -- gold.dim_customers
    -- =========================================================================
    SELECT 'dim_customers' AS tabela, 'customer_key nulo ou duplicado' AS teste, COUNT(*) AS falhas
    FROM (
        SELECT customer_key FROM gold.dim_customers
        GROUP BY customer_key HAVING COUNT(*) > 1 OR customer_key IS NULL
    ) t
    UNION ALL
    SELECT 'dim_customers', 'customer_id nulo ou duplicado', COUNT(*)
    FROM (
        SELECT customer_id FROM gold.dim_customers
        GROUP BY customer_id HAVING COUNT(*) > 1 OR customer_id IS NULL
    ) t
    UNION ALL
    SELECT 'dim_customers', 'customer_number nulo ou duplicado', COUNT(*)
    FROM (
        SELECT customer_number FROM gold.dim_customers
        GROUP BY customer_number HAVING COUNT(*) > 1 OR customer_number IS NULL
    ) t
    UNION ALL
    SELECT 'dim_customers', 'espaços indesejados (número/nome/sobrenome/país)', COUNT(*)
    FROM gold.dim_customers
    WHERE customer_number != TRIM(customer_number)
       OR first_name != TRIM(first_name)
       OR last_name != TRIM(last_name)
       OR country != TRIM(country)
    UNION ALL
    SELECT 'dim_customers', 'estado civil fora de Single/Married/n/a', COUNT(*)
    FROM gold.dim_customers
    WHERE marital_status IS NULL OR marital_status NOT IN ('Single', 'Married', 'n/a')
    UNION ALL
    SELECT 'dim_customers', 'gênero fora de Male/Female/n/a', COUNT(*)
    FROM gold.dim_customers
    WHERE customer_gender IS NULL OR customer_gender NOT IN ('Male', 'Female', 'n/a')
    UNION ALL
    SELECT 'dim_customers', 'país nulo, vazio ou com sigla (DE/US/USA)', COUNT(*)
    FROM gold.dim_customers
    WHERE country IS NULL OR country = '' OR country IN ('DE', 'US', 'USA')
    UNION ALL
    SELECT 'dim_customers', 'nascimento fora de 1924-01-01 a hoje', COUNT(*)
    FROM gold.dim_customers
    WHERE birth_date < DATE '1924-01-01' OR birth_date > CURRENT_DATE
    UNION ALL
    SELECT 'dim_customers', 'data de cadastro nula ou futura', COUNT(*)
    FROM gold.dim_customers
    WHERE create_date IS NULL OR create_date > CURRENT_DATE
    UNION ALL
    SELECT 'dim_customers', 'gênero n/a mesmo havendo gênero no ERP', COUNT(*)
    FROM gold.dim_customers c
    JOIN silver.erp_cust_az12 e ON e.cid = c.customer_number
    WHERE c.customer_gender = 'n/a' AND e.gen != 'n/a'
    UNION ALL
    SELECT 'dim_customers', 'linhas != clientes da Silver', ABS(
        (SELECT COUNT(*) FROM gold.dim_customers) - (SELECT COUNT(*) FROM silver.crm_cust_info))
    -- =========================================================================
    -- gold.dim_products
    -- =========================================================================
UNION ALL
    SELECT 'dim_products', 'product_key nulo ou duplicado', COUNT(*)
    FROM (
        SELECT product_key FROM gold.dim_products
        GROUP BY product_key HAVING COUNT(*) > 1 OR product_key IS NULL
    ) t
    UNION ALL
    SELECT 'dim_products', 'product_number nulo ou duplicado', COUNT(*)
    FROM (
        SELECT product_number FROM gold.dim_products
        GROUP BY product_number HAVING COUNT(*) > 1 OR product_number IS NULL
    ) t
    UNION ALL
    SELECT 'dim_products', 'product_id nulo ou duplicado', COUNT(*)
    FROM (
        SELECT product_id FROM gold.dim_products
        GROUP BY product_id HAVING COUNT(*) > 1 OR product_id IS NULL
    ) t
    UNION ALL
    SELECT 'dim_products', 'espaços indesejados', COUNT(*)
    FROM gold.dim_products
    WHERE product_number != TRIM(product_number)
       OR product_name != TRIM(product_name)
       OR product_category != TRIM(product_category)
       OR product_subcategory != TRIM(product_subcategory)
    UNION ALL
    SELECT 'dim_products', 'produto sem categoria ou subcategoria', COUNT(*)
    FROM gold.dim_products
    WHERE product_category IS NULL OR product_subcategory IS NULL
       OR COALESCE(product_category, '') = '' OR COALESCE(product_subcategory, '') = ''
    UNION ALL
    SELECT 'dim_products', 'manutenção fora de Yes/No', COUNT(*)
    FROM gold.dim_products
    WHERE maintenance IS NULL OR maintenance NOT IN ('Yes', 'No')
    UNION ALL
    SELECT 'dim_products', 'linha de produto fora do padrão', COUNT(*)
    FROM gold.dim_products
    WHERE product_line IS NULL
       OR product_line NOT IN ('Road', 'Mountain', 'Other sales', 'Touring', 'n/a')
    UNION ALL
    SELECT 'dim_products', 'custo nulo ou negativo', COUNT(*)
    FROM gold.dim_products
    WHERE product_cost IS NULL OR product_cost < 0
    UNION ALL
    SELECT 'dim_products', 'data de início nula', COUNT(*)
    FROM gold.dim_products
    WHERE start_date IS NULL
    UNION ALL
    SELECT 'dim_products', 'produto inativo (data de fim preenchida)', COUNT(*)
    FROM gold.dim_products
    WHERE end_date IS NOT NULL
    UNION ALL
    SELECT 'dim_products', 'linhas != produtos ativos da Silver', ABS(
        (SELECT COUNT(*) FROM gold.dim_products)
      - (SELECT COUNT(*) FROM silver.crm_prd_info WHERE prd_end_dt IS NULL))
    -- =========================================================================
    -- gold.fact_sales
    -- =========================================================================
    UNION ALL
    SELECT 'fact_sales', 'pedido+produto nulo ou duplicado', COUNT(*)
    FROM (
        SELECT order_number, product_key FROM gold.fact_sales
        GROUP BY order_number, product_key
        HAVING COUNT(*) > 1 OR order_number IS NULL OR product_key IS NULL
    ) t
    UNION ALL
    SELECT 'fact_sales', 'venda sem product_key (produto não encontrado)', COUNT(*)
    FROM gold.fact_sales
    WHERE product_key IS NULL
    UNION ALL
    SELECT 'fact_sales', 'venda sem customer_key (cliente não encontrado)', COUNT(*)
    FROM gold.fact_sales
    WHERE customer_key IS NULL
    UNION ALL
    SELECT 'fact_sales', 'product_key inexistente na dimensão', COUNT(*)
    FROM gold.fact_sales f
    WHERE f.product_key IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM gold.dim_products p WHERE p.product_key = f.product_key)
    UNION ALL
    SELECT 'fact_sales', 'customer_key inexistente na dimensão', COUNT(*)
    FROM gold.fact_sales f
    WHERE f.customer_key IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM gold.dim_customers c WHERE c.customer_key = f.customer_key)
    UNION ALL
    SELECT 'fact_sales', 'datas nulas', COUNT(*)
    FROM gold.fact_sales
    WHERE order_date IS NULL OR ship_date IS NULL OR due_date IS NULL
    UNION ALL
    SELECT 'fact_sales', 'datas fora do intervalo 1900-2050', COUNT(*)
    FROM gold.fact_sales
    WHERE order_date NOT BETWEEN DATE '1900-01-01' AND DATE '2050-01-01'
       OR ship_date  NOT BETWEEN DATE '1900-01-01' AND DATE '2050-01-01'
       OR due_date   NOT BETWEEN DATE '1900-01-01' AND DATE '2050-01-01'
    UNION ALL
    SELECT 'fact_sales', 'pedido posterior ao envio ou ao vencimento', COUNT(*)
    FROM gold.fact_sales
    WHERE order_date > ship_date OR order_date > due_date
    UNION ALL
    SELECT 'fact_sales', 'venda, quantidade ou preço nulo/não positivo', COUNT(*)
    FROM gold.fact_sales
    WHERE sales IS NULL OR sales <= 0
       OR quantity IS NULL OR quantity <= 0
       OR price IS NULL OR price <= 0
    UNION ALL
    SELECT 'fact_sales', 'venda diferente de quantidade x preço', COUNT(*)
    FROM gold.fact_sales
    WHERE sales != quantity * price
    -- =========================================================================
    -- Reconciliação com a Silver
    --   (os JOINs não podem perder nem duplicar vendas)
    -- =========================================================================
    UNION ALL
    SELECT 'fact_sales', 'linhas != vendas da Silver', ABS(
        (SELECT COUNT(*) FROM gold.fact_sales) - (SELECT COUNT(*) FROM silver.crm_sales_details))
    UNION ALL
    SELECT 'fact_sales', 'receita total != receita da Silver', ABS(
        (SELECT COALESCE(SUM(sales), 0) FROM gold.fact_sales)
      - (SELECT COALESCE(SUM(sls_sales), 0) FROM silver.crm_sales_details))
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
-- Chaves duplicadas em dim_customers
SELECT * FROM gold.dim_customers
WHERE customer_id IN (SELECT customer_id FROM gold.dim_customers GROUP BY customer_id HAVING COUNT(*) > 1);

-- Produtos sem categoria: o JOIN usa cat_id, confira se o código existe no ERP
SELECT product_number, product_category_id
FROM gold.dim_products WHERE product_category IS NULL;
SELECT id, cat, subcat FROM silver.erp_px_cat_g1v2 ORDER BY id;

-- Vendas sem cliente ou sem produto (integridade referencial)
SELECT f.*
FROM gold.fact_sales f
WHERE f.product_key IS NULL OR f.customer_key IS NULL;

-- Vendas cujo produto existe na Silver mas está inativo (fora da dim_products)
SELECT s.sls_ord_num, s.sls_prd_key, p.prd_end_dt
FROM silver.crm_sales_details s
JOIN silver.crm_prd_info p ON p.prd_key = s.sls_prd_key
WHERE p.prd_end_dt IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM gold.dim_products d WHERE d.product_number = s.sls_prd_key);

-- Linhas da fato multiplicadas por JOIN (chave duplicada na dimensão)
SELECT order_number, product_key, COUNT(*)
FROM gold.fact_sales GROUP BY 1, 2 HAVING COUNT(*) > 1;

-- Diferença de receita entre Gold e Silver
SELECT (SELECT SUM(sales) FROM gold.fact_sales) AS receita_gold,
       (SELECT SUM(sls_sales) FROM silver.crm_sales_details) AS receita_silver;
===============================================================================
*/
