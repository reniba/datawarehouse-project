/*
===============================================================================
DDL: Criação das views da camada Gold (PostgreSQL)
===============================================================================
Objetivo do script:
    Cria as views do schema 'gold', o modelo analítico em esquema estrela,
    calculadas na leitura a partir das tabelas da camada Silver:
      - gold.dim_customers : dimensão de clientes (CRM + ERP)
      - gold.dim_products  : dimensão de produtos ATIVOS, com categoria
      - gold.fact_sales    : fato de vendas, ligada às duas dimensões pelas
                             chaves substitutas (customer_key, product_key)

    Chaves substitutas:
      'customer_key' e 'product_key' são números sequenciais gerados com
      ROW_NUMBER() na própria view. Como a view é recalculada a cada consulta,
      esses números podem mudar se os dados da Silver mudarem; por isso, não
      os guarde fora do data warehouse.

    Regras principais:
      - dim_customers: o gênero vem do CRM e, quando é 'n/a', do ERP;
      - dim_products : só produtos sem data de fim (prd_end_dt IS NULL), com
                       a categoria ligada por cat_id;
      - fact_sales   : usa LEFT JOIN, então nenhuma venda é descartada; uma
                       venda sem cliente ou produto ficaria com a chave NULL
                       (verificado em scripts/tests/quality_check_gold.sql).

Como executar:
    Conectado ao banco 'datawarehouse', DEPOIS de carregar a Silver
    (CALL silver.load_silver();), rode o script inteiro. Ele pode ser
    executado várias vezes: cada view é apagada (DROP VIEW IF EXISTS) e
    recriada. A fato é apagada primeiro porque depende das dimensões.

Depois de executar, rode scripts/tests/quality_check_gold.sql para validar a camada.
===============================================================================
*/

-- A fato depende das dimensões: apague-a primeiro para poder recriar as dimensões
DROP VIEW IF EXISTS gold.fact_sales;

-- =============================================================================
-- gold.dim_customers
-- =============================================================================
DROP VIEW IF EXISTS gold.dim_customers;

CREATE VIEW gold.dim_customers AS (
    select
        ROW_NUMBER() OVER (
            ORDER BY ci.cst_id
        ) as customer_key,
        ci.cst_id as customer_id,
        ci.cst_key as customer_number,
        ci.cst_firstname as first_name,
        ci.cst_lastname as last_name,
        el.cntry as country,
        ci.cst_marital_status as marital_status,
        case
            when ci.cst_gndr != 'n/a' then ci.cst_gndr
            else coalesce(ec.gen, 'n/a')
        end as customer_gender,
        ec.bdate as birth_date,
        ci.cst_create_date as create_date
    from silver.crm_cust_info ci
        left join silver.erp_cust_az12 ec on ci.cst_key = ec.cid
        left join silver.erp_loc_a101 el on ci.cst_key = el.cid
);

-- =============================================================================
-- gold.dim_products (somente produtos ativos)
-- =============================================================================
DROP VIEW IF EXISTS gold.dim_products;

CREATE VIEW gold.dim_products AS (
    SELECT
        ROW_NUMBER() OVER (
            ORDER BY pi.prd_start_dt, pi.prd_key
        ) as product_key,
        pi.prd_id as product_id,
        pi.prd_key as product_number,
        pi.prd_nm as product_name,
        pi.cat_id as product_category_id,
        ec.cat as product_category,
        ec.subcat as product_subcategory,
        ec.maintenance,
        pi.prd_cost as product_cost,
        pi.prd_line as product_line,
        pi.prd_start_dt as start_date,
        pi.prd_end_dt as end_date
    from silver.crm_prd_info pi
        left join silver.erp_px_cat_g1v2 ec on pi.cat_id = ec.id
    where pi.prd_end_dt is null
);

-- =============================================================================
-- gold.fact_sales
-- =============================================================================
DROP VIEW IF EXISTS gold.fact_sales;

CREATE VIEW gold.fact_sales AS (
select
    sd.sls_ord_num as order_number,
    dp.product_key,
    dc.customer_key,
    sd.sls_order_dt as order_date,
    sd.sls_ship_dt as ship_date,
    sd.sls_due_dt as due_date,
    sd.sls_sales as sales,
    sd.sls_quantity as quantity,
    sd.sls_price as price
from silver.crm_sales_details sd
    left join gold.dim_products dp on sd.sls_prd_key = dp.product_number
    left join gold.dim_customers dc on sd.sls_cust_id = dc.customer_id
);
