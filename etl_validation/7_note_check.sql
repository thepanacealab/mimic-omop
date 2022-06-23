BEGIN;
SELECT "Visit occurrence NB (OMOP):";
SELECT count(distinct person_id), count(distinct visit_occurrence_id) FROM omop.note
WHERE NULLIF(visit_occurrence_id,'') IS NOT NULL;
SELECT "Visit occurrence NB (MIMIC):";
SELECT count(distinct subject_id), count(distinct hadm_id) FROM noteevents WHERE NULLIF(hadm_id,'') IS NOT NULL;
SELECT "=======================================================";

SELECT "Check radio NB (OMOP):";
SELECT count(1) from omop.note where note_type_concept_id = 44814641;
SELECT "Check radio NB (MIMIC):";
SELECT count(1) from noteevents where category = 'Radiology';

ROLLBACK;