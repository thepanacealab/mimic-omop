BEGIN;

SELECT "Condition occurrence - check ICD diagnoses row count matches (OMOP): ";
SELECT COUNT(distinct person_id), COUNT(distinct visit_occurrence_id)
FROM omop.condition_occurrence
WHERE condition_type_concept_id != 42894222;
SELECT "Condition occurrence - check ICD diagnoses row count matches (MIMIC): ";
SELECT COUNT(distinct subject_id), COUNT(distinct hadm_id)
FROM diagnoses_icd
WHERE NULLIF(icd9_code,'') IS NOT NULL;
/*
SELECT "======================================================================";
SELECT "Condition occurrence - Diagnosis in admission same (OMOP): ";
WITH tmp as
(
  SELECT distinct visit_occurrence_id, *
  FROM omop.condition_occurrence
  WHERE condition_type_concept_id = 42894222
)
SELECT CAST(condition_source_value AS text), COUNT(1) FROM tmp GROUP BY 1 ORDER BY 2, 1;
SELECT "Condition occurrence - Diagnosis in admission same (MIMIC): ";
SELECT CAST(diagnosis AS text), COUNT(1) FROM admissions GROUP BY 1 ORDER BY 2, 1;
SELECT "======================================================================";

SELECT "Condition occurrence - Distrib. diagnosis the same (OMOP): ";
with tmp as
(
  SELECT distinct visit_occurrence_id, *
  FROM omop.condition_occurrence
  WHERE condition_type_concept_id = 42894222
)
SELECT CAST(condition_source_value AS text), COUNT(1) FROM tmp GROUP BY 1 ORDER BY 2, 1;
SELECT "Condition occurrence - Distrib. diagnosis the same (MIMIC): ";
SELECT CAST(diagnosis AS text), COUNT(1) FROM admissions GROUP BY 1 ORDER BY 2, 1;
*/
SELECT "======================================================================";

SELECT "OMOP Condition occurrence - There is source concept in measurement not described (Actual result):";
SELECT CAST(COUNT(1) AS INTEGER)
FROM omop.condition_occurrence
WHERE condition_source_concept_id = 0;
SELECT "OMOP Condition occurrence - There is source concept in measurement not described (Expected):";
SELECT 0;
SELECT "======================================================================";

SELECT "OMOP Condition occurrence - Primary key checker (Actual result)";
SELECT CAST(COUNT(1) AS INTEGER)
FROM
(
  SELECT CAST(COUNT(1) AS INTEGER)
  FROM omop.condition_occurrence
  GROUP BY condition_occurrence_id
  having COUNT(1) > 1
) as t;
SELECT "OMOP Condition occurrence - Primary key checker (Expected)";
SELECT 0;
SELECT "======================================================================";

SELECT "OMOP Condition occurrence - Standard  concept checker (Actual result)";
SELECT COUNT(1) FROM omop.condition_occurrence
LEFT JOIN omop.concept ON condition_concept_id = concept_id
WHERE condition_concept_id != 0 AND standard_concept != 'S';
SELECT "OMOP Condition occurrence - Standard  concept checker (Expected)";
SELECT 0;
SELECT "======================================================================";

SELECT "OMOP Condition occurrence - start_datetime should be > end_datetime (Actual Result): ";
WITH tmp AS
(
  SELECT visit_detail_id, visit_occurrence_id
  , CASE
      WHEN CAST(strftime('%s', condition_end_datetime)  AS  integer) < 
      CAST(strftime('%s', condition_start_datetime)  AS  integer)
      THEN 1
    ELSE 0 END AS abnormal
  FROM omop.condition_occurrence
)
SELECT CAST(sum(abnormal) AS INTEGER) FROM tmp;
SELECT "OMOP Condition occurrence - start_datetime should be > end_datetime (Expected): ";
SELECT 0;
SELECT "======================================================================";

SELECT "OMOP Condition occurrence - start_date should be > end_date (Actual Result):";
WITH tmp AS
(
  SELECT visit_detail_id, visit_occurrence_id
  , CASE
      WHEN CAST(strftime('%s', condition_end_date)  AS  integer) < 
      CAST(strftime('%s', condition_start_date)  AS  integer)
      THEN 1
    ELSE 0 END AS abnormal
  FROM omop.condition_occurrence
)
SELECT CAST(sum(abnormal) AS INTEGER) FROM tmp;
SELECT "OMOP Condition occurrence - start_date should be > end_date (Expected):";
SELECT 0;

ROLLBACK;