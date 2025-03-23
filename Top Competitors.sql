/*
https://www.hackerrank.com/challenges/full-score/problem?utm_campaign=challenge-recommendation&utm_medium=email&utm_source=24-hour-campaign
*/

with cte as (
    select s.hacker_id, h.name, count(case when s.score = d.score then s.challenge_id else null end) as max_score_cnt
from submissions s
join challenges c on (c.challenge_id = s.challenge_id)
join difficulty d on (d.difficulty_level = c.difficulty_level)
join hackers h on (h.hacker_id = s.hacker_id)
    group by s.hacker_id, h.name
    )
select hacker_id || ' ' || name
 from cte
where max_score_cnt > 1
order by max_score_cnt desc, hacker_id
;
