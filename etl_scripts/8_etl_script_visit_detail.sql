-- visit detail
BEGIN;

CREATE TEMP VIEW "transfers_temp" AS  -- including  emergency
    SELECT
      hadm_id    
    , subject_id       
    , curr_careunit 
    , curr_wardid   
    , intime        
    , outtime       
    , mimic_id      
    FROM transfers
    WHERE eventtype!= 'discharge' -- these are not useful
UNION ALL
    SELECT DISTINCT hadm_id AS hadm_id
         , admissions.subject_id
         , 'EMERGENCY' as curr_careunit
	     , CAST(null AS integer) as curr_wardid
         , edregtime as intime
         , min(intime) OVER(PARTITION BY hadm_id) as dischtime 
    -- the end of the emergency is considered the begin of the the admission 
    -- the admittime is sometime after the first transfer
	 , ROW_NUMBER() OVER (ORDER BY admissions.mimic_id)+(SELECT mimic_id_seq FROM TEMP_SEQUENCES LIMIT 1) as mimic_id
     FROM admissions
     LEFT JOIN transfers USING (hadm_id)
     WHERE NULLIF(edregtime,'') IS NOT NULL -- only those having a emergency timestamped
;

CREATE TEMP VIEW "patients_temp1" AS SELECT subject_id, mimic_id as person_id FROM patients;

CREATE TEMP VIEW "gcpt_care_site_temp1" AS
       SELECT care_site.care_site_name, care_site.care_site_id, visit_detail_concept_id
       FROM OMOP.care_site
       left join gcpt_care_site on 
       gcpt_care_site.care_site_name = care_site.care_site_source_value;

CREATE TEMP VIEW "gcpt_admission_location_to_concept_temp1" AS SELECT concept_id as admitting_concept_id, admission_location FROM gcpt_admission_location_to_concept;
CREATE TEMP VIEW "gcpt_discharge_location_to_concept_temp1" AS SELECT concept_id as discharge_to_concept_id, discharge_location FROM gcpt_discharge_location_to_concept;
CREATE TEMP VIEW "admissions_temp_1" AS SELECT hadm_id, admission_location, discharge_location, mimic_id as visit_occurrence_id, admittime, dischtime FROM admissions;
--- IMPORTANT!!!!!!!!!!!!!!!!!!!!!!!!! subject_id has some different values that the ones provided from transfer table
CREATE TEMP VIEW "transfers_chained" AS 
 select t1.*, sum(group_flag) over ( partition by hadm_id order by intime) as grp
  from (
   select transfers_temp.subject_id, transfers_temp.hadm_id, transfers_temp.curr_careunit, transfers_temp.curr_wardid, transfers_temp.intime , coalesce(NULLIF(transfers_temp.outtime,''),NULLIF(dischtime,'')) as outtime
    , transfers_temp.mimic_id, case when lag(transfers_temp.curr_wardid) over ( partition by hadm_id order by intime) = curr_wardid then null else 1 end as group_flag
   from transfers_temp --ie including emergency
   left join admissions_temp_1 USING (hadm_id)
  ) AS t1;

CREATE TEMP VIEW "transfers_no_bed" as 
 SELECT DISTINCT hadm_id, grp 
  , transfers_chained.*
  , min(intime) OVER (PARTITION BY hadm_id, grp) as intime_real
  , max(outtime) OVER (PARTITION BY hadm_id, grp) as outtime_real
 FROM transfers_chained
 ORDER BY hadm_id, grp, intime;

