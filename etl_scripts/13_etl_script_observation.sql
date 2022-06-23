BEGIN;
-- from datetimeevents
CREATE TEMP VIEW "ob_datetimeevents_temp" AS SELECT subject_id, hadm_id, itemid, cgid, mimic_id as observation_id, CAST(coalesce(NULLIF(value,''),NULLIF(charttime,'')) AS Text) as observation_date, value as observation_datetime FROM datetimeevents where NULLIF(error,'') is null or error = 0;
CREATE TEMP VIEW "ob_gcpt_datetimeevents_to_concept_temp" AS SELECT label as value_as_string, observation_concept_id, itemid, observation_source_concept_id from gcpt_datetimeevents_to_concept;
CREATE TEMP VIEW "ob_patients_temp" AS SELECT subject_id, mimic_id as person_id FROM patients;
CREATE TEMP VIEW "ob_caregivers_temp" AS SELECT cgid, mimic_id as provider_id FROM caregivers;
CREATE TEMP VIEW "ob_admissions_temp" AS SELECT subject_id, hadm_id, mimic_id as visit_occurrence_id, insurance, marital_status, language, diagnosis, religion, ethnicity, admittime FROM admissions;
CREATE TEMP VIEW "ob_row_to_insert_1" AS
 SELECT
        ob_datetimeevents_temp.observation_id
      , ob_patients_temp.person_id
      --, gcpt.observation_concept_id
      , 4085802 as observation_concept_id
      , ob_datetimeevents_temp.observation_date
      , (ob_datetimeevents_temp.observation_datetime) as observation_datetime
      , 38000280 as observation_type_concept_id -- Observation recorded from EHR
      , CAST(null AS double precision) as value_as_number
      , gcpt.value_as_string as value_as_string
      , CAST(null AS bigint) as value_as_concept_id
      , CAST(null AS bigint) as qualifier_concept_id
      , CAST(null AS bigint) as unit_concept_id
      , ob_caregivers_temp.provider_id
      , ob_admissions_temp.visit_occurrence_id
      , CAST(null AS bigint) as  visit_detail_id
      , CAST(null AS text) as observation_source_value
      , gcpt.observation_source_concept_id
      , null as unit_source_value
      , null as qualifier_source_value
   FROM ob_datetimeevents_temp
 LEFT JOIN ob_patients_temp USING (subject_id)
 LEFT JOIN ob_admissions_temp USING (hadm_id)
 LEFT JOIN ob_caregivers_temp USING (cgid)
 LEFT JOIN ob_gcpt_datetimeevents_to_concept_temp gcpt USING (itemid)
--
 WHERE gcpt.observation_concept_id = 0 or NULLIF(gcpt.observation_concept_id,'') IS NULL;

DELETE FROM OMOP.observation WHERE observation_id IN (SELECT observation_id FROM ob_row_to_insert_1);
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
, ob_row_to_insert_1.visit_occurrence_id
, visit_detail_assign.visit_detail_id
, observation_source_value
, observation_source_concept_id
, unit_source_value
, qualifier_source_value
FROM ob_row_to_insert_1
LEFT JOIN OMOP.visit_detail_assign
ON ob_row_to_insert_1.visit_occurrence_id = visit_detail_assign.visit_occurrence_id
AND
(--only one visit_detail
(is_first IS TRUE AND is_last IS TRUE)
OR -- first
(is_first IS TRUE AND is_last IS FALSE AND ob_row_to_insert_1.observation_datetime <= visit_detail_assign.visit_end_datetime)
OR -- last
(is_last IS TRUE AND is_first IS FALSE AND ob_row_to_insert_1.observation_datetime > visit_detail_assign.visit_start_datetime)
OR -- middle
(is_last IS FALSE AND is_first IS FALSE AND ob_row_to_insert_1.observation_datetime > visit_detail_assign.visit_start_datetime AND ob_row_to_insert_1.observation_datetime <= visit_detail_assign.visit_end_datetime)
) GROUP BY observation_id;

-- from admissions
CREATE TEMP VIEW "ob_patients_temp2" AS SELECT subject_id, mimic_id as person_id FROM patients;
CREATE TEMP VIEW "ob_caregivers_temp2" AS SELECT cgid, mimic_id as provider_id FROM caregivers;
CREATE TEMP VIEW "ob_admissions_temp2" AS SELECT subject_id, hadm_id, mimic_id as visit_occurrence_id, insurance, marital_status, language, diagnosis, religion, ethnicity, admittime FROM admissions;
CREATE TEMP VIEW "ob_gcpt_insurance_to_concept_temp2" AS SELECT * FROM gcpt_insurance_to_concept;
CREATE TEMP VIEW "ob_gcpt_ethnicity_to_concept_temp2" AS SELECT * FROM gcpt_ethnicity_to_concept;
CREATE TEMP VIEW "ob_gcpt_religion_to_concept_temp2" AS SELECT * FROM gcpt_religion_to_concept;
CREATE TEMP VIEW "ob_gcpt_marital_status_to_concept_temp2" AS SELECT * FROM gcpt_marital_status_to_concept;

