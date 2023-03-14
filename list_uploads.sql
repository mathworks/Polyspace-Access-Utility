/*
(c) MathWorks Inc. 2023
Do not edit this script
*/
SELECT "RefRun", "StartTime", "EndTime", AGE("EndTime", "StartTime") AS "UploadDuration" FROM "Status"."Etl" WHERE "Status" = 'Failed'

