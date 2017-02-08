# pg-logical-backup-test

Simple script to test your database backup (logical, made by pg_dump) can be restored.

```
Usage: logical_backup_test.rb [options] dump_file

    -U, --user [USER]                DB user. Will be created and will be db owner
    -p, --password [PASSWORD]        DB password. Will be set for db user (optional).
    -d, --dbname [NAME]              DB name. Should be same as in dump file
    -V, --pg-version [VERSION]       PostgreSQL version to perform restore on (default: latest)
    -v, --[no-]verbose               Run verbosely
    -h, --help                       Show this message
```

### Example

```
ruby test_logical_backup.rb -V 9.5.2 -U your_db_username -d your_db --verbose /opt/backup/db_logical/db-2017-02-06.dump
```
