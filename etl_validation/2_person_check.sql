BEGIN;
SELECT load_extension('/data/student_work/luis_work/mimicIII/stats');
SELECT "Total number of patients (OMOP): ";
SELECT COUNT(*) AS num_persons_count FROM omop.person;

SELECT "Total number of patients (MIMIC): ";
SELECT COUNT(*) AS num_persons_count FROM patients;

SELECT "=========================================";
SELECT "Gender distribution (OMOP): ";
SELECT COUNT(person.person_ID) AS num_persons_count
FROM omop.person as person
INNER JOIN omop.concept as concept ON person.gender_concept_id = concept.CONCEPT_ID
GROUP BY person.gender_CONCEPT_ID, concept.CONCEPT_NAME
ORDER BY num_persons_count DESC;
SELECT "Gender distribution (MIMIC): ";
SELECT  COUNT(gender) AS num_persons_count
FROM patients
GROUP BY gender
ORDER BY num_persons_count DESC;
SELECT "=========================================";

SELECT "Date of birth year distribution (MIMIC): ";
SELECT percentile_25(CAST(strftime('%Y',dob) AS INTEGER)) AS percentile25
       , median(CAST(strftime('%Y',dob) AS INTEGER)) AS median
       , percentile_75(CAST(strftime('%Y',dob) AS INTEGER)) AS percentile75
       , MIN(CAST(strftime('%Y',dob) AS INTEGER)) AS minimum
       , MAX(CAST(strftime('%Y',dob) AS INTEGER)) AS maximum
       , CAST(AVG(CAST(strftime('%Y',dob) AS INTEGER)) AS INTEGER) AS mean
       , CAST(STDDEV(CAST(strftime('%Y',dob) AS INTEGER)) AS INTEGER) AS stddev
  FROM patients LIMIT 1;

SELECT "Date of birth year distribution (OMOP): ";
SELECT percentile_25(CAST(strftime('%Y',birth_datetime) AS INTEGER)) AS percentile25
       , median(CAST(strftime('%Y',birth_datetime) AS INTEGER)) AS median
       , percentile_75(CAST(strftime('%Y',birth_datetime) AS INTEGER)) AS percentile75
       , MIN(CAST(strftime('%Y',birth_datetime) AS INTEGER)) AS minimum
       , MAX(CAST(strftime('%Y',birth_datetime) AS INTEGER)) AS maximum
       , CAST(AVG(CAST(strftime('%Y',birth_datetime) AS INTEGER)) AS INTEGER) AS mean
       , CAST(STDDEV(CAST(strftime('%Y',birth_datetime) AS INTEGER)) AS INTEGER) AS stddev
  FROM omop.person LIMIT 1;

SELECT "=========================================";

SELECT "OMOP - No. births after deaths (Expected): ";
SELECT 0;
SELECT "OMOP - No. births after deaths (Actual Result): ";
WITH tmp AS
(
        SELECT person_id
             , CASE when CAST(strftime('%s',death.death_datetime) AS INTEGER) < 
             CAST(strftime('%s',person.birth_datetime) AS INTEGER) THEN 1 ELSE 0 END AS abnormal
        FROM omop.person
        JOIN omop.death USING (person_id)
)
SELECT max(abnormal) FROM tmp;
SELECT "=========================================";
ROLLBACK;