CREATE TEMP VIEW "visit_detail_ward" AS 
 SELECT 
  mimic_id as visit_detail_id
  , patients_temp1.person_id
  , admissions_temp_1.visit_occurrence_id
  , transfers_no_bed.hadm_id
  , coalesce(NULLIF(curr_careunit,''),'UNKNOWN') as curr_careunit -- most of ward are unknown
  ,(CASE WHEN outtime_real > intime_real THEN CAST(intime_real AS text) ELSE CAST(outtime_real AS text) END) as visit_start_date
  ,(CASE WHEN outtime_real > intime_real THEN intime_real ELSE outtime_real END) as visit_start_datetime
  ,(CASE WHEN outtime_real > intime_real THEN CAST(outtime_real AS text) ELSE CAST(intime_real AS text) END) as visit_end_date
  ,(CASE WHEN outtime_real > intime_real THEN outtime_real ELSE intime_real END) as visit_end_datetime
  , CAST(outtime_real AS text) as visit_end_date
  , outtime_real as visit_end_datetime
  , 2000000006 as visit_type_concept_id  -- [MIMIC Generated] ward and physical
  , mimic_id = first_value(mimic_id) OVER(PARTITION BY visit_occurrence_id ORDER BY intime_real ASC ) AS  is_first
  , mimic_id = last_value(mimic_id) OVER(PARTITION BY visit_occurrence_id ORDER BY intime_real ASC range between current row and unbounded following) AS is_last
  , LAG(mimic_id) OVER ( PARTITION BY transfers_no_bed.hadm_id ORDER BY transfers_no_bed.intime_real ASC) as preceding_visit_detail_id
  , admitting_concept_id
  , discharge_to_concept_id
  , admissions_temp_1.admission_location
  , admissions_temp_1.discharge_location
  , (coalesce(NULLIF(curr_careunit,''),'UNKNOWN') || ' ward #' || coalesce(NULLIF(CAST(curr_wardid AS Text),''), '?')) as care_site_name
 FROM transfers_no_bed
 LEFT JOIN patients_temp1 ON transfers_no_bed.subject_id = patients_temp1.subject_id
 LEFT JOIN admissions_temp_1 ON transfers_no_bed.hadm_id = admissions_temp_1.hadm_id
 LEFT JOIN gcpt_admission_location_to_concept_temp1 ON admissions_temp_1.admission_location = gcpt_admission_location_to_concept_temp1.admission_location
 LEFT JOIN gcpt_discharge_location_to_concept_temp1 ON admissions_temp_1.discharge_location = gcpt_discharge_location_to_concept_temp1.discharge_location;

INSERT INTO OMOP.visit_detail
(
    visit_detail_id
  , person_id
  , visit_detail_concept_id
  , visit_start_date
  , visit_start_datetime
  , visit_end_date
  , visit_end_datetime
  , visit_type_concept_id
  , provider_id
  , care_site_id
  , visit_source_value
  , visit_source_concept_id
  , admitting_concept_id
  , admitting_source_value
  , admitting_source_concept_id
  , discharge_to_concept_id
  , discharge_to_source_value
  , discharge_to_source_concept_id
  , preceding_visit_detail_id
  , visit_detail_parent_id
  , visit_occurrence_id
)
SELECT
  visit_detail_id
, person_id
, coalesce(NULLIF(gcpt_care_site_temp1.visit_detail_concept_id,''), 2000000013) as visit_detail_concept_id --unknown
, visit_start_date
, visit_start_datetime
, visit_end_date
, visit_end_datetime
, visit_type_concept_id
, CAST(null AS integer) provider_id
, care_site_id
, CAST(null AS text) visit_source_value
, CAST(null AS integer) visit_source_concept_id
, CASE 
    WHEN (is_first IS FALSE OR is_first = 0) THEN 4030023
    ELSE admitting_concept_id
  END AS admitting_concept_id
, CASE 
    WHEN (is_first IS FALSE OR is_first = 0) THEN 'transfer'
    ELSE admission_location
  END AS admitting_source_value
, CAST(null AS integer) as admitting_source_concept_id
, CASE 
    WHEN (is_last IS FALSE OR is_last = 0) THEN 4030023
    ELSE discharge_to_concept_id
  END AS discharge_to_concept_id
, CASE 
    WHEN (is_last IS FALSE OR is_last = 0) THEN 'transfer'
    ELSE discharge_location
  END AS discharge_to_source_value
, CAST(null AS integer) as discharge_to_source_concept_id
, preceding_visit_detail_id
, CAST(null AS integer) visit_detail_parent_id
, visit_occurrence_id
FROM visit_detail_ward
LEFT JOIN gcpt_care_site_temp1 USING (care_site_name);

CREATE TEMP VIEW "callout_delay" as 
 SELECT
  visit_detail_id as subject_id
  , visit_start_datetime as cohort_start_date
  , visit_end_datetime as cohort_end_date
  , ((strftime('%s', outcometime) - strftime('%s', createtime))/3600/24) as discharge_delay
  , (outcometime - createtime) / 2 + createtime as mean_time
 FROM callout
  LEFT JOIN  visit_detail_ward v
  ON v.hadm_id = callout.hadm_id
  AND callout.curr_careunit = v.curr_careunit
  AND ((outcometime - createtime) / 2 + createtime) between v.visit_start_datetime and v.visit_end_datetime
  WHERE LOWER(callout_outcome) not like 'cancel%' AND NULLIF(visit_detail_id,'') IS NOT NULL;

