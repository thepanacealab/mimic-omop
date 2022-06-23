BEGIN;
SELECT load_extension('/data/student_work/luis_work/mimicIII/re');
-- from drug_exposure
-- mapping is 85% done from gsn coding
CREATE TEMP VIEW "de_pr" AS
	SELECT
	 'drug:['|| coalesce(NULLIF(drug,''), NULLIF(drug_name_poe,''), NULLIF(drug_name_generic,''),'') ||']'||  'prod_strength:['||coalesce(NULLIF(prod_strength,''),'')||']'|| 'drug_type:['||coalesce(NULLIF(drug_type,''),'')||']'|| 'formulary_drug_cd:['||coalesce(NULLIF(formulary_drug_cd,''),'') || ']' || 'dose_unit_rx:[' || coalesce(NULLIF(dose_unit_rx,''),'') || ']' as concept_name
	, subject_id
	, hadm_id
	, dose_val_rx
	, prescriptions.mimic_id as drug_exposure_id
	, startdate as drug_exposure_start_datetime
	, enddate as drug_exposure_end_datetime
	, coalesce(NULLIF(c2.concept_id,''), NULLIF(c3.concept_id,'')) as drug_concept_id
	, gcpt_route_to_concept.concept_id as route_concept_id
	, route as route_source_value --TODO: add route as local concept
	, form_unit_disp as dose_unit_source_value --TODO: add unit as local concept
	, ndc as drug_source_value -- ndc was used for automatic/manual mapping
	, form_val_disp
	FROM prescriptions
	LEFT join OMOP.concept ctemp on ctemp.domain_id = 'Drug' and ctemp.concept_code = CAST(ndc AS text) --this covers 85% of direct mapping but no standard
	LEFT join OMOP.concept_relationship crtemp on ctemp.concept_id = crtemp.concept_id_1 and crtemp.relationship_id = 'Maps to'
	LEFT join OMOP.concept c2 on c2.concept_id = concept_id_2 and c2.standard_concept = 'S' --covers 71% of rxnorm standards concepts
	LEFT JOIN gcpt_route_to_concept using (route)
	LEFT JOIN gcpt_prescriptions_ndcisnullzero_to_concept as c3 ON coalesce(NULLIF(drug,''), NULLIF(drug_name_poe,''), NULLIF(drug_name_generic,''),'') || ' ' || coalesce(NULLIF(prod_strength,''), '') = c3.label -- this improve to 85% mapping and save most of ndc = 0
;

CREATE TEMP VIEW "de_patients_temp" AS SELECT subject_id, mimic_id as person_id from patients;
CREATE TEMP VIEW "de_admissions_temp" AS SELECT hadm_id, mimic_id as visit_occurrence_id FROM admissions;
CREATE TEMP VIEW "de_omop_local_drug" AS SELECT concept_name as drug_source_value, concept_id as drug_source_concept_id FROM OMOP.concept WHERE domain_id = 'prescriptions' AND vocabulary_id = 'MIMIC prescriptions';
CREATE TEMP VIEW "de_row_to_insert_1" AS 
	SELECT
  drug_exposure_id
, person_id
, coalesce(NULLIF(drug_concept_id,''), 0) as drug_concept_id
, CAST(drug_exposure_start_datetime AS text) as drug_exposure_start_date
, (drug_exposure_start_datetime) AS drug_exposure_start_datetime
, CAST(drug_exposure_end_datetime AS text) as drug_exposure_end_date
, (drug_exposure_end_datetime) AS drug_exposure_end_datetime
, CAST(null AS text) as verbatim_end_date
, 38000177 as drug_type_concept_id
, CAST(null AS text) as stop_reason
, CAST(null AS integer) as refills
--NOTE: replaced from extract_value_period_decimal function
, CAST(regexp_substr(replace(replace(form_val_disp,',',''),' ',''),'[+-]?[0-9]*[.][0-9]+|[+-]?[0-9]+') AS DECIMAL)  as quantity --extract quantity from pure numeric when possible
, CAST(null AS integer) as days_supply
, CAST(null AS text)  as sig
, route_concept_id
, CAST(null AS text) as lot_number
, CAST(null AS integer) as provider_id
, visit_occurrence_id
, CAST(null AS integer) as visit_detail_id
, drug_source_value
, drug_source_concept_id
, route_source_value
, dose_unit_source_value
, form_val_disp as quantity_source_value
FROM de_pr
LEFT JOIN de_omop_local_drug USING(drug_source_value)
LEFT JOIN de_patients_temp USING (subject_id)
LEFT JOIN de_admissions_temp USING (hadm_id);

