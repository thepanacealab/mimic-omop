BEGIN;

CREATE TEMP VIEW "death_adm" AS 
	SELECT patients.mimic_id as person_id, 
	MIN(strftime(deathtime), strftime(dischtime)) as death_datetime, 
	38003569 as death_type_concept_id
	FROM (SELECT DISTINCT subject_id as subject_id, first_value(deathtime) OVER(PARTITION BY subject_id ORDER BY admittime ASC) as deathtime, dischtime FROM admissions WHERE NULLIF(deathtime,'') IS NOT NULL) a --donor organs
	LEFT JOIN patients USING (subject_id)
	WHERE NULLIF(deathtime,'') IS NOT NULL;

CREATE TEMP VIEW "death_ssn" AS
	SELECT mimic_id as person_id, dod as death_datetime, 261 as death_type_concept_id
	FROM patients LEFT JOIN death_adm ON (mimic_id = person_id)
	WHERE NULLIF(dod,'') IS NOT NULL AND NULLIF(death_adm.person_id,'') IS NULL;

CREATE TEMP VIEW "insert_death" AS 
SELECT * FROM(
 SELECT person_id, CAST(death_datetime AS text), death_datetime, death_type_concept_id 
 FROM  death_adm
  UNION ALL
 SELECT person_id, CAST(death_datetime AS text), death_datetime, death_type_concept_id 
 FROM  death_ssn
) GROUP BY person_id;

 INSERT INTO OMOP.DEATH(person_id, death_date, death_datetime, death_type_concept_id)
 SELECT * FROM insert_death;

COMMIT;