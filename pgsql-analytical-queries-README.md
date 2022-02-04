# SQL Analytics in PostgreSQL
Here are some PostgreSQL SQL examples for data analytics.


Let's say you have gathered the data pipeline performance data as follows.

### Table name: build_statistics
| correlation_id | client_id | environment | app_version | is_monthly | status    | etl_start_dtm     | etl_end_dtm | build_size_gb | db_schema |
| -------------- | -------- | ------------- | ---------- | ---------- | ------- | -------------------- | ---------------- | ----- | ----------- |
| df8bbe0ac4d1   | amazon123   | prod       | 3.1         | 1          | SUCCEEDED | 2016-06-22 19:10:25-07 | 2016-06-22 20:10:25-07 | 50 | schema_123 |
| fcbafa88c9f3   | amazon123   | prod       | 3.1         | 0          | FAILED | 2016-07-05 08:00:00-05 | 2016-07-05 11:30:15-01 | 200 | schema_456 |
| 41002ad80036   | amazon123   | stage      | 3.2         | 1          | RUNNING | 2016-08-10 12:15:10-03 | 2016-08-10 14:45:03-09 | 1500 | schema_789 |

Here, a process can run monthly or daily. is_monthly flag indicates it. Correlation ID is UUID for each unique run.


## Top Level Statistics (total runs per client)
This is a simple aggregation of metrics by client_id.
```sql
CREATE OR REPLACE VIEW top_level_stats_vw AS
(
   SELECT
       client_id,
       count(client_id) as total_count,
       count(case is_monthly when 1 then 1 else null end) as monthly_count,
       count(case is_monthly when 0 then 1 else null end) as daily_count,
       count(case status when 'SUCCEEDED' then 1 else null end) as succeeded_count,
       count(case status when 'FAILED' then 1 else null end) as failed_count,
       count(case status when 'ABORTED' then 1 else null end) as aborted_count,
       count(case status when 'RUNNING' then 1 else null end) as running_count
   FROM build_statistics
   GROUP BY client_id
);
```

## Add computed column for Build Time (minutes)
Note that you can find the age from two tiestamps (etl_exec_time_age) and then use this computed column to extract the number of days, hours, minutes and seconds, anc convert it into total build time in minutes.

```sql
CREATE OR REPLACE VIEW build_stats_exec_time_vw AS
SELECT
 correlation_id,
 client_id,
 environment,
 build_type,
 app_version,
 etl_start_dtm,
 etl_end_dtm,
 (24 * 60 * extract(day from etl_exec_time_age)
   + 60 * extract(hour from etl_exec_time_age)
   + extract(minute from etl_exec_time_age)
   + (1/60) * extract(second from etl_exec_time_age)
 ) as executiom_time_minutes
FROM (
 SELECT
   correlation_id,
   client_id,
   environment,
   (case is_monthly when 1 then 'monthly' else 'daily' end) as build_type,
   app_version,
   etl_start_dtm,
   etl_end_dtm,
   age(TO_TIMESTAMP(etl_end_dtm, 'YYYY-MM-DD HH24:MI:SS'), TO_TIMESTAMP(etl_start_dtm, 'YYYY-MM-DD HH24:MI:SS')) as etl_exec_time_age
 FROM build_statistics
 WHERE etl_start_dtm <> ''
 AND status = 'SUCCEEDED'
) tmp;
```

## Client data size analytics
This query categorizes the clients into small, medium and large clients based on total gigabytes of data per client.

```sql
CREATE OR REPLACE view client_build_size_stats_vw AS
WITH client_build_size_tmp AS  (
 SELECT
   correlation_id,
   client_id,
   environment,
   (CASE is_monthly WHEN 1 THEN 'monthly' else 'daily' END) AS build_type,
   app_version,
   CAST(build_size_gb AS double precision) AS build_size_gb
 FROM build_statistics
 WHERE status = 'SUCCEEDED'
 AND build_size_gb <> 'NULL'
 AND build_size_gb != '0'
),
size_stats_tmp AS (
 SELECT
   MIN(build_size_gb) AS min_size,
   MAX(build_size_gb) AS max_size,
   AVG(build_size_gb) AS avg_size
 FROM client_build_size_tmp
 )
SELECT
 a.*,
 (CASE
      WHEN a.build_size_gb = b.min_size THEN 'smallest client'
  WHEN (a.build_size_gb > b.min_size AND a.build_size_gb < 0.25 * (b.max_size - b.min_size)) THEN 'smaller client'
  WHEN (a.build_size_gb >= 0.25 * (b.max_size - b.min_size) AND a.build_size_gb < 0.75 * (b.max_size - b.min_size)) THEN 'average client'
  WHEN (a.build_size_gb >= 0.75 * (b.max_size - b.min_size) AND a.build_size_gb < b.max_size) THEN 'larger client'
   WHEN a.build_size_gb = b.max_size THEN 'largest client'
 END) AS client_type,
 b.min_size AS overall_min_build_size,
 b.max_size AS overall_max_build_size,
 b.avg_size AS overall_avg_build_size
FROM client_build_size_tmp a
 CROSS JOIN size_stats_tmp b
ORDER BY a.build_size_gb
;
```

## Computing execution time per ETL
If the pipeline data load process runs for total 2 hours and runs 50 individual ETLs, then it is useful to compute the MAX, MIN, and AVG execution time per ETL. This can help in trending and plotting the bottleneck ETLs.

