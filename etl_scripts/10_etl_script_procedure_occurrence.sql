BEGIN;

CREATE TEMP VIEW "po_proc_icd_temp" as SELECT mimic_id as procedure_occurrence_id, subject_id, hadm_id, icd9_code as procedure_source_value, CASE WHEN length(cast(ICD9_CODE as text)) = 2 THEN cast(ICD9_CODE as text) ELSE substr(cast(ICD9_CODE as text), 1, 2) || '.' || substr(cast(ICD9_CODE as text), 3) END AS concept_code FROM procedures_icd;
CREATE TEMP VIEW "po_local_proc_icd_temp" AS SELECT concept_id as procedure_source_concept_id, concept_code as procedure_source_value FROM OMOP.concept WHERE domain_id = 'd_icd_procedures' AND vocabulary_id = 'MIMIC Local Codes';
CREATE TEMP VIEW "po_concept_proc_icd9_temp" as SELECT concept_id as procedure_concept_id, concept_code FROM OMOP.concept WHERE vocabulary_id = 'ICD9Proc';
CREATE TEMP VIEW "po_patients_temp" AS SELECT subject_id, mimic_id as person_id FROM patients;
CREATE TEMP VIEW "po_caregivers_temp" AS SELECT mimic_id AS provider_id, cgid FROM caregivers;
CREATE TEMP VIEW "po_admissions_temp" AS SELECT hadm_id, admittime, dischtime as procedure_datetime, mimic_id as visit_occurrence_id FROM admissions;
CREATE TEMP VIEW "po_proc_event" as 
   SELECT d_items.mimic_id AS procedure_source_concept_id
        , procedureevents_mv.mimic_id as procedure_occurrence_id
        , subject_id
        , cgid
        , hadm_id
        , itemid
        , starttime as procedure_datetime
        , label as procedure_source_value
        , value as quantity -- then it stores the duration... this is a warkaround and may be inproved
     FROM procedureevents_mv
     LEFT JOIN d_items USING (itemid)
     where cancelreason = 0; -- not cancelled

CREATE TEMP VIEW "po_gcpt_procedure_to_concept_temp" as SELECT item_id as itemid, concept_id as procedure_concept_id from gcpt_procedure_to_concept;
CREATE TEMP VIEW "po_cpt_event" AS SELECT mimic_id as procedure_occurrence_id , subject_id , hadm_id , chartdate as procedure_datetime, cpt_cd, subsectionheader as procedure_source_value FROM cptevents;
CREATE TEMP VIEW "po_omop_cpt4" AS SELECT concept_id as procedure_source_concept_id, concept_code as cpt_cd FROM OMOP.concept where vocabulary_id = 'CPT4';
CREATE TEMP VIEW "po_standard_cpt4" AS
	select distinct c1.concept_id, first_value(c2.concept_id) over(partition by c1.concept_id order by relationship_id ASC) as procedure_concept_id, c1.concept_code as cpt_cd --keep snomed in predilection
	from OMOP.concept c1
	join OMOP.concept_relationship cr on concept_id_1 = c1.concept_id and relationship_id IN ('CPT4 - SNOMED eq','Maps to')
	left join OMOP.concept c2 on concept_id_2 = c2.concept_id
	WHERE
	    c1.vocabulary_id ='CPT4'
	and c2.standard_concept = 'S';

CREATE TEMP VIEW "po_row_to_insert_part1" AS
SELECT
procedure_occurrence_id
, po_patients_temp.person_id
, coalesce(NULLIF(po_standard_cpt4.procedure_concept_id,''),0) as procedure_concept_id
, CAST(coalesce(NULLIF(po_cpt_event.procedure_datetime,''), po_admissions_temp.admittime) AS text) as procedure_date
, coalesce(NULLIF(po_cpt_event.procedure_datetime,''), po_admissions_temp.admittime) as procedure_datetime
, 257 as procedure_type_concept_id -- Hospitalization Cost Record
, CAST(null AS integer) as modifier_concept_id
, CAST(null AS integer) as quantity
, CAST(null AS integer) as provider_id
, po_admissions_temp.visit_occurrence_id
, CAST(null AS integer) as visit_detail_id -- the chartdate is never a time, when exist
, po_cpt_event.procedure_source_value
, po_omop_cpt4.procedure_source_concept_id as procedure_source_concept_id
, CAST(null AS text) as modifier_source_value
FROM po_cpt_event
LEFT JOIN po_patients_temp USING (subject_id)
LEFT JOIN po_admissions_temp USING (hadm_id)
LEFT JOIN po_omop_cpt4 USING (cpt_cd)
LEFT JOIN po_standard_cpt4 USING (cpt_cd);

