BEGIN;

SELECT "Observation period row count matches visit_occurrence (OMOP): ";
SELECT count(1) from omop.visit_occurrence;
SELECT "Observation period row count matches visit_occurrence (OMOP): ";
select count(1) from omop.observation_period;
ROLLBACK;