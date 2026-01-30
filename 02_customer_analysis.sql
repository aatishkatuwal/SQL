-- =============================================
-- Customer Behavior & Product Performance Analysis
-- Author: Aatish Katuwal
-- Description: Analyzes 6 months of ERP data to identify top customers and product trends
-- Key Finding: Top 15% of customers generate 40% of revenue
-- =============================================

USE retail_analytics;

-- =============================================
-- CUSTOMER REVENUE ANALYSIS
-- =============================================

-- 1. Calculate total revenue per customer
DROP VIEW IF EXISTS customer_revenue_summary;
CREATE VIEW customer_revenue_summary AS
SELECT 
    c.customer_id,
    c.customer_name,
    c.customer_segment,
    c.loyalty_tier,
    c.city,
    c.state,
    COUNT(DISTINCT o.order_id) as total_orders,
    SUM(o.total_amount) as total_revenue,
    AVG(o.total_amount) as avg_order_value,
    MAX(o.order_date) as last_order_date,
    DATEDIFF(CURDATE(), MAX(o.order_date)) as days_since_last_order
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.customer_name, c.customer_segment, c.loyalty_tier, c.city, c.state;

-- View the summary
SELECT * FROM customer_revenue_summary
ORDER BY total_revenue DESC
LIMIT 20;

-- =============================================
-- TOP 15% CUSTOMERS ANALYSIS
-- =============================================

-- 2. Identify top 15% of customers (by revenue)
WITH ranked_customers AS (
    SELECT 
        customer_id,
        customer_name,
        customer_segment,
        total_revenue,
        SUM(total_revenue) OVER () as total_company_revenue,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) as revenue_rank,
        COUNT(*) OVER () as total_customers
    FROM customer_revenue_summary
    WHERE total_revenue > 0
),
top_15_percent AS (
    SELECT 
        *,
        ROUND((revenue_rank / total_customers) * 100, 2) as percentile
    FROM ranked_customers
    WHERE revenue_rank <= CEILING(total_customers * 0.15)
)
SELECT 
    COUNT(*) as top_customer_count,
    ROUND(SUM(total_revenue), 2) as top_customers_revenue,
    ROUND(AVG(total_company_revenue), 2) as total_company_revenue,
    ROUND((SUM(total_revenue) / AVG(total_company_revenue)) * 100, 2) as revenue_percentage,
    ROUND(AVG(total_revenue), 2) as avg_revenue_per_top_customer
FROM top_15_percent;

-- 3. Detailed view of top 15% customers
WITH ranked_customers AS (
    SELECT 
        customer_id,
        customer_name,
        customer_segment,
        loyalty_tier,
        total_revenue,
        total_orders,
        avg_order_value,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) as revenue_rank,
        COUNT(*) OVER () as total_customers
    FROM customer_revenue_summary
    WHERE total_revenue > 0
)
SELECT 
    revenue_rank,
    customer_name,
    customer_segment,
    loyalty_tier,
    total_orders,
    CONCAT('$', FORMAT(total_revenue, 2)) as total_revenue,
    CONCAT('$', FORMAT(avg_order_value, 2)) as avg_order_value,
    ROUND((revenue_rank / total_customers) * 100, 2) as percentile
FROM ranked_customers
WHERE revenue_rank <= CEILING(total_customers * 0.15)
ORDER BY revenue_rank;

-- =============================================
-- CUSTOMER SEGMENTATION ANALYSIS
-- =============================================

-- 4. Revenue by customer segment
SELECT 
    customer_segment,
    COUNT(DISTINCT customer_id) as customer_count,
    CONCAT('$', FORMAT(SUM(total_revenue), 2)) as total_revenue,
    CONCAT('$', FORMAT(AVG(total_revenue), 2)) as avg_revenue_per_customer,
    ROUND((SUM(total_revenue) / (SELECT SUM(total_revenue) FROM customer_revenue_summary)) * 100, 2) as pct_of_total_revenue
FROM customer_revenue_summary
GROUP BY customer_segment
ORDER BY SUM(total_revenue) DESC;

