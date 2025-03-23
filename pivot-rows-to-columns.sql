/*** 
Pivot rows into columns
https://www.hackerrank.com/challenges/occupations/problem?isFullScreen=true&h_r=next-challenge&h_v=zen 
***/
  
with cte as (select o.*, (case when occupation='Doctor' then 1
 when occupation='Professor' then 2
 when occupation='Singer' then 3
 when occupation='Actor' then 4
end ) as rnk
from occupations o
order by occupation, name
),
d as (select cte.name, rownum as rnum from cte where rnk=1),
p as (select cte.name, rownum as rnum  from cte where rnk=2),
s as (select cte.name, rownum as rnum  from cte where rnk=3),
a as (select cte.name, rownum as rnum  from cte where rnk=4)
select d.name, p.name,s.name,a.name 
from d
full outer join p on (d.rnum = p.rnum)
full outer join s on (s.rnum = p.rnum and s.rnum = d.rnum)
full outer join a on (a.rnum = s.rnum and a.rnum = p.rnum and a.rnum = d.rnum)
order by 1 nulls last, 2 nulls last, 3 nulls last, 4 nulls last
;             
