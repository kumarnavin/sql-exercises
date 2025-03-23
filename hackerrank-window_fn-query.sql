https://www.hackerrank.com/challenges/15-days-of-learning-sql/problem?utm_campaign=challenge-recommendation&utm_medium=email&utm_source=24-hour-campaign&h_r=next-challenge&h_v=zen 

with cte_1 as (
select s.hacker_id, s.submission_date,
count(s.submission_id) over (partition by s.submission_date, s.hacker_id) as day_hacker_count,
count(s.submission_id) over (partition by s.submission_date) as day_count
from submissions s
),
cte as (
select cte_1.*, 
    rank() over (partition by submission_date order by day_hacker_count desc, hacker_id asc) as rnk 
from cte_1
)
select cte.submission_date, max(cte.day_count), cte.hacker_id, h.name
from cte
join hackers h on (h.hacker_id = cte.hacker_id)
where cte.rnk = 1
group by cte.submission_date, cte.hacker_id, h.name
order by cte.submission_date;
