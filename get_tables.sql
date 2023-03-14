/*
(c) MathWorks Inc. 2023
Do not edit this script
*/
COPY (
select 
       table_schema, 
       table_name, 
       pg_size_pretty(pg_relation_size('"'||table_schema||'"."'||table_name||'"')) as pg_relation_size,
       pg_size_pretty(pg_total_relation_size('"'||table_schema||'"."'||table_name||'"')) as pg_total_relation_size
from information_schema.tables
where table_schema NOT IN ('pg_catalog', 'information_schema')
order by pg_total_relation_size('"'||table_schema||'"."'||table_name||'"') DESC
) TO STDOUT WITH CSV HEADER

