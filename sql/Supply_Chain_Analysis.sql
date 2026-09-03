---------------  Procurement Analysis  ---------------
------------------------------------------------------

-- Supplier Procurement Spend
-- 1. Which suppliers account for the highest total procurement spend?

SELECT
    s.supplier_name,
    ROUND(SUM(f.total_cost)::numeric, 2) AS total_procurement_spend
FROM fact_procurement AS f
JOIN dim_supplier AS s
    ON f.supplier_id = s.supplier_id
GROUP BY
    s.supplier_name
ORDER BY
    total_procurement_spend DESC;


-- Supplier Overall Performance
-- 2. How do suppliers compare in terms of average procurement cost, lead time, and quality?

SELECT
    s.supplier_name,
    ROUND(SUM(f.total_cost)::numeric / NULLIF(SUM(f.order_quantity), 0), 2
    ) AS avg_unit_cost,
    ROUND(AVG(f.lead_time_days)::numeric, 2) AS avg_lead_time_days,
    ROUND(AVG(f.quality_score)::numeric, 2) AS avg_quality_score
FROM fact_procurement AS f
JOIN dim_supplier AS s
    ON f.supplier_id = s.supplier_id
GROUP BY
    s.supplier_name
ORDER BY
    avg_unit_cost ASC;


 -- Procurement Spend Concentration
-- 3. How concentrated is procurement spending across suppliers?

WITH supplier_spend AS (
    SELECT
        s.supplier_name,
        SUM(f.total_cost) AS total_procurement_spend
    FROM fact_procurement AS f
    JOIN dim_supplier AS s
        ON f.supplier_id = s.supplier_id
    GROUP BY
        s.supplier_name
)

SELECT
    supplier_name,
    ROUND(total_procurement_spend::numeric, 2)
        AS total_procurement_spend,
    ROUND(( total_procurement_spend::numeric
            / SUM(total_procurement_spend) OVER ()::numeric) * 100, 2
    ) AS spend_share_pct
FROM supplier_spend
ORDER BY
    total_procurement_spend DESC;
	

-- Procurement Volume by Product
-- 4. Which products have the highest procurement volumes?

SELECT
    p.product_name,
    SUM(f.order_quantity) AS total_procurement_quantity
FROM fact_procurement AS f
JOIN dim_product AS p
    ON f.product_id = p.product_id
GROUP BY
    p.product_name
ORDER BY
    total_procurement_quantity DESC;


-- Procurement Cost by Product
-- 5. Which products have the highest average procurement costs?

SELECT
    p.product_name,
    ROUND(
        ( SUM(f.total_cost)::numeric
            / NULLIF(SUM(f.order_quantity), 0) ), 2 ) AS avg_procurement_cost
FROM fact_procurement AS f
JOIN dim_product AS p
    ON f.product_id = p.product_id
GROUP BY
    p.product_name
ORDER BY
    avg_procurement_cost DESC;



---------------  Inventory Analysis  ---------------
------------------------------------------------------

-- Reorder Risk
-- 1. Which product-facility combinations are currently at or below their reorder points?

SELECT
    p.product_name,
    i.facility_id,
    i.stock_level,
    i.reorder_point
FROM fact_inventory AS i
JOIN dim_product AS p
    ON i.product_id = p.product_id
WHERE i.stock_level <= i.reorder_point
ORDER BY i.stock_level;


-- Inventory Shortfall
-- 2. Which product-facility combinations have the largest inventory shortfalls against their reorder points?

SELECT
    p.product_name,
    i.facility_id,
    i.stock_level,
    i.reorder_point,
    i.reorder_point - i.stock_level AS shortfall
FROM fact_inventory AS i
JOIN dim_product AS p
    ON i.product_id = p.product_id
WHERE i.stock_level < i.reorder_point
ORDER BY shortfall DESC;


-- Current Inventory Level
-- 3. Which products currently have the highest inventory levels?

SELECT
    p.product_name,
    SUM(i.stock_level) AS total_stock
FROM fact_inventory AS i
JOIN dim_product AS p
    ON i.product_id = p.product_id
WHERE i.date_key = (
    SELECT MAX(date_key)
    FROM fact_inventory
)
GROUP BY
    p.product_name
ORDER BY
    total_stock DESC;


-- Facility Inventory Risk
-- 4. Which facilities have the highest proportion of inventory records at risk?

SELECT
    d.facility_name,
    i.facility_id,
    COUNT(*) AS risk_records,
    ROUND(
        COUNT(*)::numeric / 16 * 100,
        2
    ) AS risk_rate
FROM fact_inventory AS i
JOIN dim_facility AS d
    ON i.facility_id = d.facility_id
WHERE i.date_key = (
    SELECT MAX(date_key)
    FROM fact_inventory
)
AND i.stock_level <= i.reorder_point
GROUP BY
    d.facility_name,
    i.facility_id
ORDER BY
    risk_rate DESC;


-- Estimated Inventory Value
-- 5. Which products have the highest estimated inventory value?

