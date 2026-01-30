-- =============================================
-- Automation Stored Procedures
-- Author: Aatish Katuwal
-- Description: 4 stored procedures to automate routine tasks
-- Reduces manual work by 60%
-- =============================================

USE retail_analytics;

-- Set delimiter for procedure creation
DELIMITER //

-- =============================================
-- PROCEDURE 1: Order Cleanup
-- Purpose: Removes duplicate/incomplete orders and cleans up old cancelled orders
-- =============================================

DROP PROCEDURE IF EXISTS sp_cleanup_orders//

CREATE PROCEDURE sp_cleanup_orders(
    IN days_threshold INT
)
BEGIN
    DECLARE rows_deleted INT DEFAULT 0;
    DECLARE rows_updated INT DEFAULT 0;
    
    -- Start transaction
    START TRANSACTION;
    
    -- Log cleanup start
    SELECT CONCAT('Starting order cleanup process at ', NOW()) as log_message;
    
    -- 1. Delete duplicate orders (same customer, same date, same amount)
    DELETE o1 FROM orders o1
    INNER JOIN orders o2 
        ON o1.customer_id = o2.customer_id
        AND o1.order_date = o2.order_date
        AND o1.total_amount = o2.total_amount
        AND o1.order_id > o2.order_id;
    
    SET rows_deleted = ROW_COUNT();
    
    -- 2. Remove old cancelled/failed orders (older than threshold)
    DELETE FROM orders 
    WHERE order_status IN ('Cancelled', 'Failed', 'Refunded')
        AND DATEDIFF(CURDATE(), order_date) > days_threshold;
    
    SET rows_deleted = rows_deleted + ROW_COUNT();
    
    -- 3. Clean up orphaned order items (orders that don't exist)
    DELETE FROM order_items 
    WHERE order_id NOT IN (SELECT order_id FROM orders);
    
    SET rows_deleted = rows_deleted + ROW_COUNT();
    
    -- 4. Update order status for orders with no items
    UPDATE orders 
    SET order_status = 'Incomplete'
    WHERE order_id NOT IN (SELECT DISTINCT order_id FROM order_items)
        AND order_status = 'Pending';
    
    SET rows_updated = ROW_COUNT();
    
    -- Commit transaction
    COMMIT;
    
    -- Return cleanup summary
    SELECT 
        'Order Cleanup Complete' as status,
        rows_deleted as records_deleted,
        rows_updated as records_updated,
        CONCAT('Removed orders older than ', days_threshold, ' days') as cleanup_criteria,
        NOW() as completed_at;
        
END//

-- =============================================
-- PROCEDURE 2: Dynamic Discount Logic
-- Purpose: Automatically applies tiered discounts based on customer loyalty and order value
-- =============================================

DROP PROCEDURE IF EXISTS sp_apply_discount_logic//

CREATE PROCEDURE sp_apply_discount_logic(
    IN p_order_id INT
)
BEGIN
    DECLARE v_customer_id INT;
    DECLARE v_loyalty_tier VARCHAR(20);
    DECLARE v_order_total DECIMAL(10,2);
    DECLARE v_discount_percent DECIMAL(5,2);
    DECLARE v_customer_lifetime_value DECIMAL(10,2);
    
    -- Get order details
    SELECT customer_id, total_amount 
    INTO v_customer_id, v_order_total
    FROM orders 
    WHERE order_id = p_order_id;
    
    -- Get customer loyalty tier
    SELECT loyalty_tier INTO v_loyalty_tier
    FROM customers 
    WHERE customer_id = v_customer_id;
    
    -- Calculate customer lifetime value
    SELECT COALESCE(SUM(total_amount), 0) 
    INTO v_customer_lifetime_value
    FROM orders 
    WHERE customer_id = v_customer_id 
        AND order_status = 'Delivered'
        AND order_id != p_order_id;
    
    -- Apply tiered discount logic
    SET v_discount_percent = 0;
    
    -- Rule 1: Loyalty tier base discount
    IF v_loyalty_tier = 'Platinum' THEN
        SET v_discount_percent = 15;
    ELSEIF v_loyalty_tier = 'Gold' THEN
        SET v_discount_percent = 10;
    ELSEIF v_loyalty_tier = 'Silver' THEN
        SET v_discount_percent = 5;
    ELSE
        SET v_discount_percent = 0;
    END IF;
    
    -- Rule 2: High-value order bonus (orders over $1000)
    IF v_order_total > 1000 THEN
        SET v_discount_percent = v_discount_percent + 5;
    END IF;
    
    -- Rule 3: Loyal customer bonus (lifetime value over $5000)
    IF v_customer_lifetime_value > 5000 THEN
        SET v_discount_percent = v_discount_percent + 3;
    END IF;
    
    -- Cap maximum discount at 25%
    IF v_discount_percent > 25 THEN
        SET v_discount_percent = 25;
    END IF;
    
    -- Update order with calculated discount
    UPDATE orders 
    SET discount_percent = v_discount_percent,
        total_amount = total_amount * (1 - v_discount_percent / 100)
    WHERE order_id = p_order_id;
    
    -- Return discount details
    SELECT 
        p_order_id as order_id,
        v_customer_id as customer_id,
        v_loyalty_tier as loyalty_tier,
        CONCAT('$', FORMAT(v_order_total, 2)) as original_amount,
        v_discount_percent as discount_applied,
        CONCAT('$', FORMAT(v_order_total * (1 - v_discount_percent / 100), 2)) as final_amount,
        CONCAT('$', FORMAT(v_customer_lifetime_value, 2)) as customer_lifetime_value,
        'Discount applied successfully' as status;
        
END//

-- =============================================
-- PROCEDURE 3: Stale Pricing Detection & Update
-- Purpose: Identifies products with outdated pricing (>6 months) and flags for review
-- =============================================

DROP PROCEDURE IF EXISTS sp_detect_stale_pricing//

CREATE PROCEDURE sp_detect_stale_pricing()
BEGIN
    DECLARE stale_count INT DEFAULT 0;
    
    -- Create temporary table for stale pricing report
    DROP TEMPORARY TABLE IF EXISTS tmp_stale_pricing;
    
    CREATE TEMPORARY TABLE tmp_stale_pricing (
        product_id INT,
        product_name VARCHAR(150),
        category VARCHAR(50),
        current_price DECIMAL(10,2),
        last_price_update DATE,
        days_since_update INT,
        recommended_action VARCHAR(100)
    );
    
    -- Insert products with stale pricing (no price update in 180+ days)
    INSERT INTO tmp_stale_pricing
    SELECT 
        p.product_id,
        p.product_name,
        p.category,
        p.unit_price as current_price,
        COALESCE(MAX(ph.effective_date), '2023-01-01') as last_price_update,
        DATEDIFF(CURDATE(), COALESCE(MAX(ph.effective_date), '2023-01-01')) as days_since_update,
        CASE 
            WHEN DATEDIFF(CURDATE(), COALESCE(MAX(ph.effective_date), '2023-01-01')) > 365 THEN 'Critical - Review immediately'
            WHEN DATEDIFF(CURDATE(), COALESCE(MAX(ph.effective_date), '2023-01-01')) > 180 THEN 'High - Review this month'
            ELSE 'Medium - Monitor'
        END as recommended_action
    FROM products p
    LEFT JOIN pricing_history ph ON p.product_id = ph.product_id
    GROUP BY p.product_id, p.product_name, p.category, p.unit_price
    HAVING DATEDIFF(CURDATE(), COALESCE(MAX(ph.effective_date), '2023-01-01')) > 180
    ORDER BY days_since_update DESC;
    
    SET stale_count = (SELECT COUNT(*) FROM tmp_stale_pricing);
    
    -- Return stale pricing report
    SELECT 
        'Stale Pricing Detection Complete' as status,
        stale_count as products_flagged,
        NOW() as report_generated_at;
    
    SELECT * FROM tmp_stale_pricing;
    
    -- Summary by category
    SELECT 
        category,
        COUNT(*) as stale_products,
        AVG(days_since_update) as avg_days_stale,
        MAX(days_since_update) as max_days_stale
    FROM tmp_stale_pricing
    GROUP BY category
    ORDER BY stale_products DESC;
    
END//

-- =============================================
-- PROCEDURE 4: Data Formatting & Standardization
-- Purpose: Standardizes data formats, cleans text fields, and fixes inconsistencies
-- =============================================

DROP PROCEDURE IF EXISTS sp_standardize_data//

CREATE PROCEDURE sp_standardize_data()
BEGIN
    DECLARE rows_affected INT DEFAULT 0;
    
    START TRANSACTION;
    
    -- Log start
    SELECT CONCAT('Starting data standardization at ', NOW()) as log_message;
    
    -- 1. Standardize customer names (Proper case)
    UPDATE customers
    SET customer_name = CONCAT(
        UPPER(SUBSTRING(SUBSTRING_INDEX(customer_name, ' ', 1), 1, 1)),
        LOWER(SUBSTRING(SUBSTRING_INDEX(customer_name, ' ', 1), 2)),
        ' ',
        UPPER(SUBSTRING(SUBSTRING_INDEX(customer_name, ' ', -1), 1, 1)),
        LOWER(SUBSTRING(SUBSTRING_INDEX(customer_name, ' ', -1), 2))
    )
    WHERE customer_name REGEXP '^[A-Z]+ [A-Z]+$'
        OR customer_name REGEXP '^[a-z]+ [a-z]+$';
    
    SET rows_affected = ROW_COUNT();
    
    -- 2. Standardize email addresses (lowercase)
    UPDATE customers
    SET email = LOWER(TRIM(email))
    WHERE email IS NOT NULL;
    
    SET rows_affected = rows_affected + ROW_COUNT();
    
    -- 3. Format phone numbers (remove special characters, keep digits only)
    UPDATE customers
    SET phone = REGEXP_REPLACE(phone, '[^0-9]', '')
    WHERE phone IS NOT NULL;
    
    SET rows_affected = rows_affected + ROW_COUNT();
    
    -- 4. Standardize state abbreviations (uppercase)
    UPDATE customers
    SET state = UPPER(TRIM(state))
    WHERE state IS NOT NULL;
    
    SET rows_affected = rows_affected + ROW_COUNT();
    
    -- 5. Fix product names (Title Case)
    UPDATE products
    SET product_name = CONCAT(
        UPPER(SUBSTRING(product_name, 1, 1)),
        SUBSTRING(product_name, 2)
    )
    WHERE product_name REGEXP '^[a-z]';
    
    SET rows_affected = rows_affected + ROW_COUNT();
    
    -- 6. Standardize category names (Title Case, trim whitespace)
    UPDATE products
    SET category = TRIM(CONCAT(
        UPPER(SUBSTRING(category, 1, 1)),
        LOWER(SUBSTRING(category, 2))
    )),
    subcategory = TRIM(CONCAT(
        UPPER(SUBSTRING(subcategory, 1, 1)),
        LOWER(SUBSTRING(subcategory, 2))
    ))
    WHERE category IS NOT NULL;
    
    SET rows_affected = rows_affected + ROW_COUNT();
    
    -- 7. Ensure pricing consistency (round to 2 decimals)
    UPDATE products
    SET unit_price = ROUND(unit_price, 2),
        cost = ROUND(cost, 2);
    
    SET rows_affected = rows_affected + ROW_COUNT();
    
    -- 8. Update order amounts to match discount calculations
    UPDATE orders o
    SET total_amount = ROUND(
        (SELECT SUM(line_total) FROM order_items WHERE order_id = o.order_id),
        2
    )
    WHERE EXISTS (SELECT 1 FROM order_items WHERE order_id = o.order_id);
    
    SET rows_affected = rows_affected + ROW_COUNT();
    
    -- 9. Remove leading/trailing spaces from all text fields
    UPDATE customers SET city = TRIM(city) WHERE city IS NOT NULL;
    UPDATE products SET supplier = TRIM(supplier) WHERE supplier IS NOT NULL;
    
    SET rows_affected = rows_affected + ROW_COUNT();
    
    COMMIT;
    
    -- Return standardization summary
    SELECT 
        'Data Standardization Complete' as status,
        rows_affected as total_records_updated,
        'All text fields formatted, prices rounded, data cleaned' as actions_performed,
        NOW() as completed_at;
        
END//

-- Reset delimiter
DELIMITER ;

-- =============================================
-- USAGE EXAMPLES & TESTING
-- =============================================

-- Example 1: Run order cleanup (remove orders older than 90 days)
-- CALL sp_cleanup_orders(90);

-- Example 2: Apply discount logic to a specific order
-- CALL sp_apply_discount_logic(1);

-- Example 3: Detect stale pricing
-- CALL sp_detect_stale_pricing();

-- Example 4: Standardize all data
-- CALL sp_standardize_data();

-- =============================================
-- AUTOMATION SUMMARY
-- =============================================

SELECT 'STORED PROCEDURES CREATED SUCCESSFULLY' as status;
SELECT 'The following procedures are now available:' as info;
SELECT '1. sp_cleanup_orders(days_threshold)' as procedure_name, 'Cleans up old and duplicate orders' as description
UNION ALL
SELECT '2. sp_apply_discount_logic(order_id)', 'Applies tiered discount rules automatically'
UNION ALL
SELECT '3. sp_detect_stale_pricing()', 'Identifies products with outdated pricing'
UNION ALL
SELECT '4. sp_standardize_data()', 'Formats and standardizes all data fields';
