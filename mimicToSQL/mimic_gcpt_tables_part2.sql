BEGIN;
.mode csv

.import 'mimicToSQL/concept/datetimeevents_to_concept.csv' gcpt_datetimeevents_to_concept

UPDATE gcpt_datetimeevents_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_datetimeevents_to_concept ORDER BY mimic_id DESC LIMIT 1);

COMMIT;