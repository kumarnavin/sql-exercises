
https://www.hackerrank.com/challenges/draw-the-triangle-1/problem?isFullScreen=true

with cte as (select level as lvl, '*' as str
from dual
connect by level <=20
)
select rpad(str,lvl*2,' *') 
from cte
order by lvl desc;

