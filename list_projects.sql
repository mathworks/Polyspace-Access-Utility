/*
(c) MathWorks Inc. 2023
Do not edit this script
*/
SELECT p."DefinitionID", p."Name"::text FROM "Project"."Definition" p LEFT JOIN "Project"."Hierarchy" h ON p."DefinitionID" = h."RefChildProject" WHERE h."RefChildProject" IS NULL
