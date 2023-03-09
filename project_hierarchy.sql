/*
(c) MathWorks Inc. 2023
*/
COPY ( 
WITH RECURSIVE ancestors(id, path) AS (SELECT p."DefinitionID", p."Name"::text FROM "Project"."Definition" p LEFT JOIN "Project"."Hierarchy" h ON p."DefinitionID" = h."RefChildProject" WHERE h."RefChildProject" IS NULL UNION ALL SELECT p."DefinitionID", (a.path || '/' || p."Name")::text FROM "Project"."Definition" p LEFT JOIN "Project"."Hierarchy" h ON p."DefinitionID" = h."RefChildProject" INNER JOIN ancestors a ON a.id = h."RefProject") SELECT path FROM ancestors LEFT JOIN "Result"."Run" r ON ancestors.id = r."RefProject" GROUP BY path order by path) TO STDOUT
