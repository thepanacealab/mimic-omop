BEGIN;
SELECT "Procedure occurrence - check all procedureevents_mv rows inserted (OMOP):";
SELECT count (*), count(distinct person_id), count(distinct visit_occurrence_id)
FROM omop.procedure_occurrence WHERE procedure_type_concept_id = 38000275;
SELECT "Procedure occurrence - check all procedureevents_mv rows inserted (MIMIC):";
SELECT count(*), count(distinct subject_id), count(distinct hadm_id)
FROM procedureevents_mv WHERE cancelreason = 0;
SELECT "======================================================================";

SELECT "Procedure occurrence - check label is consistent with source_value (OMOP):";
SELECT CAST(procedure_source_value AS text) as label, count(1)
from omop.procedure_occurrence
WHERE procedure_type_concept_id = 38000275
GROUP BY procedure_source_value ORDER BY 2,1 desc;
SELECT "Procedure occurrence - check label is consistent with source_value (MIMIC):";
SELECT CAST(label AS text), count(1)
from procedureevents_mv
JOIN d_items using (itemid)
WHERE cancelreason = 0
GROUP BY 1 ORDER BY 2,1 desc;
SELECT "======================================================================";

SELECT "Procedure occurrence - Check all CPT code rows inserted (OMOP):";
SELECT count (*), count(distinct person_id), count(distinct visit_occurrence_id)
from omop.procedure_occurrence
WHERE procedure_type_concept_id = 257 ;

SELECT "Procedure occurrence - Check all CPT code rows inserted (MIMIC):";
SELECT count(*), count(distinct subject_id), count(distinct hadm_id)
FROM cptevents;
SELECT "======================================================================";

SELECT "Procedure occurrence - Check CPT subsections mapped correctly (OMOP):";
SELECT count(1)
FROM omop.procedure_occurrence
WHERE procedure_type_concept_id = 257
GROUP BY procedure_source_value
ORDER BY count(1) DESC;
SELECT "Procedure occurrence - Check CPT subsections mapped correctly (MIMIC):";
SELECT count(1)
FROM cptevents
GROUP BY subsectionheader
ORDER BY count(*) DESC;
SELECT "======================================================================";

SELECT "Procedure occurrence - Chcek ICD procedure rows inserted (MIMIC):";
SELECT count(*), count(distinct subject_id), count(distinct hadm_id) FROM procedures_icd;

SELECT "Procedure occurrence - Chcek ICD procedure rows inserted (OMOP):";
SELECT count (*), count(distinct person_id), count(distinct visit_occurrence_id)
FROM omop.procedure_occurrence
WHERE procedure_type_concept_id = 38003622;

ROLLBACK;