INSERT INTO OMOP.cohort_attribute
  (
     cohort_definition_id
  	, cohort_start_date
  	, cohort_end_date
  	, subject_id
  	, attribute_definition_id
  	, value_as_number
  	, value_as_concept_id
  )
	SELECT
	0 AS cohort_definition_id
	, cohort_start_date
	, cohort_end_date
	, subject_id
	, 1 AS  attribute_definition_id -- callout delay
	, discharge_delay as value_as_number
	, 0 value_as_concept_id
	FROM callout_delay;

INSERT INTO OMOP.cohort_attribute
  (
  	  cohort_definition_id
  	, cohort_start_date
  	, cohort_end_date
  	, subject_id
  	, attribute_definition_id
  	, value_as_number
  	, value_as_concept_id
  )
	SELECT
	0 AS cohort_definition_id
	, visit_start_datetime as  cohort_start_date
	, visit_end_datetime as cohort_end_date
	, visit_detail_id as subject_id
	,  2  as  attribute_definition_id  -- visit delay
    , ((strftime('%s', visit_end_datetime) - strftime('%s', visit_start_datetime))/3600/24) as value_as_number
	, 0 value_as_concept_id
	FROM visit_detail_ward;

SELECT 1;

--UPDATING THE mimic_id_seq SEQUENCE
UPDATE MIMIC.TEMP_SEQUENCES SET mimic_id_seq = (SELECT visit_detail_id FROM OMOP.visit_detail ORDER BY visit_detail_id DESC LIMIT 1);
UPDATE MIMIC.TEMP_SEQUENCES SET mimic_id_seq = MAX(mimic_id_seq, (SELECT cohort_definition_id FROM OMOP.cohort_attribute ORDER BY cohort_definition_id DESC LIMIT 1));

-- SERVICES information
WITH
"patients_temp2" AS (SELECT subject_id, mimic_id as person_id FROM patients),
"gcpt_care_site_temp2" AS (
	       SELECT
	   care_site.care_site_name
	 , care_site.care_site_id
	 , visit_detail_concept_id
	      FROM OMOP.care_site
	      LEFT JOIN gcpt_care_site on gcpt_care_site.care_site_name = care_site.care_site_source_value
),
"admissions_temp_2" AS (SELECT hadm_id, admission_location, discharge_location, mimic_id as visit_occurrence_id, admittime, dischtime FROM admissions),
"serv_tmp" as (
	SELECT services.*
	, visit_occurrence_id
	, lead(services.row_id) OVER ( PARTITION BY services.hadm_id ORDER BY transfertime) as next
	, lag(services.row_id) OVER ( PARTITION BY services.hadm_id ORDER BY transfertime) as prev
	, admittime
	, dischtime
	FROM services
	LEFT JOIN admissions_temp_2 USING (hadm_id)
),
"serv" as (
	SELECT
	serv_tmp.visit_occurrence_id
	, serv_tmp.mimic_id as visit_detail_id
	, serv_tmp.subject_id
	, serv_tmp.hadm_id
	, serv_tmp.curr_service
	, serv_adm_prev.mimic_id as preceding_visit_detail_id
	, serv_tmp.transfertime as visit_start_datetime
	, CASE WHEN NULLIF(serv_tmp.prev,'') IS NULL AND NULLIF(serv_tmp.next,'') IS NOT NULL THEN serv_adm_next.transfertime
               WHEN NULLIF(serv_tmp.prev,'') IS NULL AND NULLIF(serv_tmp.next,'') IS NULL THEN serv_tmp.dischtime
               WHEN NULLIF(serv_tmp.prev,'') IS NOT NULL AND NULLIF(serv_tmp.next,'') IS NULL THEN serv_tmp.dischtime
               WHEN NULLIF(serv_tmp.prev,'') IS NOT NULL AND NULLIF(serv_tmp.next,'') IS NOT NULL THEN serv_adm_next.transfertime
          END as visit_end_datetime
	FROM serv_tmp
	LEFT JOIN serv_tmp as serv_adm_prev ON (serv_tmp.prev = serv_adm_prev.row_id)
	LEFT JOIN serv_tmp as serv_adm_next ON (serv_tmp.next = serv_adm_next.row_id)
),
"visit_detail_service" AS (
        SELECT
        ROW_NUMBER() OVER (ORDER BY visit_detail_id)+(SELECT mimic_id_seq FROM TEMP_SEQUENCES LIMIT 1) as visit_detail_id
      , person_id
      , coalesce(NULLIF(gcpt_care_site_temp2.visit_detail_concept_id,''), 0) as visit_detail_concept_id
      ,(CASE WHEN serv.visit_end_datetime > serv.visit_start_datetime THEN CAST(serv.visit_start_datetime AS text) ELSE CAST(serv.visit_end_datetime AS text) END) as visit_start_date
      ,(CASE WHEN serv.visit_end_datetime > serv.visit_start_datetime THEN serv.visit_start_datetime ELSE serv.visit_end_datetime END) as visit_start_datetime
      ,(CASE WHEN serv.visit_end_datetime > serv.visit_start_datetime THEN CAST(serv.visit_end_datetime AS text) ELSE CAST(serv.visit_start_datetime AS text) END) as visit_end_date
      ,(CASE WHEN serv.visit_end_datetime > serv.visit_start_datetime THEN serv.visit_end_datetime ELSE serv.visit_start_datetime END) as visit_end_datetime
      , 45770670 as visit_type_concept_id
      , gcpt_care_site_temp2.care_site_id
      , CAST(null AS integer) preceding_visit_detail_id
      , CAST(null AS integer) visit_detail_parent_id
      , serv.visit_occurrence_id
        FROM serv
	LEFT JOIN gcpt_care_site_temp2 ON (care_site_name = curr_service)
	LEFT JOIN patients_temp2 using (subject_id)
)
INSERT INTO OMOP.visit_detail -- SERVICE INFORMATIONS
(
    visit_detail_id
  , person_id
  , visit_detail_concept_id
  , visit_start_date
  , visit_start_datetime
  , visit_end_date
  , visit_end_datetime
  , visit_type_concept_id
  , provider_id
  , care_site_id
  , visit_source_value
  , visit_source_concept_id
  , admitting_concept_id
  , admitting_source_value
  , admitting_source_concept_id
  , discharge_to_concept_id
  , discharge_to_source_value
  , discharge_to_source_concept_id
  , preceding_visit_detail_id
  , visit_detail_parent_id
  , visit_occurrence_id
)
SELECT
  visit_detail_id
