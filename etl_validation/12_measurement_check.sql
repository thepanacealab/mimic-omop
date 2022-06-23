BEGIN;
SELECT load_extension('/data/student_work/luis_work/mimicIII/stats');
--This one is experimental
SELECT "Measurement - check microbiology organism distributions match (MIMIC): ";
SELECT CAST(org_name AS TEXT), count(1)
FROM
(
	SELECT DISTINCT hadm_id, spec_type_desc, org_name, coalesce(charttime, chartdate)
    AS org_name
	FROM microbiologyevents
  WHERE NULLIF(org_name,'') IS NOT NULL
) tmp
GROUP BY org_name ORDER BY 2, 1 desc;
SELECT "Measurement - check microbiology organism distributions match (OMOP): ";
SELECT CAST(value_source_value AS TEXT), count(1)
FROM omop.measurement
WHERE measurement_type_concept_id = 2000000007
AND CAST(value_as_concept_id AS INTEGER) IS NOT 9189
GROUP BY value_source_value ORDER BY 2, 1 desc;
SELECT "======================================================================";

SELECT "OMOP Measurement - there is a source concept in measurement not described (Expected):";
SELECT 0;
SELECT "OMOP Measurement - there is a source concept in measurement not described (Actual result):";
SELECT count(1) FROM omop.measurement WHERE measurement_source_concept_id = 0;
SELECT "======================================================================";

SELECT "OMOP Measurement - check for duplicate primary keys (Expected)";
SELECT 0;
SELECT "OMOP Measurement - check for duplicate primary keys (Actual result)";
SELECT COUNT(1)
FROM
(
  SELECT COUNT(1)
  FROM omop.measurement
  GROUP BY measurement_id
  HAVING COUNT(1) > 1
) as t;
SELECT "======================================================================";

SELECT "OMOP Measurement - Standard concept checker (Expected): ";
SELECT 0;
SELECT "OMOP Measurement - Standard concept checker (Actual Result): ";
SELECT COUNT(1)
FROM omop.measurement
LEFT JOIN omop.concept
  ON measurement_concept_id = concept_id
WHERE measurement_concept_id != 0
AND standard_concept != 'S';
SELECT "======================================================================";

SELECT " Measurement - check row count match (OMOP): ";
WITH omop_measure AS
(
  SELECT CAST(concept_code AS integer) as itemid, count(*)
  FROM omop.measurement
  JOIN omop.concept ON measurement_source_concept_id = concept_id
  WHERE measurement_type_concept_id IN (44818701, 44818702, 2000000003, 2000000009, 2000000010, 2000000011)
  group by 1 order by 1 asc
),
omop_observation AS
(
  SELECT CAST(concept_code AS integer) as itemid, count(*)
  FROM omop.observation
  JOIN omop.concept ON observation_source_concept_id = concept_id
  WHERE observation_type_concept_id = 581413
  group by 1 order by 1 asc
),
omop_result AS
(
  SELECT * from omop_measure
  UNION
  SELECT * from omop_observation
)
SELECT itemid, count(*)
FROM omop_result
ORDER BY 1 asc;

SELECT " Measurement - check row count match (MIMIC): ";
WITH mimic_chartevents as
(
	SELECT itemid, count(*) from chartevents WHERE NULLIF(error,'') is null or error = 0
    group by 1 order by 1 asc
),
mimic_labevents AS
(
	SELECT itemid, count(*) from labevents
	group by 1 order by 1 asc
),
mimic_output AS
(
	SELECT itemid, count(*) FROM outputevents WHERE NULLIF(iserror,'') is null
	group by 1 order by 1 asc
),
mimic_result AS
(
	SELECT * from mimic_chartevents
	UNION
	SELECT * from mimic_labevents
	UNION
	SELECT * FROM mimic_output
)
SELECT itemid, count(*) FROM mimic_result ORDER BY 1 asc;

ROLLBACK;