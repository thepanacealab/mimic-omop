--ATTACH DATABASE 'omop.db' as OMOP;
--ATTACH DATABASE 'mimicIII.db' as MIMIC;

CREATE TEMP VIEW "distinct_itemid" AS  SELECT distinct itemid  FROM datetimeevents;
CREATE TEMP VIEW "distinct_label" AS SELECT label, itemid FROM d_items WHERE itemid IN (SELECT * FROM distinct_itemid);

.header on
.mode csv
.output mimicToSQL/concept/datetimeevents_to_concept.csv

SELECT null as mimic_id, dl.label, null as observation_concept_id, null as observation_concept_name
, dl.itemid, c.concept_id as observation_source_concept_id FROM distinct_label dl
JOIN concept c ON concept_code = itemid AND c.vocabulary_id = 'MIMIC d_items';

.quit
