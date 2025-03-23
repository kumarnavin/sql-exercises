/* 
Compute daily active users (DAU) for the past week.
Uses COUNT(DISTINCT user_id) to count unique users per day.
Partitioning the table by event_date improves query performance in Hive/Presto.
*/

SELECT event_date, COUNT(DISTINCT user_id) AS daily_active_users
FROM user_activity
WHERE event_date >= DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY)
GROUP BY event_date
ORDER BY event_date DESC;

/*
Optimization (Presto Performance Tip)
Use HyperLogLog (HLL) Approximation to optimize distinct counts:
approx_distinct(user_id) reduces query execution time significantly with minimal accuracy loss. Consider where error date of 0-5% is acceptable.
*/

SELECT event_date, approx_distinct(user_id) AS approx_dau
FROM user_activity
WHERE event_date >= DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY)
GROUP BY event_date
ORDER BY event_date DESC;

