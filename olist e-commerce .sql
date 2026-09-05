USE OlistDB;
GO

CREATE OR ALTER VIEW dbo.vw_Olist_BI_Master AS
WITH PaymentAggregated AS (
    SELECT 
        order_id,
        STRING_AGG(payment_type, ', ') AS payment_methods,
        MAX(payment_installments) AS max_installments,
        SUM(TRY_CAST(payment_value AS DECIMAL(10, 2))) AS total_payment_value
    FROM dbo.olist_order_payments_dataset
    GROUP BY order_id
),
ItemsAggregated AS (
    SELECT 
        order_id,
        COUNT(order_item_id) AS total_items,
        SUM(TRY_CAST(price AS DECIMAL(10, 2))) AS total_order_price,
        SUM(TRY_CAST(freight_value AS DECIMAL(10, 2))) AS total_freight_value,
        MIN(seller_id) AS primary_seller_id
    FROM dbo.olist_order_items_dataset
    GROUP BY order_id
),
ReviewsAggregated AS (
    SELECT 
        order_id,
        AVG(TRY_CAST(review_score AS FLOAT)) AS avg_review_score
    FROM dbo.olist_order_reviews_dataset
    GROUP BY order_id
)
SELECT 
    o.order_id,
    c.customer_id,
    c.customer_unique_id,
    i.primary_seller_id,
    c.customer_city,
    c.customer_state,
    c.customer_zip_code_prefix,
    o.order_status,
    TRY_CAST(o.order_purchase_timestamp AS DATETIME) AS order_purchase_timestamp,
    TRY_CAST(o.order_approved_at AS DATETIME) AS order_approved_at,
    TRY_CAST(o.order_delivered_carrier_date AS DATETIME) AS shipping_carrier_date,
    TRY_CAST(o.order_delivered_customer_date AS DATETIME) AS delivery_customer_date,
    TRY_CAST(o.order_estimated_delivery_date AS DATETIME) AS estimated_delivery_date,
    DATEDIFF(
        DAY, 
        TRY_CAST(o.order_purchase_timestamp AS DATETIME), 
        TRY_CAST(o.order_delivered_customer_date AS DATETIME)
    ) AS total_delivery_lag_days,
    DATEDIFF(
        DAY, 
        TRY_CAST(o.order_delivered_carrier_date AS DATETIME), 
        TRY_CAST(o.order_delivered_customer_date AS DATETIME)
    ) AS carrier_transit_lag_days,
    DATEDIFF(
        DAY, 
        TRY_CAST(o.order_purchase_timestamp AS DATETIME), 
        TRY_CAST(o.order_estimated_delivery_date AS DATETIME)
    ) AS estimated_delivery_days,
    CASE 
        WHEN TRY_CAST(o.order_delivered_customer_date AS DATETIME) > TRY_CAST(o.order_estimated_delivery_date AS DATETIME) THEN 1 
        ELSE 0 
    END AS is_late_delivery,
    COALESCE(i.total_items, 0) AS total_items,
    COALESCE(i.total_order_price, 0.00) AS total_order_price,
    COALESCE(i.total_freight_value, 0.00) AS total_freight_value,
    COALESCE(p.payment_methods, 'Not Recorded') AS payment_methods,
    COALESCE(p.max_installments, 1) AS max_installments,
    COALESCE(p.total_payment_value, 0.00) AS total_payment_value,
    COALESCE(r.avg_review_score, NULL) AS avg_review_score
FROM dbo.olist_orders_dataset o
INNER JOIN dbo.olist_customers_dataset c 
    ON o.customer_id = c.customer_id
LEFT JOIN ItemsAggregated i 
    ON o.order_id = i.order_id
LEFT JOIN PaymentAggregated p 
    ON o.order_id = p.order_id
LEFT JOIN ReviewsAggregated r 
    ON o.order_id = r.order_id;
GO

SELECT 
    order_id,
    customer_id,
    customer_unique_id,
    customer_city,
    customer_state,
    order_status,
    order_purchase_timestamp,
    delivery_customer_date,
    estimated_delivery_date,
    total_delivery_lag_days,
    is_late_delivery,
    total_items,
    total_order_price,
    total_freight_value,
    payment_methods,
    total_payment_value,
    avg_review_score
FROM dbo.vw_Olist_BI_Master
ORDER BY order_purchase_timestamp DESC;
GO