BEGIN;
SELECT "Visit detail - test visit_source_value and visit_source_concept_id match (OMOP):";
SELECT count(visit_source_concept_id) FROM omop.visit_detail
GROUP BY visit_source_concept_id ORDER BY 1 DESC;
SELECT "--------------------------------------------------------------";
SELECT count(visit_source_value) FROM omop.visit_detail
GROUP BY visit_source_value ORDER BY 1 DESC;
SELECT "=============================================================";

SELECT "Visit detail - test admitting_source_concept_id and admitting_source_value match (OMOP):";
SELECT COUNT(admitting_source_concept_id) FROM omop.visit_detail
GROUP BY admitting_source_concept_id ORDER BY 1 DESC;
SELECT "--------------------------------------------------------------";
SELECT COUNT(admitting_source_value) FROM omop.visit_detail
GROUP BY admitting_source_value ORDER BY 1 DESC;
SELECT "=============================================================";
SELECT "Visit detail - test patients number in visit_detail/icustays (OMOP):";
SELECT COUNT(distinct person_id), COUNT(distinct visit_occurrence_id) FROM omop.visit_detail
WHERE visit_detail_concept_id = 32037 AND visit_type_concept_id = 2000000006;
SELECT "Visit detail - test patients number in visit_detail/icustays (MIMIC):";
SELECT COUNT(distinct subject_id), COUNT(distinct hadm_id) FROM icustays;
SELECT "=============================================================";

SELECT "OMOP - Visit detail - check start_datetime < end_datetime (Actual result):";
WITH tmp AS
(
  SELECT visit_detail_id, visit_occurrence_id
  , CASE
      WHEN CAST(strftime('%s', visit_end_datetime)  AS  integer) <
      CAST(strftime('%s', visit_start_datetime)  AS  integer)
      THEN 1
    ELSE 0 END AS abnormal
  FROM omop.visit_detail
)
SELECT sum(abnormal) FROM tmp;
SELECT "OMOP - Visit detail - check start_datetime < end_datetime (Expected):";
SELECT 0;
SELECT "=============================================================";

SELECT "OMOP - Visit detail - check start_date < end_date (Actual result):";
WITH tmp AS
(
  SELECT visit_detail_id, visit_occurrence_id
    , CASE
        WHEN CAST(strftime('%s', visit_end_date)  AS  integer) <
         CAST(strftime('%s', visit_start_date)  AS  integer)
        THEN 1
        ELSE 0
      END AS abnormal
  FROM omop.visit_detail
)
SELECT sum(abnormal) FROM tmp;

SELECT "OMOP - Visit detail - check start_datet < end_date (Expected):";
SELECT 0;
SELECT "=============================================================";

SELECT "Visit detail - check care site is never null (OMOP):";
SELECT CAST(COUNT(*) AS INTEGER) AS res
FROM omop.visit_detail
WHERE NULLIF(care_site_id,'') IS NULL;
SELECT "Visit detail - check care site is never null (MIMIC):";
SELECT CAST(0 AS INTEGER) AS res;
ROLLBACK;