WITH procurement_cost AS (
    SELECT
        product_id,
        SUM(total_cost) / SUM(order_quantity) AS avg_unit_cost
    FROM fact_procurement
    GROUP BY product_id
)

SELECT
    p.product_name,
    SUM(i.stock_level) AS total_stock,
    ROUND(
        (SUM(i.stock_level) * pc.avg_unit_cost)::numeric,
        2
    ) AS estimated_inventory_value
FROM fact_inventory AS i
JOIN dim_product AS p
    ON i.product_id = p.product_id
JOIN procurement_cost AS pc
    ON i.product_id = pc.product_id
WHERE i.date_key = (
    SELECT MAX(date_key)
    FROM fact_inventory
)
GROUP BY
    p.product_name,
    pc.avg_unit_cost
ORDER BY
    estimated_inventory_value DESC;



---------------  Product Analysis  -------------------
------------------------------------------------------

-- Production Output
-- 1. Which facilities have the highest production output?

SELECT
    d.facility_name,
    f.facility_id,
    SUM(f.quantity_produced) AS total_production
FROM fact_production AS f
JOIN dim_facility AS d
    ON f.facility_id = d.facility_id
GROUP BY
    d.facility_name,
    f.facility_id
ORDER BY
    total_production DESC;


-- Production Quality
-- 2. Which facilities have the highest production defect rates?

SELECT
    d.facility_name,
    f.facility_id,
    SUM(f.quantity_produced) AS total_production,
    SUM(f.defective_units) AS total_defective_units,
    ROUND(
        SUM(f.defective_units)::numeric
        / NULLIF(SUM(f.quantity_produced), 0) * 100,
        3
    ) AS defect_rate
FROM fact_production AS f
JOIN dim_facility AS d
    ON f.facility_id = d.facility_id
GROUP BY
    d.facility_name,
    f.facility_id
ORDER BY
    defect_rate DESC;



-- Production Quality
-- 3. Which products have the highest number of defective units?
SELECT
    p.product_name,
    SUM(f.quantity_produced) AS total_production,
    SUM(f.defective_units) AS total_defective_units
FROM fact_production AS f
JOIN dim_product AS p
    ON f.product_id = p.product_id
GROUP BY
    p.product_name
ORDER BY
    total_defective_units DESC;




-- Revenue by Product
-- 1. Which products generate the highest total revenue?

SELECT
    p.product_name,
    SUM(f.net_revenue) AS total_revenue
FROM fact_sales AS f
JOIN dim_product AS p
    ON f.product_id = p.product_id
GROUP BY
    p.product_name
ORDER BY
    total_revenue DESC;


-- Sales Volume
-- 2. Which products have the highest total sales volume?

SELECT
    p.product_name,
    SUM(f.quantity_sold) AS total_units_sold
FROM fact_sales AS f
JOIN dim_product AS p
    ON f.product_id = p.product_id
GROUP BY
    p.product_name
ORDER BY
    total_units_sold DESC;


-- Profitability
-- 3. Which products generate the highest total profit?

SELECT
    p.product_name,
    Round( SUM(f.profit)::numeric, 2) AS total_profit
FROM fact_sales AS f
JOIN dim_product AS p
    ON f.product_id = p.product_id
GROUP BY
    p.product_name
ORDER BY
    total_profit DESC;



-- Profit Margin
-- 4. Which products have the highest profit margins?

SELECT
    p.product_name,
    Round(SUM(f.net_revenue)::numeric, 2) AS total_revenue,
    Round( SUM(f.profit)::numeric, 2) AS total_profit,
    ROUND(
        SUM(f.profit)::numeric
        / SUM(f.net_revenue)::numeric * 100,
        2
    ) AS profit_margin
FROM fact_sales AS f
JOIN dim_product AS p
    ON f.product_id = p.product_id
GROUP BY
    p.product_name
ORDER BY
    profit_margin DESC;


-- Customer Revenue
-- 5. Which customers generate the highest total revenue?

SELECT
    c.customer_name,
    SUM(f.net_revenue) AS total_revenue
FROM fact_sales AS f
JOIN dim_customer AS c
    ON f.customer_id = c.customer_id
GROUP BY
    c.customer_name
ORDER BY
    total_revenue DESC;


-- Sales by Customer Volume
-- 6. Which customers purchase the highest number of units?

SELECT
    c.customer_name,
    SUM(f.quantity_sold) AS total_units_sold
FROM fact_sales AS f
JOIN dim_customer AS c
    ON f.customer_id = c.customer_id
GROUP BY
    c.customer_name
ORDER BY
    total_units_sold DESC;


-- Sales Trend
-- 7. How does sales revenue change over time?

SELECT
    d.year,
    d.month,
    d.month_name,
    Round(SUM(f.net_revenue)::numeric,2) AS total_revenue
FROM fact_sales AS f
JOIN dim_date AS d
    ON f.date_key = d.date_key
GROUP BY
    d.year,
    d.month,
    d.month_name
ORDER BY
    d.year,
    d.month;
	






















