### Table name: etl_statistics
| correlation_id | client_id | etl_name         | etl_start_dtm          | etl_end_dtm            |
| -------------- | --------  | ---------------- | ---------------------- | ---------------------- |
| df8bbe0ac4d1   | amazon123 | order_summary    | 2020-06-22 19:10:25-07 | 2020-06-22 20:10:25-07 | 
| fcbafa88c9f3   | amazon123 | payment_summary  | 2020-07-05 20:00:00-05 | 2020-07-05 22:30:15-01 | 
| 41002ad80036   | amazon123 | shipment_summary | 2020-08-10 03:15:10-03 | 2020-08-10 04:45:03-09 | 

Here, data pipeline processing is running three ETLs for summarizing orders, payments and shipment details.

## Computing performance metrics per ETL
```sql
CREATE OR REPLACE VIEW etl_statistics_vw AS
SELECT
  ps.client_id,
  bs.app_version,
  ps.etl_name,
  ROUND(MAX(ps.etl_executiom_time_minutes), 2) AS max_execution_time_minutes,
  ROUND(AVG(ps.etl_executiom_time_minutes), 2) AS avg_execution_time_minutes,
  COUNT(ps.correlation_id) AS total_etl_count,
  ROUND(SUM(ps.etl_executiom_time_minutes), 2) AS total_execution_time_minutes
FROM (
   SELECT
       correlation_id,
       client_id,
       etl_name,
       CAST((24 * 60 * EXTRACT(day FROM AGE(etl_end_dtm, etl_start_dtm))
                + 60 * EXTRACT(hour FROM AGE(etl_end_dtm, etl_start_dtm))
                     + EXTRACT(minute FROM AGE(etl_end_dtm, etl_start_dtm))
          + (1.0/60) * EXTRACT(second FROM AGE(etl_end_dtm, etl_start_dtm))) AS decimal) AS etl_executiom_time_minutes
  FROM performance_statistics
) ps
JOIN build_statistics bs ON ps.correlation_id = bs.correlation_id
GROUP BY ps.client_id, bs.app_version, ps.etl_name
ORDER BY max_execution_time_minutes DESC;
```

## Query for identifying slowest ETLs. 
Analytical function, agg() over (partition by <columns>), is used to  compute the aggregate metrics.
```sql
CREATE OR REPLACE VIEW volume_performance_metrics_vw AS
SELECT
  distinct
  ps.client_id,
  bs.app_version,
   bs.status etl_status,
  ps.etl_name,
   ps.etl_execution_time_minutes,
  ROUND(MAX(ps.etl_execution_time_minutes) over (partition by ps.client_id, bs.app_version, ps.etl_name), 2) AS max_execution_time_minutes,
  ROUND(AVG(ps.etl_execution_time_minutes) over (partition by ps.client_id, bs.app_version, ps.etl_name), 2) AS avg_execution_time_minutes,
  COUNT(ps.correlation_id) over (partition by ps.client_id, bs.app_version, ps.etl_name) AS total_etl_count
FROM (
   SELECT
       correlation_id,
       client_id,
       etl_name,
       CAST((24 * 60 * EXTRACT(day FROM AGE(etl_end_dtm, etl_start_dtm))
                + 60 * EXTRACT(hour FROM AGE(etl_end_dtm, etl_start_dtm))
                     + EXTRACT(minute FROM AGE(etl_end_dtm, etl_start_dtm))
          + (1.0/60) * EXTRACT(second FROM AGE(etl_end_dtm, etl_start_dtm))) AS decimal) AS etl_execution_time_minutes
  FROM performance_statistics
) ps
JOIN build_statistics bs ON ps.correlation_id = bs.correlation_id
WHERE build_version = '99' -- filters to only those runs needed to identify bottnecks by using runtime tsting
ORDER BY max_execution_time_minutes DESC;
```


## Query that provides the latest processing detail per client.

```sql
CREATE OR REPLACE VIEW app_latest_builds_vw
AS
with tmp as (
 select a.*,
        rank() over (partition by environment, client_id, app_version, is_monthly order by last_update_dtm desc) as rnk
 from build_statistics a
 where db_schema is not null
 and status = 'SUCCEEDED'
)
select environment, client_id, app_version,
     (case is_monthly when 1 then 'monthly' else 'daily' end) as build_type,
     last_update_dtm, source_hive_schema, correlation_id, build_size_gb
from tmp
where rnk = 1
order by environment, client_id, oadw_version desc, build_type;
```

## Query that computes performance for individual steps of AWS step function
AWS step function execution history is captued in CloudWatch. Using AWS CLI, we can grab the execution time details as follows and persist in a table, step_function_statistics. We can then run SQL on the table for computing performance metrics.
   https://docs.aws.amazon.com/step-functions/latest/apireference/API_GetExecutionHistory.html
   
```sql
CREATE OR REPLACE VIEW aws_step_function_summary_stats_vw AS
SELECT
 a.correlation_id,
 a.client_id,
 a.step_name,
 a.step_event_id AS step_start_event_id,
 a.status AS step_start_status,
 a.step_exec_dtm AS step_start_dtm,
 b.step_event_id AS step_finish_event_id,
 b.status AS step_finish_status,
 b.step_exec_dtm AS step_finish_dtm,
 CAST((24 * 60 * EXTRACT(day FROM AGE(b.step_exec_dtm, a.step_exec_dtm))
     + 60 * EXTRACT(hour FROM AGE(b.step_exec_dtm, a.step_exec_dtm))
      + EXTRACT(minute FROM AGE(b.step_exec_dtm, a.step_exec_dtm))
       + (1.0/60) * EXTRACT(second FROM AGE(b.step_exec_dtm, a.step_exec_dtm))) AS decimal)
 AS step_execution_time_minutes
FROM step_function_statistics a
JOIN step_function_statistics b
ON (a.correlation_id = b.correlation_id
   AND a.step_name = b.step_name)
AND a.step_event_id < b.step_event_id
ORDER BY client_id, correlation_id, step_start_dtm DESC;
```

