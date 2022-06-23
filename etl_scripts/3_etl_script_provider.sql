BEGIN;

WITH caregivers_temp AS (SELECT mimic_id as provider_id, label as provider_source_value, description as specialty_source_value FROM MIMIC.caregivers)
INSERT INTO OMOP.PROVIDER
(
  provider_id
 , provider_source_value
 , specialty_source_value
)
SELECT caregivers_temp.provider_id, caregivers_temp.provider_source_value, caregivers_temp.specialty_source_value
FROM caregivers_temp;

COMMIT;