INSERT INTO OMOP.drug_exposure
(
		drug_exposure_id
	,	person_id
	,	drug_concept_id
	,	drug_exposure_start_date
	,	drug_exposure_start_datetime
	,	drug_exposure_end_date
	,	drug_exposure_end_datetime
	,	verbatim_end_date
	,	drug_type_concept_id
	,	stop_reason
	,	refills
	,	quantity
	,	days_supply
	,	sig
	,	route_concept_id
	,	lot_number
	,	provider_id
	,	visit_occurrence_id
	,	visit_detail_id
	,	drug_source_value
	,	drug_source_concept_id
	,	route_source_value
	,	dose_unit_source_value
	,	quantity_source_value
)
SELECT
  de_row_to_insert_1.drug_exposure_id
, de_row_to_insert_1.person_id
, de_row_to_insert_1.drug_concept_id
, de_row_to_insert_1.drug_exposure_start_date
, de_row_to_insert_1.drug_exposure_start_datetime
, de_row_to_insert_1.drug_exposure_end_date
, de_row_to_insert_1.drug_exposure_end_datetime
, de_row_to_insert_1.verbatim_end_date
, de_row_to_insert_1.drug_type_concept_id
, de_row_to_insert_1.stop_reason
, de_row_to_insert_1.refills
, de_row_to_insert_1.quantity
, de_row_to_insert_1.days_supply
, de_row_to_insert_1.sig
, de_row_to_insert_1.route_concept_id
, de_row_to_insert_1.lot_number
, de_row_to_insert_1.provider_id
, de_row_to_insert_1.visit_occurrence_id
, de_row_to_insert_1.visit_detail_id
, de_row_to_insert_1.drug_source_value
, de_row_to_insert_1.drug_source_concept_id
, de_row_to_insert_1.route_source_value
, de_row_to_insert_1.dose_unit_source_value
, de_row_to_insert_1.quantity_source_value
FROM de_row_to_insert_1;

-- MEASUREMENT / inputevent
-- ajouter champs unit_concept_id
-- type =  38000180 -- Inpatient administration
-- route = 4112421 -- intravenous ()

-- inputevent_mv
-- route_concept_source = ordercategorydescription (ordercategoryname)
-- -> CREER les deux concepts
-- cgid provider
-- privilegie rate
-- stop reason: statusdescription
-- quality_concept_id : when 1 then cancel else ok. --> infered from data.
-- when orderid then fact_relationship with 44818791 -- Has temporal context [SNOMED]
-- weight into observation/measurement
CREATE TEMP VIEW "de_imv" AS
SELECT
  mimic_id AS drug_exposure_id
, subject_id
, hadm_id
, itemid
, cgid
, starttime as drug_exposure_start_datetime
, endtime as drug_exposure_end_datetime
, CASE WHEN NULLIF(rate,'') IS NOT NULL THEN rate WHEN NULLIF(amount,'') IS NOT NULL THEN amount ELSE NULL END AS quantity
, CASE WHEN NULLIF(rate,'') IS NOT NULL THEN rateuom WHEN NULLIF(amount,'') IS NOT NULL THEN amountuom ELSE NULL END AS dose_unit_source_value
, 38000180 AS drug_type_concept_id -- Inpatient administration
--, 4112421 as route_concept_id -- intraveous
, orderid = linkorderid as is_leader -- other input are linked to it/them
, first_value(mimic_id) over(partition by orderid order by starttime ASC) = mimic_id as is_orderid_leader -- other input are linked to it/them
, linkorderid
, orderid
, ordercategorydescription || ' (' || ordercategoryname || ')' AS route_source_value
, statusdescription as stop_reason
, ordercategoryname
, cancelreason
FROM inputevents_mv
WHERE cancelreason = 0;

--"rxnorm_map" AS (SELECT distinct on (drug_source_value) concept_id as drug_concept_id, drug_source_value FROM mimic.gcpt_gdata_drug_exposure LEFT JOIN OMOP.concept ON drug_concept_id::text = concept_code AND domain_id = 'Drug' WHERE drug_concept_id IS NOT NULL),
CREATE TEMP VIEW "de_rxnorm_map" AS -- exploit the mapping based on ndc
select distinct drug_concept_id, concept_name as drug_source_value from OMOP.drug_exposure left join OMOP.concept on drug_concept_id = concept_id where drug_concept_id != 0;

