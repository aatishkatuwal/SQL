-- =============================================
-- Retail Analytics Database Setup
-- Author: Aatish Katuwal
-- Description: Creates retail ERP database schema and populates with 6 months of sample data
-- =============================================

-- Create database
DROP DATABASE IF EXISTS retail_analytics;
CREATE DATABASE retail_analytics;
USE retail_analytics;

-- =============================================
-- TABLE DEFINITIONS
-- =============================================

-- Customers table
CREATE TABLE customers (
    customer_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20),
    customer_segment VARCHAR(50),
    registration_date DATE,
    city VARCHAR(50),
    state VARCHAR(50),
    loyalty_tier VARCHAR(20) DEFAULT 'Bronze'
);

-- Products table
CREATE TABLE products (
    product_id INT PRIMARY KEY AUTO_INCREMENT,
    product_name VARCHAR(150) NOT NULL,
    category VARCHAR(50),
    subcategory VARCHAR(50),
    unit_price DECIMAL(10, 2),
    cost DECIMAL(10, 2),
    supplier VARCHAR(100),
    stock_quantity INT DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Orders table
CREATE TABLE orders (
    order_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT,
    order_date DATE,
    ship_date DATE,
    ship_mode VARCHAR(50),
    order_status VARCHAR(50) DEFAULT 'Pending',
    total_amount DECIMAL(10, 2),
    discount_percent DECIMAL(5, 2) DEFAULT 0,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- Order items table
CREATE TABLE order_items (
    order_item_id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT,
    product_id INT,
    quantity INT,
    unit_price DECIMAL(10, 2),
    discount_amount DECIMAL(10, 2) DEFAULT 0,
    line_total DECIMAL(10, 2),
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- Pricing history table (for stale pricing detection)
CREATE TABLE pricing_history (
    price_id INT PRIMARY KEY AUTO_INCREMENT,
    product_id INT,
    old_price DECIMAL(10, 2),
    new_price DECIMAL(10, 2),
    effective_date DATE,
    updated_by VARCHAR(50),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- =============================================
-- SAMPLE DATA INSERTION
-- =============================================

-- Insert Customers (100 customers)
INSERT INTO customers (customer_name, email, phone, customer_segment, registration_date, city, state, loyalty_tier) VALUES
('John Smith', 'john.smith@email.com', '555-0101', 'Retail', '2024-01-15', 'Houston', 'TX', 'Gold'),
('Sarah Johnson', 'sarah.j@email.com', '555-0102', 'Wholesale', '2024-01-20', 'Dallas', 'TX', 'Platinum'),
('Michael Brown', 'mbrown@email.com', '555-0103', 'Retail', '2024-02-01', 'Austin', 'TX', 'Silver'),
('Emily Davis', 'emily.d@email.com', '555-0104', 'Corporate', '2024-02-05', 'San Antonio', 'TX', 'Gold'),
('David Wilson', 'dwilson@email.com', '555-0105', 'Retail', '2024-02-10', 'Fort Worth', 'TX', 'Bronze'),
('Jennifer Martinez', 'jmartinez@email.com', '555-0106', 'Wholesale', '2024-02-15', 'El Paso', 'TX', 'Platinum'),
('Robert Taylor', 'rtaylor@email.com', '555-0107', 'Retail', '2024-02-20', 'Arlington', 'TX', 'Silver'),
('Lisa Anderson', 'landerson@email.com', '555-0108', 'Corporate', '2024-03-01', 'Plano', 'TX', 'Gold'),
('James Thomas', 'jthomas@email.com', '555-0109', 'Retail', '2024-03-05', 'Irving', 'TX', 'Bronze'),
('Mary Jackson', 'mjackson@email.com', '555-0110', 'Wholesale', '2024-03-10', 'Garland', 'TX', 'Platinum'),
('William White', 'wwhite@email.com', '555-0111', 'Retail', '2024-03-15', 'Frisco', 'TX', 'Silver'),
('Patricia Harris', 'pharris@email.com', '555-0112', 'Corporate', '2024-03-20', 'McKinney', 'TX', 'Gold'),
('Christopher Martin', 'cmartin@email.com', '555-0113', 'Retail', '2024-04-01', 'Denton', 'TX', 'Bronze'),
('Barbara Thompson', 'bthompson@email.com', '555-0114', 'Wholesale', '2024-04-05', 'Richardson', 'TX', 'Platinum'),
('Daniel Garcia', 'dgarcia@email.com', '555-0115', 'Retail', '2024-04-10', 'Lewisville', 'TX', 'Silver'),
('Susan Martinez', 'smartinez@email.com', '555-0116', 'Corporate', '2024-04-15', 'Allen', 'TX', 'Gold'),
('Matthew Robinson', 'mrobinson@email.com', '555-0117', 'Retail', '2024-04-20', 'Grand Prairie', 'TX', 'Bronze'),
('Jessica Clark', 'jclark@email.com', '555-0118', 'Wholesale', '2024-05-01', 'Mesquite', 'TX', 'Platinum'),
('Anthony Rodriguez', 'arodriguez@email.com', '555-0119', 'Retail', '2024-05-05', 'Carrollton', 'TX', 'Silver'),
('Karen Lewis', 'klewis@email.com', '555-0120', 'Corporate', '2024-05-10', 'Flower Mound', 'TX', 'Gold');

-- Generate more customers (simplified for brevity - in real implementation, add 80 more)
INSERT INTO customers (customer_name, email, customer_segment, registration_date, city, state, loyalty_tier)
SELECT 
    CONCAT('Customer_', n) as customer_name,
    CONCAT('customer', n, '@email.com') as email,
    CASE 
        WHEN n % 4 = 0 THEN 'Corporate'
        WHEN n % 4 = 1 THEN 'Wholesale'
        ELSE 'Retail'
    END as customer_segment,
    DATE_ADD('2024-01-01', INTERVAL n DAY) as registration_date,
    'Houston' as city,
    'TX' as state,
    CASE 
        WHEN n % 5 = 0 THEN 'Platinum'
        WHEN n % 5 = 1 THEN 'Gold'
        WHEN n % 5 = 2 THEN 'Silver'
        ELSE 'Bronze'
    END as loyalty_tier
FROM (
    SELECT (@row_number:=@row_number + 1) AS n
    FROM information_schema.tables t1, information_schema.tables t2, (SELECT @row_number:=20) AS init
    LIMIT 80
) AS numbers;

-- Insert Products (50 products across different categories)
INSERT INTO products (product_name, category, subcategory, unit_price, cost, supplier, stock_quantity) VALUES
('Wireless Mouse', 'Electronics', 'Accessories', 29.99, 15.00, 'TechSupply Co', 150),
('USB-C Cable', 'Electronics', 'Accessories', 12.99, 5.00, 'TechSupply Co', 300),
('Laptop Stand', 'Electronics', 'Accessories', 49.99, 25.00, 'OfficeMax Inc', 80),
('Mechanical Keyboard', 'Electronics', 'Peripherals', 89.99, 45.00, 'TechSupply Co', 60),
('27" Monitor', 'Electronics', 'Displays', 299.99, 180.00, 'Display Corp', 40),
('Office Chair', 'Furniture', 'Seating', 199.99, 120.00, 'FurnishPro', 25),
('Standing Desk', 'Furniture', 'Desks', 399.99, 250.00, 'FurnishPro', 15),
('Desk Lamp', 'Furniture', 'Lighting', 34.99, 18.00, 'LightWorks', 100),
('Notebook Pack', 'Office Supplies', 'Paper', 8.99, 3.50, 'PaperPlus', 500),
('Pen Set', 'Office Supplies', 'Writing', 15.99, 6.00, 'PaperPlus', 400),
('Stapler', 'Office Supplies', 'Tools', 12.99, 5.50, 'OfficeMax Inc', 200),
('File Folders', 'Office Supplies', 'Organization', 9.99, 4.00, 'PaperPlus', 350),
('Whiteboard', 'Office Supplies', 'Presentation', 79.99, 40.00, 'OfficeMax Inc', 45),
('Coffee Maker', 'Appliances', 'Kitchen', 89.99, 50.00, 'HomeGoods Ltd', 30),
('Water Filter', 'Appliances', 'Kitchen', 39.99, 20.00, 'HomeGoods Ltd', 60),
('Desk Calendar', 'Office Supplies', 'Organization', 14.99, 6.50, 'PaperPlus', 180),
('Surge Protector', 'Electronics', 'Accessories', 24.99, 12.00, 'TechSupply Co', 150),
('Webcam HD', 'Electronics', 'Peripherals', 69.99, 35.00, 'TechSupply Co', 50),
('Headset', 'Electronics', 'Audio', 59.99, 30.00, 'TechSupply Co', 70),
('Portable SSD 1TB', 'Electronics', 'Storage', 129.99, 75.00, 'TechSupply Co', 35);

-- Generate more products
INSERT INTO products (product_name, category, subcategory, unit_price, cost, supplier, stock_quantity)
SELECT 
    CONCAT('Product_', n) as product_name,
    CASE 
        WHEN n % 4 = 0 THEN 'Electronics'
        WHEN n % 4 = 1 THEN 'Furniture'
        WHEN n % 4 = 2 THEN 'Office Supplies'
        ELSE 'Appliances'
    END as category,
    'General' as subcategory,
    ROUND(20 + (RAND() * 200), 2) as unit_price,
    ROUND(10 + (RAND() * 100), 2) as cost,
    'Generic Supplier' as supplier,
    FLOOR(10 + (RAND() * 200)) as stock_quantity
FROM (
    SELECT (@row_num:=@row_num + 1) AS n
    FROM information_schema.tables t1, information_schema.tables t2, (SELECT @row_num:=20) AS init
    LIMIT 30
) AS numbers;

-- Insert Orders (6 months of data - Jan to June 2024)
-- High-value customers (top 15 customers generate 40% of revenue)
INSERT INTO orders (customer_id, order_date, ship_date, ship_mode, order_status, total_amount, discount_percent) VALUES
-- Customer 1 (High spender - Platinum tier)
(1, '2024-01-20', '2024-01-22', 'Express', 'Delivered', 1250.00, 5),
(1, '2024-02-15', '2024-02-17', 'Express', 'Delivered', 2100.00, 8),
(1, '2024-03-10', '2024-03-12', 'Standard', 'Delivered', 1800.00, 5),
(1, '2024-04-05', '2024-04-07', 'Express', 'Delivered', 2450.00, 10),
(1, '2024-05-12', '2024-05-14', 'Express', 'Delivered', 1950.00, 5),
(1, '2024-06-08', '2024-06-10', 'Standard', 'Delivered', 1600.00, 7),
-- Customer 2 (High spender - Platinum tier)
(2, '2024-01-25', '2024-01-27', 'Express', 'Delivered', 3200.00, 12),
(2, '2024-02-20', '2024-02-22', 'Express', 'Delivered', 2800.00, 10),
(2, '2024-03-18', '2024-03-20', 'Express', 'Delivered', 3500.00, 15),
(2, '2024-04-22', '2024-04-24', 'Express', 'Delivered', 2900.00, 10),
(2, '2024-05-28', '2024-05-30', 'Express', 'Delivered', 3100.00, 12),
(2, '2024-06-15', '2024-06-17', 'Express', 'Delivered', 2700.00, 10),
-- Customer 4 (High spender - Gold tier)
(4, '2024-02-10', '2024-02-12', 'Standard', 'Delivered', 1800.00, 8),
(4, '2024-03-15', '2024-03-17', 'Express', 'Delivered', 2200.00, 10),
(4, '2024-04-20', '2024-04-22', 'Standard', 'Delivered', 1950.00, 7),
(4, '2024-05-25', '2024-05-27', 'Express', 'Delivered', 2400.00, 10),
(4, '2024-06-18', '2024-06-20', 'Standard', 'Delivered', 1700.00, 5);

-- Medium spenders
INSERT INTO orders (customer_id, order_date, ship_date, ship_mode, order_status, total_amount, discount_percent)
SELECT 
    FLOOR(3 + (RAND() * 40)) as customer_id,
    DATE_ADD('2024-01-01', INTERVAL FLOOR(RAND() * 180) DAY) as order_date,
    DATE_ADD(DATE_ADD('2024-01-01', INTERVAL FLOOR(RAND() * 180) DAY), INTERVAL 2 DAY) as ship_date,
    CASE WHEN RAND() > 0.5 THEN 'Standard' ELSE 'Express' END as ship_mode,
    'Delivered' as order_status,
    ROUND(200 + (RAND() * 800), 2) as total_amount,
    FLOOR(RAND() * 15) as discount_percent
FROM (
    SELECT (@order_num:=@order_num + 1) AS n
    FROM information_schema.tables t1, information_schema.tables t2, (SELECT @order_num:=0) AS init
    LIMIT 150
) AS numbers;

-- Low spenders (bulk of customers)
INSERT INTO orders (customer_id, order_date, ship_date, ship_mode, order_status, total_amount, discount_percent)
SELECT 
    FLOOR(40 + (RAND() * 60)) as customer_id,
    DATE_ADD('2024-01-01', INTERVAL FLOOR(RAND() * 180) DAY) as order_date,
    DATE_ADD(DATE_ADD('2024-01-01', INTERVAL FLOOR(RAND() * 180) DAY), INTERVAL 3 DAY) as ship_date,
    'Standard' as ship_mode,
    'Delivered' as order_status,
    ROUND(50 + (RAND() * 300), 2) as total_amount,
    FLOOR(RAND() * 10) as discount_percent
FROM (
    SELECT (@low_order:=@low_order + 1) AS n
    FROM information_schema.tables t1, information_schema.tables t2, (SELECT @low_order:=0) AS init
    LIMIT 250
) AS numbers;

-- Insert Order Items (link orders to products)
INSERT INTO order_items (order_id, product_id, quantity, unit_price, discount_amount, line_total)
SELECT 
    o.order_id,
    FLOOR(1 + (RAND() * 50)) as product_id,
    FLOOR(1 + (RAND() * 5)) as quantity,
    p.unit_price,
    ROUND(p.unit_price * o.discount_percent / 100, 2) as discount_amount,
    ROUND(p.unit_price * FLOOR(1 + (RAND() * 5)) * (1 - o.discount_percent / 100), 2) as line_total
FROM orders o
JOIN products p ON p.product_id = FLOOR(1 + (RAND() * 50))
LIMIT 500;

-- Insert Pricing History (for stale pricing detection)
INSERT INTO pricing_history (product_id, old_price, new_price, effective_date, updated_by) VALUES
(1, 24.99, 29.99, '2024-01-01', 'admin'),
(2, 9.99, 12.99, '2024-02-01', 'admin'),
(5, 279.99, 299.99, '2024-03-01', 'admin'),
(10, 12.99, 15.99, '2023-12-01', 'admin'),  -- Stale pricing (not updated in 6+ months)
(15, 34.99, 39.99, '2023-11-15', 'admin'),  -- Stale pricing
(20, 119.99, 129.99, '2024-04-01', 'admin');

-- =============================================
-- CREATE INDEXES FOR PERFORMANCE
-- =============================================
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_date ON orders(order_date);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);
CREATE INDEX idx_pricing_product ON pricing_history(product_id);
CREATE INDEX idx_pricing_date ON pricing_history(effective_date);

-- =============================================
-- VERIFICATION QUERIES
-- =============================================
SELECT 'Database Setup Complete!' as Status;
SELECT COUNT(*) as Total_Customers FROM customers;
SELECT COUNT(*) as Total_Products FROM products;
SELECT COUNT(*) as Total_Orders FROM orders;
SELECT COUNT(*) as Total_Order_Items FROM order_items;
SELECT CONCAT('$', FORMAT(SUM(total_amount), 2)) as Total_Revenue FROM orders;
