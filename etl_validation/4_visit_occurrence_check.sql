BEGIN;
SELECT "Visit occurrence/admission table number admission (MIMIC): ";
SELECT count(*) FROM admissions;
SELECT "Visit occurrence/admission table number admission (OMOP): ";
SELECT count(*) FROM omop.visit_occurrence;

--PRAGMA case_sensitive_like=ON;
SELECT "==============================================================";
SELECT "Number of hospital admissions who die in-hospital match (MIMIC)";
SELECT COUNT(*) FROM admissions WHERE hospital_expire_flag = 1
OR LOWER(diagnosis) LIKE '%organ donor%';
SELECT "Number of hospital admissions who die in-hospital match (OMOP)";
SELECT count(distinct visit_occurrence_id) FROM omop.visit_occurrence
WHERE discharge_to_concept_id = 4216643
OR discharge_to_concept_id = 4022058;
SELECT "==============================================================";
--PRAGMA case_sensitive_like=OFF;

SELECT "Visit occurrence table -- same distribution adm (MIMIC): ";
SELECT cast(admission_type as TEXT) as visit_source_value, count(1) FROM admissions group by 1 ORDER BY 2,1 DESC;
SELECT "Visit occurrence table -- same distribution adm (OMOP): ";
SELECT cast (visit_source_value as TEXT), count(1) FROM omop.visit_occurrence group by 1 ORDER BY 2,1 DESC;
SELECT "==============================================================";

SELECT "Visit occurrence table -- distribution admit source value (MIMIC): ";
SELECT
  CAST(
    CASE WHEN LOWER(diagnosis) LIKE '%organ donor%' THEN 'DEAD/EXPIRED'
    ELSE admission_location END
  AS TEXT) as admitting_source_value
  , count(1)
  FROM admissions
  GROUP BY 1
  ORDER BY 2,1 DESC;
SELECT "Visit occurrence table -- distribution admit source value (OMOP): ";
SELECT
  CAST(admitting_source_value
    AS TEXT) as admitting_source_value
  , count(1)
  FROM omop.visit_occurrence
  GROUP BY 1
  ORDER BY 2,1 DESC;
SELECT "==============================================================";

SELECT "Visit occurrence table -- repartition discharge_to_source_value (MIMIC): ";
SELECT
  CAST(
    CASE WHEN LOWER(diagnosis) LIKE '%organ donor%' THEN diagnosis
    ELSE discharge_location END
  AS TEXT) as discharge_to_source_value
  , count(1)
  FROM admissions
  GROUP BY 1
  ORDER BY 2,1 DESC;
SELECT "Visit occurrence table -- repartition discharge_to_source_value (OMOP): ";
SELECT
  CAST(
    discharge_to_source_value
  AS TEXT) as discharge_to_source_value
, count(1)
FROM omop.visit_occurrence
GROUP BY 1
ORDER BY 2,1 DESC;
SELECT "==============================================================";

SELECT "Visit occurrence table -- links checker (MIMIC): ";
SELECT count(visit_source_concept_id) FROM omop.visit_occurrence group by visit_source_concept_id order by 1 desc;
SELECT "Visit occurrence table -- links checker (OMOP): ";
SELECT count(visit_source_value) FROM omop.visit_occurrence group by visit_source_value order by 1 desc;
SELECT "==============================================================";

SELECT "OMOP - Visit occurrence table -- start_date > end_date (Expected): ";
SELECT 0;
SELECT "OMOP - Visit occurrence table -- start_date > end_date (Actual Result): ";
WITH tmp AS
(
        SELECT visit_occurrence_id, CASE WHEN visit_end_date < visit_start_date THEN 1 ELSE 0 END AS abnormal
        FROM omop.visit_occurrence
)
SELECT max(abnormal) FROM tmp;
ROLLBACK;