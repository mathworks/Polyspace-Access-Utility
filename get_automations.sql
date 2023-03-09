/*
(c) MathWorks Inc. 2023
*/
COPY (
select * from "Metadata"."Automation"
) TO STDOUT WITH CSV HEADER