, person_id
, visit_detail_concept_id
, visit_start_date
, visit_start_datetime
, visit_end_date
, visit_end_datetime
, visit_type_concept_id
, CAST(null AS integer) provider_id
, care_site_id
, CAST(null AS text) visit_source_value
, CAST(null AS integer) visit_source_concept_id
, CAST(null AS integer) admitting_concept_id
, CAST(null AS text) admitting_source_value
, CAST(null AS integer) admitting_source_concept_id
, CAST(null AS integer) discharge_to_concept_id
, CAST(null AS text) discharge_to_source_value
, CAST(null AS integer) discharge_to_source_concept_id
, CAST(null AS integer) preceding_visit_detail_id
, visit_detail_parent_id
, visit_occurrence_id
FROM visit_detail_service;

--UPDATING THE mimic_id_seq SEQUENCE
UPDATE MIMIC.TEMP_SEQUENCES SET mimic_id_seq = (SELECT visit_detail_id FROM OMOP.visit_detail ORDER BY visit_detail_id DESC LIMIT 1);


-- first draft of icustay assignation table
-- the way of assigning is quite simple right now
-- but simple error is better than complicate error
-- meaning, those links are artificial watever we do
 DROP TABLE IF EXISTS OMOP.visit_detail_assign;
 CREATE TABLE OMOP.visit_detail_assign AS
 SELECT
   visit_detail_id
 , visit_occurrence_id
 , visit_start_datetime
 , visit_end_datetime
 , visit_detail_id = first_value(visit_detail_id) OVER(PARTITION BY visit_occurrence_id ORDER BY visit_start_datetime ASC ) AS  is_first
 , visit_detail_id = last_value(visit_detail_id) OVER(PARTITION BY visit_occurrence_id ORDER BY visit_start_datetime ASC range between current row and unbounded following) AS is_last
 , visit_detail_concept_id = 32037 AS is_icu
 , visit_detail_concept_id = 9203 AS is_emergency
 FROM  OMOP.visit_detail
 WHERE visit_type_concept_id = 2000000006; -- only ward kind
COMMIT;
 