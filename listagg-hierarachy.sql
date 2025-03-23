
/*
https://oracle-base.com/articles/misc/string-aggregation-techniques 
ORACLE: Create LISTAGG equivalent using CONNECT_BY_PATH

TABLE: emp (ename, deptno) 
*/

SELECT deptno,
       LTRIM(MAX(SYS_CONNECT_BY_PATH(ename,','))
       KEEP (DENSE_RANK LAST ORDER BY curr),',') AS employees
FROM   (SELECT deptno,
               ename,
               ROW_NUMBER() OVER (PARTITION BY deptno ORDER BY ename) AS curr,
               ROW_NUMBER() OVER (PARTITION BY deptno ORDER BY ename) -1 AS prev
        FROM   emp)
GROUP BY deptno
CONNECT BY prev = PRIOR curr AND deptno = PRIOR deptno
START WITH curr = 1;

/*
    DEPTNO EMPLOYEES
---------- --------------------------------------------------
        10 CLARK,KING,MILLER
        20 ADAMS,FORD,JONES,SCOTT,SMITH
        30 ALLEN,BLAKE,JAMES,MARTIN,TURNER,WARD

3 rows selected.
*/

