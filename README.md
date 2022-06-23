# Mapping the MIMIC-III database to the OMOP schema (using SQLite)

This work is a simplified version of the following project (Paris et al.): https://github.com/MIT-LCP/mimic-omop

## Requirements
- SQLite 3
- A MIMICIII database (each table should be in the CSV file format)

## Implementation process
### Building MIMIC schema and loading data

By executing the following command in the terminal, the mimicIII schema will be created as well as its data.

**NOTE: Every CSV file from the MIMICIII database should be located under the *mimicdata* folder**
```bash
sqlite3 mimicIII.db < 'mimicToSQL/mimicSQL.sql'
```
### Loading manual mappings

The following lines of code will add to the MIMICIII database some manual mappings which were previously created in the following repository: https://github.com/MIT-LCP/mimic-omop/tree/master/extras/concept

Moreover, it is important to mention these manual mappings were updated since some concept IDs were deprecated.

```bash
sqlite3 mimicIII.db < 'mimicToSQL/mimic_gcpt_tables.sql'
```

### Building OMOP schema and loading vocabularies

The following command liens will generate the OMOP schema and will load all the vocabularies obtained from Athena.

**NOTE: All loaded vocabularies from Athena should be located under the *athena_updated* folder**

```bash
sqlite3 omop.db < 'buildOMOP/OMOP_ddl_updated(SQLite).sql'
sqlite3 omop.db < 'buildOMOP/omop_vocab_load.sql' 'mimicToSQL/mimic_gcpt_tables.sql'
```

###Loading concepts from Athena and remaining manual mappings

Since part of the manual mappings previously loaded requires the Athena vocabulary, the following lines should be executed in the following order (inside the SQLite terminal):

```SQL
ATTACH DATABASE 'omop.db' as OMOP;
ATTACH DATABASE 'mimicIII.db' as MIMIC;
.read 'etl_scripts/1_etl_script_concept.sql'
.read 'mimicToSQL/concept/datetimeevents_to_concept.sql'
```

```bash
sqlite3 mimicIII.db < 'mimicToSQL/mimic_gcpt_tables_part2.sql'
```

###ETL process (MIMIC-OMOP)

The following scripts should be executed in the following order. This block of code will transform all data from the MIMIC schema into the OMOP Common Data Model.

```SQL
ATTACH DATABASE 'omop.db' as OMOP;
ATTACH DATABASE 'mimicIII.db' as MIMIC;
.read 'etl_scripts/2_etl_script_care_site.sql'
.read 'etl_scripts/3_etl_script_provider.sql'
.read 'etl_scripts/4_etl_script_person.sql'
.read 'etl_scripts/5_etl_script_death.sql'
.read 'etl_scripts/6_etl_script_visit_occurrence.sql'
.read 'etl_scripts/7_etl_script_observation_period.sql'
.read 'etl_scripts/8_etl_script_visit_detail.sql'
.read 'etl_scripts/9_etl_script_note.sql'
.read 'etl_scripts/10_etl_script_procedure_occurrence.sql'
.read 'etl_scripts/11_etl_script_condition_occurrence.sql'
.read 'etl_scripts/12_etl_script_drug_exposure.sql'
.read 'etl_scripts/13_etl_script_observation.sql'
.read 'etl_scripts/14_etl_script_measurement.sql'
.read 'etl_scripts/15_etl_script_dose_era.sql'
```

###ETL validation process (MIMIC-OMOP)

The following lines will validate each OMOP table in order to check for any errors or inconsistencies in the transformed database. Some key points that are evaluated are the following:
- Duplicated records
- Check all records are mapped to standard concepts (from the vocabularies loaded from Athena)
- Comparing the patient's data in both databases (MIMICIII and OMOP).
- Comparing the number of ICU stays in both databases.
- Comparing the number of admissions in both databases.

**NOTE: It is recommended to execute each of the following lines in separated runs**
```SQL
.read 'etl_validation/1_provider_check.sql'
.read 'etl_validation/2_person_check.sql'
.read 'etl_validation/3_death_check.sql'
.read 'etl_validation/4_visit_occurrence_check.sql'
.read 'etl_validation/5_observation_period_check.sql'
.read 'etl_validation/6_visit_detail_check.sql'
.read 'etl_validation/7_note_check.sql'
.read 'etl_validation/8_procedure_occurrence_check.sql'
.read 'etl_validation/9_condition_occurrence_check.sql'
.read 'etl_validation/10_drug_exposure_check.sql'
.read 'etl_validation/11_observation_check.sql'
.read 'etl_validation/12_measurement_check.sql'
```
