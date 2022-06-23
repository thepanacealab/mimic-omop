BEGIN;

CREATE TEMP VIEW "wardid" AS
    select distinct coalesce(NULLIF(curr_careunit,''),'UNKNOWN') as curr_careunit, curr_wardid
    from transfers;

CREATE TEMP VIEW "gcpt_care_site_temp" AS
    SELECT
        ROW_NUMBER() OVER (ORDER BY mimic_id)+(SELECT mimic_id_seq FROM TEMP_SEQUENCES LIMIT 1) as mimic_id
        , CASE
        WHEN NULLIF(wardid.curr_careunit,'') IS NOT NULL THEN coalesce(NULLIF(care_site_name,''),'UNKNOWN') || ' ward #' || coalesce(NULLIF(CAST(NULLIF(curr_wardid,'') AS Text),''), '?')
        ELSE care_site_name end as care_site_name
        , place_of_service_concept_id as place_of_service_concept_id
        , care_site_name as care_site_source_value
        , place_of_service_source_value
    FROM gcpt_care_site
    left join wardid on care_site_name = curr_careunit;

INSERT INTO OMOP.fact_relationship
	(domain_concept_id_1, fact_id_1, domain_concept_id_2, fact_id_2, relationship_concept_id)
SELECT
  57 AS domain_concept_id_1 -- 57    Care site
, mimic_id AS fact_id_1
, 57 AS domain_concept_id_2 -- 57    Care site
, mimic_id AS fact_id_2 
, 46233688 as relationship_concept_id -- care site has part of care site (any level is part of himself)
FROM gcpt_care_site_temp;

INSERT INTO OMOP.fact_relationship
	(domain_concept_id_1, fact_id_1, domain_concept_id_2, fact_id_2, relationship_concept_id)
SELECT
  57 AS domain_concept_id_1 -- 57    Care site
, gc1.mimic_id AS fact_id_1
, 57 AS domain_concept_id_2 -- 57    Care site
, gc2.mimic_id AS fact_id_2 
, 46233688 as relationship_concept_id -- care site has part of care site (any level is part of himself)
FROM gcpt_care_site_temp gc1
JOIN gcpt_care_site_temp gc2 ON gc2.care_site_name = 'BIDMC' 
WHERE gc1.care_site_name LIKE ' ward ';


INSERT INTO OMOP.CARE_SITE
(
   care_site_id
 , care_site_name
 , place_of_service_concept_id
 , care_site_source_value
 , place_of_service_source_value
)
SELECT gcpt_care_site_temp.mimic_id
    , gcpt_care_site_temp.care_site_name
    , gcpt_care_site_temp.place_of_service_concept_id
    , care_site_source_value
    , place_of_service_source_value
FROM gcpt_care_site_temp;

--UPDATING THE mimic_id_seq SEQUENCE
UPDATE MIMIC.TEMP_SEQUENCES SET mimic_id_seq = (SELECT care_site_id FROM OMOP.CARE_SITE ORDER BY care_site_id DESC LIMIT 1);

COMMIT;