CREATE TEMP VIEW "ob_row_to_insert_2_part1" AS
SELECT
        ROW_NUMBER() OVER (ORDER BY adm.visit_occurrence_id)+(SELECT mimic_id_seq FROM TEMP_SEQUENCES LIMIT 1) as observation_id
      , ob_patients_temp2.person_id
      , 46235654 as observation_concept_id -- Primary insurance
      , CAST(adm.ADMITTIME AS text) as observation_date
      , (adm.ADMITTIME) as observation_datetime
      , 38000280 as observation_type_concept_id -- Observation recorded from EHR
      , CAST(null AS double precision) as value_as_number
      , adm.INSURANCE as value_as_string
      , map.concept_id as value_as_concept_id
      , CAST(null AS integer) as qualifier_concept_id
      , CAST(null AS integer) as provider_id
      , CAST(null AS integer) as unit_concept_id
      , adm.visit_occurrence_id
      , CAST(null AS integer) as  visit_detail_id
      , CAST(null AS text) as observation_source_value
      , CAST(null AS integer) as observation_source_concept_id
      , CAST(null AS text) as unit_source_value
      , CAST(null AS text) as qualifier_source_value
  FROM ob_admissions_temp2 as adm
    LEFT JOIN ob_gcpt_insurance_to_concept_temp2 AS map USING (insurance)
    LEFT JOIN ob_patients_temp2 USING (subject_id)
  WHERE NULLIF(adm.insurance,'') IS NOT NULL;

CREATE TEMP VIEW "ob_row_to_insert_2_part2" AS
SELECT
        ROW_NUMBER() OVER (ORDER BY adm.visit_occurrence_id)+
        (SELECT mimic_id_seq FROM TEMP_SEQUENCES LIMIT 1)+
        (SELECT COUNT(*) FROM ob_row_to_insert_2_part1)
         as observation_id
      , ob_patients_temp2.person_id
      , 40766231 as observation_concept_id -- Marital status
      , CAST(adm.admittime AS Text) as observation_date
      , (adm.admittime) as observation_datetime
      , 38000280 as observation_type_concept_id -- Observation recorded from EHR
      , null as value_as_number
      , adm.marital_status as value_as_string
      , map.concept_id as value_as_concept_id
      , null as qualifier_concept_id
      , null as provider_id
      , CAST(null AS integer) as unit_concept_id
      , adm.visit_occurrence_id
      , null as visit_detail_id
      , null as observation_source_value
      , null as observation_source_concept_id
      , null as unit_source_value
      , null as qualifier_source_value
  FROM ob_admissions_temp2 as adm
    LEFT JOIN ob_gcpt_marital_status_to_concept_temp2 as map USING (marital_status)
    LEFT JOIN ob_patients_temp2 USING (subject_id)
  WHERE NULLIF(adm.marital_status,'') IS NOT NULL;

CREATE TEMP VIEW "ob_row_to_insert_2_part3" AS
SELECT
        ROW_NUMBER() OVER (ORDER BY adm.visit_occurrence_id)+
        (SELECT mimic_id_seq FROM TEMP_SEQUENCES LIMIT 1)+
        (SELECT COUNT(*) FROM ob_row_to_insert_2_part1)+
        (SELECT COUNT(*) FROM ob_row_to_insert_2_part2) as observation_id
      , ob_patients_temp2.person_id
      , 4052017 as observation_concept_id -- Religious affiliation
      , CAST(adm.admittime AS Text) as observation_date
      , (adm.admittime) as observation_datetime
      , 38000280 as observation_type_concept_id -- Observation recorded from EHR
      , null as value_as_number
      , adm.religion as value_as_string
      , map.concept_id as value_as_concept_id
      , null as qualifier_concept_id
      , null as provider_id
      , CAST(null AS integer) as unit_concept_id
      , adm.visit_occurrence_id
      , null as visit_detail_id
      , null as observation_source_value
      , null as observation_source_concept_id
      , null as unit_source_value
      , null as qualifier_source_value
  FROM ob_admissions_temp2 as adm
    JOIN ob_gcpt_religion_to_concept_temp2 as map USING (religion)
    LEFT JOIN ob_patients_temp2 USING (subject_id)
  WHERE NULLIF(adm.religion,'') IS NOT NULL;

