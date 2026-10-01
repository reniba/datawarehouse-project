-- Active: 1790869083747@@127.0.0.1@5432@datawarehouse
select cci.cst_id, COUNT(*)
from bronze.crm_cust_info cci
group by
    cci.cst_id
having
    count(*) > 1
    or cci.cst_id is null

select *, ROW_NUMBER() OVER (
        PARTITION BY
            cci.cst_id
        ORDER BY cci.cst_create_date DESC
    ) as row_num
from bronze.crm_cust_info cci
where
    cci.cst_id = 29466

select *
from (
        select *, row_number() over (
                partition by
                    cst_id
                order by cst_create_date desc
            ) as row_num
        from bronze.crm_cust_info
    ) t
where
    row_num = 1;

select cst_gndr
from bronze.crm_cust_info
where
    cst_gndr != trim(cst_gndr)

select
    cst_id,
    cst_key,
    trim(cst_firstname) as cst_firstname,
    trim(cst_lastname) as cst_lastname,
    cst_marital_status,
    trim(cst_gndr) as cst_gndr,
    cst_create_date
from bronze.crm_cust_info
where
    cst_gndr != trim(cst_gndr)

select * from bronze.crm_prd_info

select * from bronze.erp_px_cat_g1v2

-- check for nulls and duplicates in bronze.crm_sales_details
select prd_id, COUNT(*)
from bronze.crm_prd_info
group by
    prd_id
having
    COUNT(*) > 1
    or prd_id is null;

select
    prd_id,
    REPLACE(
        substring(prd_key, 1, 5),
        '-',
        '_'
    ) as cat_id,
    substring(prd_key, 7, length(prd_key)) as prd_key,
    prd_nm,
    COALESCE(prd_cost, 0) as prd_cost,
    CASE UPPER(TRIM(prd_line))
        WHEN 'R' THEN 'Road'
        WHEN 'M' THEN 'Mountain'
        WHEN 'S' THEN 'Other sales'
        WHEN 'T' THEN 'Touring'
        ELSE 'n/a'
    END as prd_line,
    cast(prd_start_dt as date) as prd_start_dt,
    cast(
        lead(prd_start_dt) OVER (
            PARTITION BY
                prd_key
            ORDER BY prd_start_dt
        ) - interval '1 day' as date
    ) as prd_end_dt
from bronze.crm_prd_info
where
    prd_key IN (
        'AC-HE-HL-U509-R',
        'AC-HE-HL-U509'
    )

-- check for nulls and duplicates in bronze.crm_sales_details
select prd_nm, COUNT(*)
from bronze.crm_prd_info
group by
    prd_nm
having
    COUNT(*) > 1
    or prd_nm is null;

-- check for nulls and duplicates in bronze.crm_sales_details
select prd_line, COUNT(*)
from bronze.crm_prd_info
group by
    prd_cost
having
    COUNT(*) > 1
    or prd_cost is null
    or prd_cost < 0;

select distinct (prd_line) from bronze.crm_prd_info

select COUNT(*)
from bronze.crm_prd_info
where
    prd_start_dt < prd_end_dt

select * from bronze.crm_sales_details

select
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    (sls_order_dt),
    (sls_ship_dt),
    (sls_due_dt),
    sls_sales,
    sls_quantity,
    sls_price
from bronze.crm_sales_details
WHERE
    sls_prd_key not in (
        select distinct
            prd_key
        from silver.crm_prd_info
    )

select
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    case
        when length(sls_order_dt::text) = 8
        and sls_order_dt between 19000101 and 20500101  then to_date(
            sls_order_dt::text,
            'YYYYMMDD'
        )
    end as sls_order_dt,
    case
        when length(sls_ship_dt::text) = 8
        and sls_ship_dt between 19000101 and 20500101  then to_date(sls_ship_dt::text, 'YYYYMMDD')
    end as sls_ship_dt,
    case
        when length(sls_due_dt::text) = 8
        and sls_due_dt between 19000101 and 20500101  then to_date(sls_due_dt::text, 'YYYYMMDD')
    end as sls_due_dt,
    case
        when sls_sales is null
        or sls_sales <= 0
        or sls_sales != sls_quantity * abs(sls_price) then sls_quantity * abs(sls_price)
        else sls_sales
    end as sls_sales,
    case when sls_quantity is null
        or sls_quantity <= 0 then sls_sales / nullif(sls_price, 0)
        else sls_quantity
    end as sls_quantity,
    case
        when sls_price is null
        or sls_price <= 0 then sls_sales / nullif(sls_quantity, 0)
        else sls_price
    end as sls_price
from bronze.crm_sales_details;