CREATE TEMP VIEW "po_row_to_insert_part2" AS 
SELECT
  procedure_occurrence_id
, po_patients_temp.person_id
, coalesce(NULLIF(po_gcpt_procedure_to_concept_temp.procedure_concept_id,''),0) as procedure_concept_id
, CAST(po_proc_event.procedure_datetime AS text) as procedure_date
, (po_proc_event.procedure_datetime) as procedure_datetime
, 38000275 as procedure_type_concept_id -- EHR order list entry
, null as modifier_concept_id
, quantity as quantity --duration of the procedure in minutes
, po_caregivers_temp.provider_id as provider_id
, po_admissions_temp.visit_occurrence_id
, visit_detail_assign.visit_detail_id as visit_detail_id
, procedure_source_value
, procedure_source_concept_id -- from d_items mimic_id
, null as modifier_source_value
FROM po_proc_event
LEFT JOIN po_patients_temp USING (subject_id)
LEFT JOIN po_admissions_temp USING (hadm_id)
LEFT JOIN po_caregivers_temp USING (cgid)
LEFT JOIN po_gcpt_procedure_to_concept_temp USING (itemid)
LEFT JOIN OMOP.visit_detail_assign ON po_admissions_temp.visit_occurrence_id = visit_detail_assign.visit_occurrence_id
AND
(--only one visit_detail
(is_first IS TRUE AND is_last IS TRUE)
OR -- first
(is_first IS TRUE AND is_last IS FALSE AND po_proc_event.procedure_datetime <= visit_detail_assign.visit_end_datetime)
OR -- last
(is_last IS TRUE AND is_first IS FALSE AND po_proc_event.procedure_datetime > visit_detail_assign.visit_start_datetime)
OR -- middle
(is_last IS FALSE AND is_first IS FALSE AND po_proc_event.procedure_datetime > visit_detail_assign.visit_start_datetime AND po_proc_event.procedure_datetime <= visit_detail_assign.visit_end_datetime)
) GROUP BY procedure_occurrence_id, visit_detail_assign.visit_start_datetime, visit_detail_assign.visit_end_datetime;

CREATE TEMP VIEW "po_row_to_insert_part3" AS
SELECT
  procedure_occurrence_id
, po_patients_temp.person_id
, coalesce(NULLIF(po_concept_proc_icd9_temp.procedure_concept_id,''),0) as procedure_concept_id
, CAST(po_admissions_temp.procedure_datetime AS text) as procedure_date
, (po_admissions_temp.procedure_datetime) AS procedure_datetime
, 38003622 as procedure_type_concept_id
, null as modifier_concept_id
, null as quantity
, null as provider_id
, po_admissions_temp.visit_occurrence_id
, null as visit_detail_id
, po_proc_icd_temp.procedure_source_value
, coalesce(procedure_source_concept_id,0) as procedure_source_concept_id
, null as modifier_source_value
FROM po_proc_icd_temp
LEFT JOIN po_local_proc_icd_temp USING (procedure_source_value)
LEFT JOIN po_patients_temp USING (subject_id)
LEFT JOIN po_admissions_temp USING (hadm_id)
LEFT JOIN po_concept_proc_icd9_temp USING (concept_code);

CREATE TEMP VIEW "po_row_to_insert" AS
SELECT * FROM
  po_row_to_insert_part1
UNION ALL
SELECT * FROM
  po_row_to_insert_part2
UNION ALL
SELECT * FROM
  po_row_to_insert_part3;

INSERT INTO OMOP.procedure_occurrence
(
    procedure_occurrence_id
  , person_id
  , procedure_concept_id
  , procedure_date
  , procedure_datetime
  , procedure_type_concept_id
  , modifier_concept_id
  , quantity
  , provider_id
  , visit_occurrence_id
  , visit_detail_id
  , procedure_source_value
  , procedure_source_concept_id
  , modifier_source_value
)
SELECT
  procedure_occurrence_id
, person_id
, procedure_concept_id
, procedure_date
, procedure_datetime
, procedure_type_concept_id
, modifier_concept_id
, quantity
, provider_id
, visit_occurrence_id
, visit_detail_id
, procedure_source_value
, procedure_source_concept_id
, modifier_source_value
FROM po_row_to_insert;


 -- from datetimeevents
CREATE TEMP VIEW "po_datetimeevents_temp" AS 
SELECT subject_id, hadm_id, itemid, cgid, mimic_id as observation_id, CAST(coalesce(value,charttime) AS text) as observation_date, value as observation_datetime FROM datetimeevents where NULLIF(error,'') is null or error = 0;

