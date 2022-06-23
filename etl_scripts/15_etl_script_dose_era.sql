-- prescriptions
BEGIN;
CREATE TEMP VIEW "drug_strength_temp" AS
	SELECT
  drug_concept_id
, ingredient_concept_id
, amount_value
, amount_unit_concept_id
, numerator_value
, numerator_unit_concept_id
, denominator_value
, denominator_unit_concept_id
, box_size
, valid_start_date
, valid_end_date
, invalid_reason
FROM OMOP.drug_strength
WHERE NULLIF(amount_value,'') is not null;

CREATE TEMP VIEW "prescription_written" as
	SELECT
  drug_exposure_id
, person_id
, drug_concept_id
, drug_exposure_start_date
, drug_exposure_start_datetime
, drug_exposure_end_date
, drug_exposure_end_datetime
, verbatim_end_date
, drug_type_concept_id
, stop_reason
, refills
, quantity
, days_supply
, sig
, route_concept_id
, lot_number
, provider_id
, visit_occurrence_id
, visit_detail_id
, drug_source_value
, drug_source_concept_id
, route_source_value
, dose_unit_source_value
FROM OMOP.drug_exposure
WHERE TRUE
AND drug_type_concept_id = 38000177   -- concept.concept_name = 'Prescription written'
AND dose_unit_source_value IN ('TAB', 'mg', 'g', 'dose', 'SUPP', 'TAB', 'LOZ', 'TROC')
AND NULLIF(quantity,'') IS NOT NULL;

CREATE TEMP VIEW "insert_dose_era_written" as 
	SELECT
ROW_NUMBER() OVER (ORDER BY drug_exposure.drug_exposure_id)+(SELECT mimic_id_seq FROM TEMP_SEQUENCES LIMIT 1) as dose_era_id
, person_id
, drug_exposure.drug_concept_id
, coalesce(NULLIF(drug_strength_temp.amount_unit_concept_id,''), 0) AS  unit_concept_id      -- some unit are null, that's odd
, case when dose_unit_source_value = 'mg' then CAST(quantity AS double precision)
       when dose_unit_source_value = 'g' then CAST(quantity AS double precision)
       when NULLIF(amount_value,'') is not null then quantity * amount_value
       when denominator_value is null then quantity * numerator_value
       else numerator_value / denominator_value * quantity end as dose_value
, drug_exposure_start_date             AS dose_era_start_date
, drug_exposure_end_date               AS dose_era_end_date     --we removed not null constraint
FROM prescription_written drug_exposure
INNER JOIN drug_strength_temp USING (drug_concept_id);

INSERT INTO OMOP.dose_era
SELECT
  dose_era_id         
, person_id           
, drug_concept_id     
, unit_concept_id     
, dose_value          
, dose_era_start_date 
, dose_era_end_date   
, 8512 as temporal_unit_concept_id --daily
, CAST(null AS numeric) temporal_value
from insert_dose_era_written;

--UPDATING THE mimic_id_seq SEQUENCE
UPDATE MIMIC.TEMP_SEQUENCES SET mimic_id_seq = (SELECT dose_era_id FROM insert_dose_era_written ORDER BY dose_era_id DESC LIMIT 1);

-- inputevents_mv and inputevents_cv
-- when the drug (in drug_exposure) is a dose of a specific active ingredient (mg, mg/h) we duplicate it here
-- when the drug (in drug_exposure) is a quantity of a specific active ingredient (ml, /h) we don't

CREATE TEMP VIEW "insert_dose_era_administration" as 
	SELECT
drug_exposure_id
, person_id
, drug_concept_id
, drug_exposure_start_date
, drug_exposure_start_datetime
, drug_exposure_end_date
, drug_exposure_end_datetime
, verbatim_end_date
, drug_type_concept_id
, stop_reason
, refills
, CAST(coalesce(NULLIF(quantity,''),quantity) AS NUMERIC) as quantity
, days_supply
, sig
, route_concept_id
, lot_number
, provider_id
, visit_occurrence_id
, visit_detail_id
, drug_source_value
, drug_source_concept_id
, route_source_value
, dose_unit_source_value
, quantity_source_value
, unit_concept_id
, temporal_unit_concept_id
FROM OMOP.drug_exposure
INNER JOIN 
	(SELECT label AS dose_unit_source_value, unit_concept_id, temporal_unit_concept_id 
	FROM  gcpt_unit_doseera_concept_id) --mEq, mEQ ...
	unit_driven USING (dose_unit_source_value)
WHERE TRUE
AND drug_type_concept_id = 38000180   -- concept.concept_name = 'Inpatient administration'
AND NULLIF(quantity,'') IS NOT NULL
AND drug_concept_id != 0;

INSERT OR IGNORE INTO OMOP.dose_era
SELECT
ROW_NUMBER() OVER (ORDER BY insert_dose_era_administration.drug_exposure_id)+(SELECT mimic_id_seq FROM TEMP_SEQUENCES LIMIT 1) as dose_era_id
, person_id           
, drug_concept_id     
, unit_concept_id     
, quantity AS dose_value
, drug_exposure_start_date             AS dose_era_start_date
, drug_exposure_end_date               AS dose_era_end_date     --we removed not null constraint
, temporal_unit_concept_id
, CAST(null AS numeric) temporal_value
from insert_dose_era_administration WHERE NULLIF(dose_value,'') IS NOT NULL;

--UPDATING THE mimic_id_seq SEQUENCE
UPDATE MIMIC.TEMP_SEQUENCES SET mimic_id_seq = (SELECT dose_era_id FROM dose_era ORDER BY dose_era_id DESC LIMIT 1);
COMMIT;