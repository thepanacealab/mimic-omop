BEGIN;

SELECT "Number of unique patients who die in the database (MIMIC): ";
SELECT count(dod) FROM patients WHERE NULLIF(dod,'') IS NOT NULL;
SELECT "Number of unique patients who die in the database (OMOP): ";
SELECT count(death_date) FROM omop.death WHERE NULLIF(death_date,'') IS NOT NULL;

ROLLBACK;