CREATE TEMP VIEW "de_patients_temp2" AS SELECT mimic_id AS person_id, subject_id FROM patients;
CREATE TEMP VIEW "de_admissions_temp2" AS SELECT mimic_id AS visit_occurrence_id, hadm_id FROM admissions;
CREATE TEMP VIEW "de_gcpt_inputevents_drug_to_concept_temp2" AS SELECT itemid, concept_id as drug_concept_id FROM gcpt_inputevents_drug_to_concept;
CREATE TEMP VIEW "de_gcpt_mv_input_label_to_concept_temp2" AS SELECT DISTINCT item_id as itemid, concept_id as drug_concept_id FROM gcpt_mv_input_label_to_concept;
CREATE TEMP VIEW "de_gcpt_map_route_to_concept_temp2" AS SELECT concept_id as route_concept_id, ordercategoryname FROM gcpt_map_route_to_concept;
CREATE TEMP VIEW "de_caregivers_temp2" AS SELECT mimic_id AS provider_id, cgid FROM caregivers;
CREATE TEMP VIEW "de_d_items_temp2" AS SELECT itemid, label as drug_source_value, mimic_id as drug_source_concept_id FROM d_items;

INSERT INTO OMOP.fact_relationship
(
  domain_concept_id_1
, fact_id_1
, domain_concept_id_2
, fact_id_2
, relationship_concept_id

)
SELECT
DISTINCT
  13 As fact_id_1 --Drug
, mv2.drug_exposure_id AS domain_concept_id_1
, 13 As fact_id_2 --Drug
, mv1.drug_exposure_id AS domain_concept_id_2
, 44818791 AS relationship_concept_id -- Has temporal context [SNOMED]
FROM de_imv mv1
LEFT JOIN de_imv mv2 ON (mv2.orderid = mv1.linkorderid AND mv2.is_leader IS TRUE);

INSERT INTO OMOP.fact_relationship
(
  domain_concept_id_1
, fact_id_1
, domain_concept_id_2
, fact_id_2
, relationship_concept_id
)
SELECT
DISTINCT
  13 As fact_id_1 --Drug
, mv2.drug_exposure_id AS domain_concept_id_1
, 13 As fact_id_2 --Drug
, mv1.drug_exposure_id AS domain_concept_id_2
, 44818784 AS relationship_concept_id -- Has associated procedure [SNOMED]
FROM de_imv mv1
LEFT JOIN de_imv mv2 ON (mv2.orderid = mv1.orderid AND mv2.is_orderid_leader IS TRUE);

CREATE TEMP VIEW "de_row_to_insert_2" AS
SELECT
  drug_exposure_id
, person_id
, coalesce(NULLIF(de_rxnorm_map.drug_concept_id,''), de_gcpt_inputevents_drug_to_concept_temp2.drug_concept_id, de_gcpt_mv_input_label_to_concept_temp2.drug_concept_id, 0) AS drug_concept_id
, CAST(drug_exposure_start_datetime AS text) AS drug_exposure_start_date
, drug_exposure_start_datetime
, CAST(drug_exposure_end_datetime AS text) AS drug_exposure_end_date
, drug_exposure_end_datetime
, CAST(null AS text) as verbatim_end_date
, drug_type_concept_id
, stop_reason
, CAST(null AS integer) as refills
, quantity
, CAST(null AS integer) as days_supply
, CAST(null AS text) as sig
, coalesce(NULLIF(route_concept_id,''), 0) as route_concept_id
, CAST(null AS integer) as lot_number
, provider_id
, visit_occurrence_id
, CAST(null AS integer) AS visit_detail_id
, drug_source_value
, drug_source_concept_id
, route_source_value
, dose_unit_source_value
FROM de_imv
LEFT JOIN de_patients_temp2 USING (subject_id)
LEFT JOIN de_admissions_temp2 USING (hadm_id)
LEFT JOIN de_caregivers_temp2 USING (cgid)
LEFT JOIN de_gcpt_inputevents_drug_to_concept_temp2 USING (itemid)
LEFT JOIN de_gcpt_mv_input_label_to_concept_temp2 USING (itemid)
LEFT JOIN de_gcpt_map_route_to_concept_temp2 USING (ordercategoryname)
LEFT JOIN de_d_items_temp2 USING (itemid)
LEFT JOIN de_rxnorm_map USING (drug_source_value);

