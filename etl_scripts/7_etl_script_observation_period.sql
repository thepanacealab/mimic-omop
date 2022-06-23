-- load observation_period from previously loaded visit_occurrence table
-- SHALL be run after visit_occurrence etl
BEGIN;

WITH
"insert_observation_period" as
(
SELECT
  ROW_NUMBER() OVER (ORDER BY visit_occurrence_id)+(SELECT mimic_id_seq FROM TEMP_SEQUENCES LIMIT 1) as observation_period_id
, person_id
, visit_start_date as observation_period_start_date
, visit_start_datetime as observation_period_start_datetime
, visit_end_date as observation_period_end_date
, visit_end_datetime as observation_period_end_datetime
, 44814724  as period_type_concept_id  --  Period covering healthcare encounters
FROM OMOP.visit_occurrence
)
INSERT INTO OMOP.observation_period
(
    observation_period_id
  , person_id
  , observation_period_start_date
  , observation_period_start_datetime
  , observation_period_end_date
  , observation_period_end_datetime
  , period_type_concept_id
)
SELECT
  observation_period_id
, person_id
, observation_period_start_date
, observation_period_start_datetime
, observation_period_end_date
, observation_period_end_datetime
, period_type_concept_id
FROM insert_observation_period;

--UPDATING THE mimic_id_seq SEQUENCE
UPDATE MIMIC.TEMP_SEQUENCES SET mimic_id_seq = (SELECT observation_period_id FROM OMOP.OBSERVATION_PERIOD ORDER BY observation_period_id DESC LIMIT 1);

COMMIT;