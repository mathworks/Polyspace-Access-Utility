/*
(c) MathWorks Inc. 2023
Do not edit this script
*/
COPY (SELECT tablename, indexname, indexdef FROM pg_indexes ORDER BY tablename, indexname) TO STDOUT WITH CSV HEADER