INSERT INTO OMOP.drug_exposure
(
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
	, quantity_source_value
)
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
, de_row_to_insert_2.visit_occurrence_id
, visit_detail_assign.visit_detail_id
, drug_source_value
, drug_source_concept_id
, route_source_value
, dose_unit_source_value
, CAST(quantity AS text) as quantity_source_value
FROM de_row_to_insert_2
LEFT JOIN OMOP.visit_detail_assign
ON de_row_to_insert_2.visit_occurrence_id = visit_detail_assign.visit_occurrence_id
AND
(--only one visit_detail
(is_first IS TRUE AND is_last IS TRUE)
OR -- first
(is_first IS TRUE AND is_last IS FALSE AND de_row_to_insert_2.drug_exposure_start_datetime <= visit_detail_assign.visit_end_datetime)
OR -- last
(is_last IS TRUE AND is_first IS FALSE AND de_row_to_insert_2.drug_exposure_start_datetime > visit_detail_assign.visit_start_datetime)
OR -- middle
(is_last IS FALSE AND is_first IS FALSE AND de_row_to_insert_2.drug_exposure_start_datetime > visit_detail_assign.visit_start_datetime AND de_row_to_insert_2.drug_exposure_start_datetime <= visit_detail_assign.visit_end_datetime)
) GROUP BY drug_exposure_id;

-- inputevent_cv
-- when rate chattime -> start
-- when amount charttime  -> end
-- stopped as is -> stop_reason
-- concept_id gcpt_inputevents_drug_to_concept, gcpt_mv_input_label_to_concept, gcpt_cv_input_label_to_concept
-- route = NULL  (!= originalroute, original* never considered)
CREATE TEMP VIEW "de_icv" AS
SELECT
  mimic_id AS drug_exposure_id
, subject_id
, hadm_id
, cgid
, itemid
 --when rate then start date, when amount then end date (from mimic docuemntaiton)
, CASE WHEN NULLIF(rate,'') IS NOT NULL THEN charttime WHEN  amount IS NULL THEN charttime END as drug_exposure_start_datetime
, CASE WHEN NULLIF(rate,'') IS NULL AND NULLIF(amount,'') IS NOT NULL THEN charttime ELSE NULL END as drug_exposure_end_datetime
, CASE WHEN NULLIF(rate,'') IS NOT NULL THEN rate WHEN NULLIF(amount,'') IS NOT NULL THEN amount ELSE NULL END as quantity
, CASE WHEN NULLIF(rate,'') IS NOT NULL THEN rateuom WHEN NULLIF(amount,'') IS NOT NULL THEN amountuom ELSE NULL END as dose_unit_source_value
, 38000180 AS drug_type_concept_id -- Inpatient administration
--, 4112421 as route_concept_id -- intraveous
, orderid = linkorderid as is_leader -- other input are linked to it/them
, orderid
, linkorderid
, originalroute
, stopped as stop_reason
FROM inputevents_cv;

CREATE TEMP VIEW "de_patients_temp3" AS SELECT mimic_id AS person_id, subject_id FROM patients;
CREATE TEMP VIEW "de_admissions_temp3" AS SELECT mimic_id AS visit_occurrence_id, hadm_id FROM admissions;
--"rxnorm_map" AS (SELECT DISTINCT ON (drug_source_value) concept_id as drug_concept_id, drug_source_value FROM .gcpt_gdata_drug_exposure LEFT JOIN OMOP.concept ON drug_concept_id::text = concept_code AND domain_id = 'Drug' WHERE drug_concept_id IS NOT NULL),
CREATE TEMP VIEW "de_rxnorm_map_2" AS -- exploit the mapping based on ndc
select distinct drug_concept_id, concept_name as drug_source_value from OMOP.drug_exposure left join OMOP.concept on drug_concept_id = concept_id where drug_concept_id != 0;
CREATE TEMP VIEW "de_gcpt_inputevents_drug_to_concept_temp3" AS SELECT itemid, concept_id as drug_concept_id FROM gcpt_inputevents_drug_to_concept;
CREATE TEMP VIEW "de_gcpt_cv_input_label_to_concept_temp3" AS SELECT DISTINCT item_id as itemid, concept_id as drug_concept_id FROM gcpt_mv_input_label_to_concept;
CREATE TEMP VIEW "de_caregivers_temp3" AS SELECT mimic_id AS provider_id, cgid FROM caregivers;
CREATE TEMP VIEW "de_gcpt_map_route_to_concept_temp3" AS SELECT concept_id as route_concept_id, ordercategoryname as originalroute FROM gcpt_map_route_to_concept;
CREATE TEMP VIEW "de_d_items_temp3" AS SELECT itemid, label as drug_source_value, mimic_id as drug_source_concept_id FROM d_items;
CREATE TEMP VIEW "de_gcpt_continuous_unit_carevue" as
	select dose_unit_source_value, dose_unit_source_value_new
 from gcpt_continuous_unit_carevue;

