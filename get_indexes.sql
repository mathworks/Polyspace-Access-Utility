/*
(c) MathWorks Inc. 2023
*/
COPY (SELECT tablename, indexname, indexdef FROM pg_indexes ORDER BY tablename, indexname) TO STDOUT WITH CSV HEADER
