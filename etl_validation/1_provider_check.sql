BEGIN;
SELECT "Provider - Check caregivers/providers match (OMOP):";
SELECT count(*) from omop.provider;
SELECT "Provider - Check caregivers/providers match (MIMIC):";
SELECT count(*) from caregivers;
ROLLBACK;