-- 5. Revenue by loyalty tier
SELECT 
    loyalty_tier,
    COUNT(DISTINCT customer_id) as customer_count,
    CONCAT('$', FORMAT(SUM(total_revenue), 2)) as total_revenue,
    CONCAT('$', FORMAT(AVG(total_revenue), 2)) as avg_revenue_per_customer,
    ROUND((SUM(total_revenue) / (SELECT SUM(total_revenue) FROM customer_revenue_summary)) * 100, 2) as pct_of_total_revenue
FROM customer_revenue_summary
GROUP BY loyalty_tier
ORDER BY 
    CASE loyalty_tier
        WHEN 'Platinum' THEN 1
        WHEN 'Gold' THEN 2
        WHEN 'Silver' THEN 3
        WHEN 'Bronze' THEN 4
    END;

-- =============================================
-- PRODUCT PERFORMANCE ANALYSIS
-- =============================================

-- 6. Top performing products by revenue
SELECT 
    p.product_id,
    p.product_name,
    p.category,
    p.subcategory,
    COUNT(DISTINCT oi.order_id) as times_ordered,
    SUM(oi.quantity) as units_sold,
    CONCAT('$', FORMAT(SUM(oi.line_total), 2)) as total_revenue,
    CONCAT('$', FORMAT(AVG(oi.line_total), 2)) as avg_revenue_per_order,
    ROUND((SUM(oi.line_total) - (SUM(oi.quantity) * p.cost)) / SUM(oi.line_total) * 100, 2) as profit_margin_pct
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.product_id, p.product_name, p.category, p.subcategory, p.cost
ORDER BY SUM(oi.line_total) DESC
LIMIT 15;

-- 7. Product performance by category
SELECT 
    p.category,
    COUNT(DISTINCT p.product_id) as product_count,
    COUNT(DISTINCT oi.order_id) as total_orders,
    SUM(oi.quantity) as units_sold,
    CONCAT('$', FORMAT(SUM(oi.line_total), 2)) as total_revenue,
    CONCAT('$', FORMAT(AVG(oi.line_total), 2)) as avg_revenue_per_order
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY SUM(oi.line_total) DESC;

-- 8. Slow-moving products (potential clearance candidates)
SELECT 
    p.product_id,
    p.product_name,
    p.category,
    p.stock_quantity,
    COALESCE(COUNT(DISTINCT oi.order_id), 0) as times_ordered,
    COALESCE(SUM(oi.quantity), 0) as units_sold,
    CONCAT('$', FORMAT(COALESCE(SUM(oi.line_total), 0), 2)) as total_revenue,
    CASE 
        WHEN COALESCE(COUNT(DISTINCT oi.order_id), 0) = 0 THEN 'No Sales'
        WHEN COALESCE(COUNT(DISTINCT oi.order_id), 0) <= 3 THEN 'Very Slow'
        WHEN COALESCE(COUNT(DISTINCT oi.order_id), 0) <= 7 THEN 'Slow'
        ELSE 'Normal'
    END as movement_status
FROM products p
LEFT JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.product_id, p.product_name, p.category, p.stock_quantity
HAVING COALESCE(COUNT(DISTINCT oi.order_id), 0) <= 7
ORDER BY times_ordered ASC, p.stock_quantity DESC;

-- =============================================
-- CUSTOMER PURCHASING BEHAVIOR
-- =============================================

-- 9. Customer purchase frequency analysis
SELECT 
    CASE 
        WHEN total_orders >= 5 THEN 'High Frequency (5+)'
        WHEN total_orders >= 3 THEN 'Medium Frequency (3-4)'
        WHEN total_orders >= 1 THEN 'Low Frequency (1-2)'
        ELSE 'No Orders'
    END as frequency_bucket,
    COUNT(*) as customer_count,
    ROUND(AVG(total_revenue), 2) as avg_revenue,
    SUM(total_revenue) as bucket_total_revenue
FROM customer_revenue_summary
GROUP BY 
    CASE 
        WHEN total_orders >= 5 THEN 'High Frequency (5+)'
        WHEN total_orders >= 3 THEN 'Medium Frequency (3-4)'
        WHEN total_orders >= 1 THEN 'Low Frequency (1-2)'
        ELSE 'No Orders'
    END
