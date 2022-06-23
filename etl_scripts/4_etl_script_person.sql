BEGIN;

WITH
"patients_temp" AS (SELECT subject_id, mimic_id as person_id, CASE WHEN gender ='F' THEN 8532 WHEN GENDER = 'M' THEN 8507 ELSE NULL END as gender_concept_id, strftime('%Y', dob) as year_of_birth, strftime('%m', dob) as month_of_birth, strftime('%d', dob) as day_of_birth, dob as birth_datetime, gender as gender_source_value FROM patients),
"gcpt_ethnicity_to_concept" AS (SELECT ethnicity, race_concept_id as race_concept_id, ethnicity_concept_id as ethnicity_concept_id FROM MIMIC.gcpt_ethnicity_to_concept),
"admissions" AS (SELECT DISTINCT subject_id AS subject_id, first_value(ethnicity) OVER(PARTITION BY subject_id ORDER BY admittime ASC) as race_source_value FROM MIMIC.admissions)
 INSERT INTO OMOP.PERSON
 (
     person_id
   , gender_concept_id
   , year_of_birth
   , month_of_birth
   , day_of_birth
   , birth_datetime
   , race_concept_id
   , ethnicity_concept_id
   , location_id
   , provider_id
   , care_site_id
   , person_source_value
   , gender_source_value
   , gender_source_concept_id
   , race_source_value
   , race_source_concept_id
   , ethnicity_source_value
   , ethnicity_source_concept_id
 )
 SELECT
  person_id
, gender_concept_id
, year_of_birth
, month_of_birth
, day_of_birth
, birth_datetime
, gcpt_ethnicity_to_concept.race_concept_id
, 0 as ethnicity_concept_id
, CAST(null AS INTEGER) location_id
, CAST(null AS INTEGER) provider_id
, CAST(null AS INTEGER) care_site_id
, CAST(subject_id AS Text) person_source_value
, gender_source_value
, CAST(null AS INTEGER) gender_source_concept_id
, admissions.race_source_value
, CAST(null AS INTEGER) race_source_concept_id
, CAST(null AS text) ethnicity_source_value
, CAST(null AS INTEGER) ethnicity_source_concept_id
FROM patients_temp
LEFT JOIN admissions USING (subject_id)
LEFT JOIN gcpt_ethnicity_to_concept ON (admissions.race_source_value = gcpt_ethnicity_to_concept.ethnicity);

COMMIT;