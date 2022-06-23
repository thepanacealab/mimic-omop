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