CREATE TEMP VIEW "po_gcpt_datetimeevents_to_concept_temp" AS SELECT label as value_as_string, observation_concept_id, itemid, observation_source_concept_id from gcpt_datetimeevents_to_concept;

CREATE TEMP VIEW "po_patients_temp2" AS SELECT subject_id, mimic_id as person_id FROM patients;

CREATE TEMP VIEW "po_caregivers_temp2" AS SELECT cgid, mimic_id as provider_id FROM caregivers;

CREATE TEMP VIEW "po_admissions_temp2" AS SELECT subject_id, hadm_id, mimic_id as visit_occurrence_id, insurance, marital_status, language, diagnosis, religion, ethnicity, admittime FROM admissions;

CREATE TEMP VIEW "po_row_to_insert_2" AS
SELECT
        po_datetimeevents_temp.observation_id
      , po_patients_temp2.person_id
      , gcpt.observation_concept_id
      , po_datetimeevents_temp.observation_date
      , (po_datetimeevents_temp.observation_datetime) as observation_datetime
      , 38000280 as observation_type_concept_id -- Observation recorded from EHR
      , CAST(null AS double precision) as value_as_number
      , gcpt.value_as_string as value_as_string
      , CAST(null AS bigint) as value_as_concept_id
      , CAST(null AS bigint) as qualifier_concept_id
      , CAST(null AS bigint) as unit_concept_id
      , po_caregivers_temp2.provider_id
      , po_admissions_temp2.visit_occurrence_id
      , CAST(null AS bigint) as  visit_detail_id
      , CAST(null AS text) as observation_source_value
      , gcpt.observation_source_concept_id
      , null as unit_source_value
      , null as qualifier_source_value
   FROM po_datetimeevents_temp
 LEFT JOIN po_patients_temp2 USING (subject_id)
 LEFT JOIN po_admissions_temp2 ON po_datetimeevents_temp.hadm_id = po_admissions_temp2.hadm_id
 LEFT JOIN po_caregivers_temp2 USING (cgid)
 LEFT JOIN po_gcpt_datetimeevents_to_concept_temp gcpt USING (itemid)
 WHERE gcpt.observation_concept_id != 0;

INSERT INTO OMOP.OBSERVATION
(
    observation_id
  , person_id
  , observation_concept_id
  , observation_date
  , observation_datetime
  , observation_type_concept_id
  , value_as_number
  , value_as_string
  , value_as_concept_id
  , qualifier_concept_id
  , unit_concept_id
  , provider_id
  , visit_occurrence_id
  , visit_detail_id
  , observation_source_value
  , observation_source_concept_id
  , unit_source_value
  , qualifier_source_value
)
SELECT
  observation_id
, person_id
, observation_concept_id
, observation_date
, observation_datetime
, observation_type_concept_id
, value_as_number
, value_as_string
, value_as_concept_id
, qualifier_concept_id
, unit_concept_id
, provider_id
, po_row_to_insert_2.visit_occurrence_id
, visit_detail_assign.visit_detail_id
, observation_source_value
, observation_source_concept_id
, unit_source_value
, qualifier_source_value
FROM po_row_to_insert_2
LEFT JOIN OMOP.visit_detail_assign
ON po_row_to_insert_2.visit_occurrence_id = visit_detail_assign.visit_occurrence_id
AND
(--only one visit_detail
(is_first IS TRUE AND is_last IS TRUE)
OR -- first
(is_first IS TRUE AND is_last IS FALSE AND CAST(strftime('%s',po_row_to_insert_2.observation_datetime) AS INTEGER) <= CAST(strftime('%s',visit_detail_assign.visit_end_datetime) AS INTEGER))
OR -- last
(is_last IS TRUE AND is_first IS FALSE AND CAST(strftime('%s',po_row_to_insert_2.observation_datetime) AS INTEGER) > CAST(strftime('%s',visit_detail_assign.visit_start_datetime) AS INTEGER))
OR -- middle
(is_last IS FALSE AND is_first IS FALSE AND CAST(strftime('%s',po_row_to_insert_2.observation_datetime) AS INTEGER) > CAST(strftime('%s',visit_detail_assign.visit_start_datetime) AS INTEGER) AND CAST(strftime('%s',po_row_to_insert_2.observation_datetime) AS INTEGER) <= CAST(strftime('%s',visit_detail_assign.visit_end_datetime) AS INTEGER))
) GROUP BY observation_id;
COMMIT;