ORDER BY bucket_total_revenue DESC;

-- 10. Customer retention analysis (customers at risk of churning)
SELECT 
    customer_name,
    customer_segment,
    loyalty_tier,
    total_orders,
    CONCAT('$', FORMAT(total_revenue, 2)) as total_revenue,
    last_order_date,
    days_since_last_order,
    CASE 
        WHEN days_since_last_order > 90 THEN 'High Risk'
        WHEN days_since_last_order > 60 THEN 'Medium Risk'
        WHEN days_since_last_order > 30 THEN 'Low Risk'
        ELSE 'Active'
    END as churn_risk
FROM customer_revenue_summary
WHERE total_revenue > 0
    AND days_since_last_order > 30
ORDER BY days_since_last_order DESC, total_revenue DESC
LIMIT 20;

-- =============================================
-- MONTHLY REVENUE TRENDS
-- =============================================

-- 11. Monthly revenue and order trends
SELECT 
    DATE_FORMAT(order_date, '%Y-%m') as month,
    COUNT(DISTINCT order_id) as total_orders,
    COUNT(DISTINCT customer_id) as unique_customers,
    CONCAT('$', FORMAT(SUM(total_amount), 2)) as total_revenue,
    CONCAT('$', FORMAT(AVG(total_amount), 2)) as avg_order_value
FROM orders
WHERE order_status = 'Delivered'
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY month;

-- =============================================
-- DISCOUNT IMPACT ANALYSIS
-- =============================================

-- 12. Discount effectiveness analysis
SELECT 
    CASE 
        WHEN discount_percent = 0 THEN 'No Discount'
        WHEN discount_percent <= 5 THEN '1-5%'
        WHEN discount_percent <= 10 THEN '6-10%'
        WHEN discount_percent <= 15 THEN '11-15%'
        ELSE '16%+'
    END as discount_range,
    COUNT(*) as order_count,
    CONCAT('$', FORMAT(AVG(total_amount), 2)) as avg_order_value,
    CONCAT('$', FORMAT(SUM(total_amount), 2)) as total_revenue
FROM orders
WHERE order_status = 'Delivered'
GROUP BY 
    CASE 
        WHEN discount_percent = 0 THEN 'No Discount'
        WHEN discount_percent <= 5 THEN '1-5%'
        WHEN discount_percent <= 10 THEN '6-10%'
        WHEN discount_percent <= 15 THEN '11-15%'
        ELSE '16%+'
    END
ORDER BY avg_order_value DESC;

-- =============================================
-- KEY INSIGHTS SUMMARY
-- =============================================

-- Generate executive summary
SELECT 'EXECUTIVE SUMMARY' as report_section, '' as metric, '' as value
UNION ALL
SELECT '==================' as report_section, '' as metric, '' as value
UNION ALL
SELECT 'Total Customers', '', CAST(COUNT(DISTINCT customer_id) as CHAR) FROM customers
UNION ALL
SELECT 'Total Orders', '', CAST(COUNT(*) as CHAR) FROM orders WHERE order_status = 'Delivered'
UNION ALL
SELECT 'Total Revenue', '', CONCAT('$', FORMAT(SUM(total_amount), 2)) FROM orders WHERE order_status = 'Delivered'
UNION ALL
SELECT 'Average Order Value', '', CONCAT('$', FORMAT(AVG(total_amount), 2)) FROM orders WHERE order_status = 'Delivered'
UNION ALL
SELECT 'Top 15% Customers', 'Count', CAST(CEILING((SELECT COUNT(*) FROM customer_revenue_summary WHERE total_revenue > 0) * 0.15) as CHAR)
UNION ALL
SELECT '', '% of Revenue', CONCAT(
    ROUND(
        (SELECT SUM(total_revenue) FROM (
            SELECT total_revenue, ROW_NUMBER() OVER (ORDER BY total_revenue DESC) as rn,
                   COUNT(*) OVER () as total_count
            FROM customer_revenue_summary WHERE total_revenue > 0
        ) t WHERE rn <= CEILING(total_count * 0.15)) 
        / 
        (SELECT SUM(total_revenue) FROM customer_revenue_summary) * 100
    , 2), '%');
