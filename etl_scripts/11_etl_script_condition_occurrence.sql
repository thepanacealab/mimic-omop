BEGIN;

----- Updating non-standard concepts to standard concepts from manual mapping table------------------------
CREATE TEMP VIEW "gcpt_admissions_diagnosis_to_concept_temp" AS
 
SELECT gcpt.concept_id, concept_id_1, concept.concept_name, standard_concept FROM gcpt_admissions_diagnosis_to_concept AS gcpt
LEFT JOIN concept ON gcpt.concept_id = concept.concept_id LEFT JOIN concept_relationship ON concept_id_2 = gcpt.concept_id
WHERE standard_concept != 'S' AND relationship_id = 'Mapped from' GROUP BY gcpt.concept_id;
 
UPDATE gcpt_admissions_diagnosis_to_concept SET concept_id = (SELECT concept_id_1 FROM gcpt_admissions_diagnosis_to_concept_temp gcpt
WHERE gcpt.concept_id = gcpt_admissions_diagnosis_to_concept.concept_id)
WHERE concept_id IN (SELECT concept_id FROM gcpt_admissions_diagnosis_to_concept_temp);
-------------------------------------------------------------------------------------

WITH
"gcpt_seq_num_to_concept_temp" as (SELECT seq_num, concept_id as condition_type_concept_id FROM gcpt_seq_num_to_concept),
"icd9_concept" as ( SELECT concept_id, concept_code FROM OMOP.concept WHERE vocabulary_id = 'ICD9CM'),
"diag" as (
SELECT
    mimic_id as condition_occurrence_id
  , subject_id
  , hadm_id
  , CASE
        WHEN ICD9_CODE LIKE 'E%' AND LENGTH(ICD9_CODE) > 4 THEN substr(ICD9_CODE, 1, 4) || '.' || substr(ICD9_CODE, 5)
        WHEN ICD9_CODE LIKE 'E%' AND length(ICD9_CODE) = 4 THEN ICD9_CODE
        WHEN ICD9_CODE NOT LIKE 'E%' AND length(ICD9_CODE) > 3 THEN substr(ICD9_CODE, 1, 3) || '.' || substr(ICD9_CODE, 4)
        WHEN ICD9_CODE NOT LIKE 'E%' AND length(ICD9_CODE) = 3 THEN ICD9_CODE ELSE NULL
    END as concept_code
  , seq_num
  , icd9_code as condition_source_value
FROM diagnoses_icd
WHERE NULLIF(icd9_code,'') IS NOT NULL
),
"snomed_map" as (
   SELECT rel.concept_id_1
        , min(rel.concept_id_2) AS condition_concept_id
     FROM OMOP.concept_relationship as rel
     JOIN OMOP.concept as c1
       ON (concept_id_1       = c1.concept_id)
     JOIN OMOP.concept as c2
       ON (concept_id_2       = c2.concept_id)
    WHERE rel.relationship_id = 'Maps to'
      AND c1.vocabulary_id    = 'ICD9CM'
      AND c2.vocabulary_id    = 'SNOMED'
      AND c2.concept_class_id = 'Clinical Finding'
      AND c2.standard_concept    = 'S'
    GROUP BY rel.concept_id_1
),
"admissions_temp" as (SELECT subject_id as hadm_subject_id, hadm_id, mimic_id as visit_occurrence_id, diagnosis, coalesce(edregtime, admittime) as condition_start_datetime, dischtime as condition_end_datetime FROM admissions),
"patients_temp" as (SELECT subject_id, mimic_id as person_id FROM patients),
"adm_diag_cpt" AS (SELECT * FROM gcpt_admissions_diagnosis_to_concept),
"row_to_insert" AS  (SELECT
  condition_occurrence_id
, person_id
, coalesce(NULLIF(condition_concept_id,''), 0) as condition_concept_id
,(CASE WHEN condition_end_datetime > condition_start_datetime THEN CAST(condition_start_datetime AS text) ELSE CAST(condition_end_datetime AS text) END) as condition_start_date
,(CASE WHEN condition_end_datetime > condition_start_datetime THEN condition_start_datetime ELSE condition_end_datetime END) as condition_start_datetime
,(CASE WHEN condition_end_datetime > condition_start_datetime THEN CAST(condition_end_datetime AS text) ELSE CAST(condition_start_datetime AS text) END) as condition_end_date
,(CASE WHEN condition_end_datetime > condition_start_datetime THEN condition_end_datetime ELSE condition_start_datetime END) as condition_end_datetime
, condition_type_concept_id
, null as stop_reason
, CAST(null AS bigint) as provider_id
, visit_occurrence_id
, CAST(null AS bigint) as visit_detail_id
, condition_source_value
, coalesce(NULLIF(icd9_concept.concept_id,''),0) as condition_source_concept_id
, null as condition_status_source_value
, CAST(null AS bigint) as condition_status_concept_id
 FROM diag
LEFT JOIN icd9_concept USING (concept_code)
LEFT JOIN snomed_map ON (snomed_map.concept_id_1 = icd9_concept.concept_id)
LEFT JOIN gcpt_seq_num_to_concept_temp USING (seq_num)
LEFT JOIN admissions_temp USING (hadm_id)
LEFT JOIN patients_temp USING (subject_id)
UNION ALL
SELECT
  ROW_NUMBER() OVER (ORDER BY admissions_temp.visit_occurrence_id)+(SELECT mimic_id_seq FROM TEMP_SEQUENCES LIMIT 1) as condition_occurrence_id
, patients_temp.person_id AS person_id
, coalesce(NULLIF(adm_diag_cpt.concept_id,''), 0) AS condition_concept_id
,(CASE WHEN admissions_temp.condition_end_datetime > admissions_temp.condition_start_datetime THEN CAST(admissions_temp.condition_start_datetime AS text) ELSE CAST(admissions_temp.condition_end_datetime AS text) END) as condition_start_date
,(CASE WHEN admissions_temp.condition_end_datetime > admissions_temp.condition_start_datetime THEN admissions_temp.condition_start_datetime ELSE admissions_temp.condition_end_datetime END) as condition_start_datetime
,(CASE WHEN admissions_temp.condition_end_datetime > admissions_temp.condition_start_datetime THEN CAST(admissions_temp.condition_end_datetime AS text) ELSE CAST(admissions_temp.condition_start_datetime AS text) END) as condition_end_date
,(CASE WHEN admissions_temp.condition_end_datetime > admissions_temp.condition_start_datetime THEN admissions_temp.condition_end_datetime ELSE admissions_temp.condition_start_datetime END) as condition_end_datetime
, 42894222 AS condition_type_concept_id   --EHR Chief Complaint
, null AS stop_reason
, null AS provider_id
, admissions_temp.visit_occurrence_id AS visit_occurrence_id
, null AS visit_detail_id
, admissions_temp.diagnosis AS condition_source_value
, null AS condition_source_concept_id
, null AS condition_status_source_value
, null AS condition_status_concept_id
FROM admissions_temp
LEFT JOIN patients_temp ON (subject_id = hadm_subject_id)
LEFT JOIN adm_diag_cpt USING (diagnosis))
INSERT INTO OMOP.condition_occurrence
(
    condition_occurrence_id
  , person_id
  , condition_concept_id
  , condition_start_date
  , condition_start_datetime
  , condition_end_date
  , condition_end_datetime
  , condition_type_concept_id
  , stop_reason
  , provider_id
  , visit_occurrence_id
  , visit_detail_id
  , condition_source_value
  , condition_source_concept_id
  , condition_status_source_value
  , condition_status_concept_id
)
SELECT
  condition_occurrence_id
, person_id
, condition_concept_id
, condition_start_date
, condition_start_datetime
, condition_end_date
, condition_end_datetime
, condition_type_concept_id
, stop_reason
, provider_id
, visit_occurrence_id
, visit_detail_id
, condition_source_value
, condition_source_concept_id
, condition_status_source_value
, condition_status_concept_id
FROM row_to_insert
WHERE NULLIF(condition_type_concept_id,'') IS NOT NULL; -- NOTE: Some concept_ids are not presented in the loaded vocab
--To avoid a constraint error, it is important to select only mapped rows

--UPDATING THE mimic_id_seq SEQUENCE
UPDATE MIMIC.TEMP_SEQUENCES SET mimic_id_seq = (SELECT condition_occurrence_id FROM OMOP.condition_occurrence ORDER BY condition_occurrence_id DESC LIMIT 1);
COMMIT;