CREATE TEMP VIEW "ob_row_to_insert_2_part4" AS
SELECT
        ROW_NUMBER() OVER (ORDER BY adm.visit_occurrence_id)+
        (SELECT mimic_id_seq FROM TEMP_SEQUENCES LIMIT 1)+
        (SELECT COUNT(*) FROM ob_row_to_insert_2_part1)+
        (SELECT COUNT(*) FROM ob_row_to_insert_2_part2)+
        (SELECT COUNT(*) FROM ob_row_to_insert_2_part3)
         as observation_id
      , ob_patients_temp2.person_id
      , 40758030 as observation_concept_id -- Language.preferred
      , CAST(adm.admittime AS Text) as observation_date
      , (adm.admittime) as observation_datetime
      , 38000280 as observation_type_concept_id -- Observation recorded from EHR
      , null as value_as_number
      , adm.language as value_as_string
      , null as value_as_concept_id
      , null as qualifier_concept_id
      , null as provider_id
      , CAST(null AS integer) as unit_concept_id
      , adm.visit_occurrence_id
      , null as visit_detail_id
      , null as observation_source_value
      , null as observation_source_concept_id
      , null as unit_source_value
      , null as qualifier_source_value
  FROM ob_admissions_temp2 as adm
    LEFT JOIN ob_patients_temp2 USING (subject_id)
  WHERE
    NULLIF(adm.language,'') IS NOT NULL;

CREATE TEMP VIEW "ob_row_to_insert_2_part5" AS
SELECT
        ROW_NUMBER() OVER (ORDER BY adm.visit_occurrence_id)+
        (SELECT mimic_id_seq FROM TEMP_SEQUENCES LIMIT 1)+
        (SELECT COUNT(*) FROM ob_row_to_insert_2_part1)+
        (SELECT COUNT(*) FROM ob_row_to_insert_2_part2)+
        (SELECT COUNT(*) FROM ob_row_to_insert_2_part3)+
        (SELECT COUNT(*) FROM ob_row_to_insert_2_part4)
         as observation_id
      , ob_patients_temp2.person_id
      , 44803968 as observation_concept_id -- Ethnicity - National Public Health Classification
      , CAST(adm.admittime AS Text) as observation_date
      , (adm.admittime) as observation_datetime
      , 38000280 as observation_type_concept_id -- Observation recorded from EHR
      , null as value_as_number
      , adm.ethnicity as value_as_string
      , map.race_concept_id as value_as_concept_id
      , null as qualifier_concept_id
      , null as provider_id
      , CAST(null AS integer) as unit_concept_id
      , adm.visit_occurrence_id
      , null as visit_detail_id
      , null as observation_source_value
      , null as observation_source_concept_id
      , null as unit_source_value
      , null as qualifier_source_value
  FROM ob_admissions_temp2 as adm
    JOIN ob_gcpt_ethnicity_to_concept_temp2 as map USING (ethnicity)
    LEFT JOIN ob_patients_temp2 USING (subject_id)
  WHERE NULLIF(adm.ethnicity,'') IS NOT NULL;


CREATE TEMP VIEW "ob_row_to_insert_2" AS 
  SELECT * FROM ob_row_to_insert_2_part1
UNION ALL
  SELECT * FROM ob_row_to_insert_2_part2
UNION ALL
  SELECT * FROM ob_row_to_insert_2_part3
UNION ALL
  SELECT * FROM ob_row_to_insert_2_part4
UNION ALL
  SELECT * FROM ob_row_to_insert_2_part5;

 INSERT INTO OMOP.OBSERVATION
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
        , ob_row_to_insert_2.visit_occurrence_id
        , visit_detail_id
        , observation_source_value
        , observation_source_concept_id
        , unit_source_value
        , qualifier_source_value
FROM ob_row_to_insert_2;

--UPDATING THE mimic_id_seq SEQUENCE
UPDATE MIMIC.TEMP_SEQUENCES SET mimic_id_seq = (SELECT observation_id FROM OMOP.observation ORDER BY observation_id DESC LIMIT 1);

