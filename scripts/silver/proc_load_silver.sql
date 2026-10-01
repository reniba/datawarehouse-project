CREATE OR REPLACE PROCEDURE silver.load_silver()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Esvazia antes de carregar: assim, rodar a procedure várias vezes não duplica dados

    -- =========================================================================
    -- silver.crm_cust_info
    -- =========================================================================
    TRUNCATE TABLE silver.crm_cust_info;

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

    -- =========================================================================
    -- silver.crm_prd_info
    -- =========================================================================
    TRUNCATE TABLE silver.crm_prd_info;

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
        REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_'),
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

    -- =========================================================================
    -- silver.crm_sales_details
    -- =========================================================================
    TRUNCATE TABLE silver.crm_sales_details;

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
        CASE
            WHEN LENGTH(sls_order_dt::TEXT) = 8
             AND sls_order_dt BETWEEN 19000101 AND 20500101
            THEN TO_DATE(sls_order_dt::TEXT, 'YYYYMMDD')
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
END;
$$;

-- Para executar a carga:
  CALL silver.load_silver();



