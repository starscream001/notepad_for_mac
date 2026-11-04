-- SQL: строки, параметры, числа, функции и комментарии
SELECT
    customer_id,
    COUNT(*) AS order_count,
    SUM(amount) AS total_amount
FROM orders
WHERE status = 'paid'
  AND amount >= :minimum_amount
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY total_amount DESC
LIMIT 100;
