BEGIN;
SELECT "Observation - Religion distribution matches concept 4052017 (OMOP):";
SELECT CAST(value_as_string AS TEXT) as religion
     , COUNT(1)
FROM omop.observation
WHERE observation_concept_id = 4052017 and value_as_string != 'OTHER' 
and value_as_string != 'NOT SPECIFIED' and value_as_string != 'UNOBTAINABLE'
GROUP BY 1
ORDER BY 2, 1 DESC;
SELECT "Observation - Religion distribution matches concept 4052017 (MIMIC):";
SELECT cast(religion as text), count(1)
FROM admissions
WHERE NULLIF(religion,'') is not null
and religion != 'OTHER' and religion != 'NOT SPECIFIED' and religion != 'UNOBTAINABLE'
GROUP BY 1
ORDER BY 2, 1 desc;
SELECT "=========================================================================";

SELECT "Observation - Language distribution matches concept 40758030 (OMOP):";
SELECT CAST(value_as_string AS TEXT) as language, COUNT(1)
FROM omop.observation WHERE observation_concept_id = 40758030
GROUP BY 1 ORDER BY 2, 1 DESC;
SELECT "Observation - Language distribution matches concept 40758030 (MIMIC):";
SELECT cast(language as TEXT), count(1) FROM admissions
WHERE NULLIF(language,'') is not null
GROUP BY 1 ORDER BY 2, 1 desc;
SELECT "=========================================================================";

SELECT "Observation - Marital distribution matches concept 40766231 (OMOP):";
SELECT CAST(value_as_string AS TEXT) as marital_status
     , COUNT(1)
FROM omop.observation
WHERE observation_concept_id = 40766231
GROUP BY 1 ORDER BY 2, 1 DESC;
SELECT "Observation - Marital distribution matches concept 40766231 (MIMIC):";
SELECT CAST(marital_status AS TEXT), count(1)
FROM admissions
WHERE NULLIF(marital_status,'') is not null
GROUP BY 1 ORDER BY 2, 1 desc;
SELECT "=========================================================================";

SELECT "Observation - Insurance distribution matches concept 46235654 (OMOP):";
SELECT CAST(value_as_string AS TEXT) as insurance
     , COUNT(1)
FROM omop.observation
WHERE observation_concept_id = 46235654
GROUP BY 1 ORDER BY 2, 1 DESC;
SELECT "Observation - Insurance distribution matches concept 46235654 (MIMIC):";
SELECT CAST(insurance AS TEXT), count(1)
FROM admissions
WHERE NULLIF(insurance,'') is not null
GROUP BY 1 ORDER BY 2, 1 desc;
SELECT "=========================================================================";

SELECT "Observation - Ethnicity distribution matches concept 44803968 (OMOP)";
SELECT CAST(value_as_string AS TEXT) as ethnicity
     , COUNT(1)
FROM omop.observation
WHERE observation_concept_id =  44803968
GROUP BY 1 ORDER BY 2, 1 DESC;
SELECT "Observation - Ethnicity distribution matches concept 44803968 (MIMIC)";
SELECT CAST(ethnicity AS TEXT), count(1)
FROM admissions
WHERE NULLIF(ethnicity,'') is not null
GROUP BY 1 ORDER BY 2, 1 desc;
SELECT "=========================================================================";

SELECT "OMOP Observation - source concept described (Expected):";
SELECT 0;
SELECT "OMOP Observation - source concept described (Actual Result):";
SELECT CAST(count(1) AS integer) FROM omop.observation where observation_source_concept_id = 0;
SELECT "=========================================================================";

SELECT "OMOP Observation - Primary key is always unique (Actual result):";
select CAST(count(1) AS integer)
from
(
  SELECT CAST(count(1) AS integer)
  FROM omop.observation
  group by observation_id
  having count(1) > 1
) as t;
SELECT "OMOP Observation - Primary key is always unique (Expected):";
SELECT 0;
SELECT "=========================================================================";

--NOTE: There are no observation_concept_id with 4085802 as value (accoording to the etl script)
SELECT "Observation - Datetimeevents number (OMOP):";
select CAST(count(1) AS integer) from omop.observation where observation_concept_id = 4085802;
SELECT "Observation - Datetimeevents number (MIMIC):";
select CAST(count(1) AS integer) from datetimeevents where NULLIF(error,'') is null OR error = 0;
SELECT "=========================================================================";

SELECT "OMOP Observation - Standard concept checker (Actual result): ";
SELECT CAST(count(1) AS integer)
FROM omop.observation
LEFT JOIN omop.concept ON observation_concept_id = concept_id
WHERE observation_concept_id != 0
AND standard_concept != 'S';
SELECT "OMOP Observation - Standard concept checker (Expected): ";
SELECT 0;

ROLLBACK;