BEGIN;

CREATE TEMP VIEW "noteevents_temp" AS
SELECT
  mimic_id as note_id
, cgid
, subject_id
, hadm_id
, chartdate as note_date
, charttime as note_datetime
, description as note_title
, text as note_text
, category as note_source_value
FROM noteevents
WHERE NULLIF(iserror,'') IS NULL;
-- NOTE IS NULL is not working to compare empty cells

CREATE TEMP VIEW "gcpt_note_category_to_concept_temp" AS SELECT category as note_source_value, concept_id as note_type_concept_id FROM gcpt_note_category_to_concept;
CREATE TEMP VIEW "admissions_temp" AS SELECT hadm_id, mimic_id as visit_occurrence_id FROM admissions;
CREATE TEMP VIEW "patients_temp" AS SELECT subject_id, mimic_id as person_id FROM patients;
CREATE TEMP VIEW "caregivers_temp" AS SELECT mimic_id AS provider_id, cgid FROM caregivers;

CREATE TEMP VIEW "row_to_insert" AS
SELECT
  note_id
, person_id
, note_date
, note_datetime as note_datetime
, coalesce(NULLIF(gcpt_note_category_to_concept_temp.note_type_concept_id,''),0) AS  note_type_concept_id
, 0 AS note_class_concept_id -- TODO/ not yet mapped to CDO
, note_title
, note_text
, 0 AS encoding_concept_id
, 40639385 as language_concept_id -- English (from metadata, maybe not the best)
, provider_id
, visit_occurrence_id
, noteevents_temp.note_source_value AS note_source_value
, CAST(NULL AS integer) visit_detail_id
FROM noteevents_temp
LEFT JOIN gcpt_note_category_to_concept_temp ON trim(LOWER(noteevents_temp.note_source_value)) = trim(LOWER(gcpt_note_category_to_concept_temp.note_source_value))
LEFT JOIN patients_temp USING (subject_id)
LEFT JOIN admissions_temp USING (hadm_id)
LEFT JOIN caregivers_temp USING (cgid);

INSERT INTO OMOP.NOTE
(
    note_id
  , person_id
  , note_date
  , note_datetime
  , note_type_concept_id
  , note_class_concept_id
  , note_title
  , note_text
  , encoding_concept_id
  , language_concept_id
  , provider_id
  , visit_occurrence_id
  , note_source_value
  , visit_detail_id
)
SELECT
  note_id
, person_id
, note_date
, note_datetime
, note_type_concept_id
, note_class_concept_id
, note_title
, note_text
, encoding_concept_id
, language_concept_id
, provider_id
, visit_occurrence_id
, note_source_value
, visit_detail_id
FROM row_to_insert;

COMMIT;