-- drgcodes
WITH
"drgcodes_temp3" AS (
SELECT
  mimic_id as observation_id
, subject_id
, hadm_id
, description
FROM drgcodes
),
"gcpt_drgcode_to_concept_temp3" AS (SELECT description, non_standard_concept_id, standard_concept_id FROM gcpt_drgcode_to_concept),
"patients_temp3" AS (SELECT subject_id, mimic_id as person_id FROM patients),
"admissions_temp3" AS (SELECT subject_id, hadm_id, mimic_id as visit_occurrence_id, coalesce(NULLIF(edregtime,''), NULLIF(admittime,'')) as observation_datetime FROM admissions),
"row_to_insert_3" AS (
SELECT
          observation_id
        , person_id
        , 4296248 as observation_concept_id -- Cost containment drgcode should be in cost table apparently.... http://forums.ohdsi.org/t/most-appropriate-omop-table-to-house-drg-information/1591/9
        , CAST(observation_datetime AS Text) as observation_date
        , observation_datetime
        , 38000280 as observation_type_concept_id -- Observation recorded from EHR
        , CAST(null AS numeric) value_as_number
        , description as value_as_string
        , coalesce(NULLIF(standard_concept_id,''), NULLIF(non_standard_concept_id,''), 0) as value_as_concept_id
        , CAST(null AS integer) qualifier_concept_id
        , CAST(null AS integer) unit_concept_id
        , CAST(null AS integer) provider_id
        , visit_occurrence_id
        , CAST(null AS integer) visit_detail_id
        , CAST(null AS text) observation_source_value
        , CAST(null AS integer) observation_source_concept_id
        , CAST(null AS text) unit_source_value
        , CAST(null AS text) qualifier_source_value
	FROM drgcodes_temp3
	LEFT JOIN patients_temp3 USING (subject_id)
	LEFT JOIN admissions_temp3 USING (hadm_id)
	LEFT JOIN gcpt_drgcode_to_concept_temp3 USING (description)
)
INSERT INTO OMOP.observation
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
        , visit_occurrence_id
        , visit_detail_id
        , observation_source_value
        , observation_source_concept_id
        , unit_source_value
        , qualifier_source_value
FROM row_to_insert_3;


-- Chartevents.text
WITH
"chartevents_text" AS (
        SELECT
               chartevents.mimic_id as observation_id
             , subject_id
             , cgid
             , hadm_id
             , charttime as observation_datetime
             , value as value_as_string
             , valuenum as value_as_number
             , concept.concept_id as observation_source_concept_id
             , concept.concept_code as observation_source_value
          FROM chartevents
	  JOIN OMOP.concept ON  -- concept driven dispatcher
		(           concept_code  = CAST(itemid AS Text)
			AND domain_id     = 'Observation'
			AND vocabulary_id = 'MIMIC d_items'
		)
	WHERE NULLIF(error,'') IS NULL OR error= 0
       ),
"patients_temp4" AS (SELECT mimic_id AS person_id, subject_id FROM patients),
"admissions_temp4" AS (SELECT mimic_id AS visit_occurrence_id, hadm_id FROM admissions),
"caregivers_temp4" AS (SELECT mimic_id AS provider_id, cgid FROM caregivers),
"row_to_insert_4" AS (
SELECT
          observation_id
        , person_id
        , 0 as observation_concept_id
        , CAST(observation_datetime AS Text) observation_date
        , observation_datetime
        , 581413 as observation_type_concept_id -- Observation from Measurement
        , value_as_number
        , value_as_string
        , CAST(null AS integer) value_as_concept_id
        , CAST(null AS integer) qualifier_concept_id
        , CAST(null AS integer) unit_concept_id
        , provider_id
        , visit_occurrence_id
        , CAST(null AS integer) visit_detail_id
        , observation_source_value
        , observation_source_concept_id
        , CAST(null AS integer) unit_source_value
        , CAST(null AS text) qualifier_source_value
        FROM chartevents_text
        LEFT JOIN patients_temp4 USING (subject_id)
        LEFT JOIN caregivers_temp4 USING (cgid)
        LEFT JOIN admissions_temp4 USING (hadm_id))
INSERT INTO OMOP.observation
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
        , row_to_insert_4.visit_occurrence_id
        , visit_detail_assign.visit_detail_id
        , observation_source_value
        , observation_source_concept_id
        , unit_source_value
        , qualifier_source_value
FROM row_to_insert_4
LEFT JOIN OMOP.visit_detail_assign
ON row_to_insert_4.visit_occurrence_id = visit_detail_assign.visit_occurrence_id
AND
(--only one visit_detail
(is_first IS TRUE AND is_last IS TRUE)
OR -- first
(is_first IS TRUE AND is_last IS FALSE AND row_to_insert_4.observation_datetime <= visit_detail_assign.visit_end_datetime)
OR -- last
(is_last IS TRUE AND is_first IS FALSE AND row_to_insert_4.observation_datetime > visit_detail_assign.visit_start_datetime)
OR -- middle
(is_last IS FALSE AND is_first IS FALSE AND row_to_insert_4.observation_datetime > visit_detail_assign.visit_start_datetime AND row_to_insert_4.observation_datetime <= visit_detail_assign.visit_end_datetime)
) GROUP BY observation_id;
COMMIT;