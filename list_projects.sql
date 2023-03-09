/*
(c) MathWorks Inc. 2023
*/
SELECT p."DefinitionID", p."Name"::text FROM "Project"."Definition" p LEFT JOIN "Project"."Hierarchy" h ON p."DefinitionID" = h."RefChildProject" WHERE h."RefChildProject" IS NULL