INSERT INTO OMOP.fact_relationship
(
  domain_concept_id_1
, fact_id_1
, domain_concept_id_2
, fact_id_2
, relationship_concept_id
)
SELECT
DISTINCT
  13 As fact_id_1 --Drug
, cv2.drug_exposure_id AS domain_concept_id_1
, 13 As fact_id_2 --Drug
, cv1.drug_exposure_id AS domain_concept_id_2
, 44818791 AS relationship_concept_id -- Has temporal context [SNOMED]
FROM de_icv cv1
LEFT JOIN de_icv cv2 ON (cv2.orderid = cv1.linkorderid AND cv2.is_leader IS TRUE)
WHERE NULLIF(cv2.drug_exposure_id,'') IS NOT NULL;
--RETURNING *;

CREATE TEMP VIEW "de_row_to_insert_3" AS
SELECT
  drug_exposure_id
, person_id
, coalesce(NULLIF(de_rxnorm_map_2.drug_concept_id,''), NULLIF(de_gcpt_inputevents_drug_to_concept_temp3.drug_concept_id,''), NULLIF(de_gcpt_cv_input_label_to_concept_temp3.drug_concept_id,''), 0) AS drug_concept_id
, CAST(drug_exposure_start_datetime AS text) AS drug_exposure_start_date
, drug_exposure_start_datetime
, CAST(drug_exposure_end_datetime AS text) AS drug_exposure_end_date
, drug_exposure_end_datetime
, CAST(null AS text) as verbatim_end_date
, drug_type_concept_id
, stop_reason
, CAST(null AS integer) as refills
, quantity
, CAST(null AS integer) as days_supply
, CAST(null AS text) as sig
, coalesce(NULLIF(route_concept_id,''),0) as route_concept_id
, CAST(null AS integer) as lot_number
, provider_id
, visit_occurrence_id
, CAST(null AS integer) AS visit_detail_id
, drug_source_value
, drug_source_concept_id
, CAST(null AS text) route_source_value
, coalesce(NULLIF(de_gcpt_continuous_unit_carevue.dose_unit_source_value_new,''), NULLIF(dose_unit_source_value,'')) as dose_unit_source_value
FROM de_icv
LEFT JOIN de_patients_temp3 USING (subject_id)
LEFT JOIN de_admissions_temp3 USING (hadm_id)
LEFT JOIN de_caregivers_temp3 USING (cgid)
LEFT JOIN de_gcpt_inputevents_drug_to_concept_temp3 USING (itemid)
LEFT JOIN de_gcpt_cv_input_label_to_concept_temp3 USING (itemid)
LEFT JOIN de_d_items_temp3 USING (itemid)
LEFT JOIN de_rxnorm_map_2 USING (drug_source_value)
LEFT JOIN de_gcpt_map_route_to_concept_temp3 USING (originalroute)
LEFT JOIN de_gcpt_continuous_unit_carevue USING (dose_unit_source_value);


INSERT INTO OMOP.drug_exposure
(
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
	, quantity_source_value
)
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
, de_row_to_insert_3.visit_occurrence_id
, visit_detail_assign.visit_detail_id
, drug_source_value
, drug_source_concept_id
, route_source_value
, dose_unit_source_value
, CAST(quantity AS text) as quantity_source_value
FROM de_row_to_insert_3
LEFT JOIN OMOP.visit_detail_assign
ON de_row_to_insert_3.visit_occurrence_id = visit_detail_assign.visit_occurrence_id
AND
(--only one visit_detail
(is_first IS TRUE AND is_last IS TRUE)
OR -- first
(is_first IS TRUE AND is_last IS FALSE AND de_row_to_insert_3.drug_exposure_start_datetime <= visit_detail_assign.visit_end_datetime)
OR -- last
(is_last IS TRUE AND is_first IS FALSE AND de_row_to_insert_3.drug_exposure_start_datetime > visit_detail_assign.visit_start_datetime)
OR -- middle
(is_last IS FALSE AND is_first IS FALSE AND de_row_to_insert_3.drug_exposure_start_datetime > visit_detail_assign.visit_start_datetime AND de_row_to_insert_3.drug_exposure_start_datetime <= visit_detail_assign.visit_end_datetime)
) GROUP BY drug_exposure_id;
COMMIT;