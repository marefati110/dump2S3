# 🐘 PostgreSQL to S3 Backup (Docker)

A lightweight Docker image to **periodically back up a PostgreSQL database to AWS S3** (or any S3-compatible storage).  
Supports multiple PostgreSQL versions and flexible scheduling.

---

## 🚀 Usage

### Example `docker-compose.yml`
```yaml
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password

  backup:
    image: marefati110/dump2s3:17
    environment:
      SCHEDULE: '@weekly'               # optional: backup frequency
      RUN_BACKUP_ON_START: "true"       # optional: run a backup immediately on start
      BACKUP_KEEP_DAYS: 7               # optional: delete old backups from S3
      GZIP_ENABLED: "yes"               # optional: yes/true/1 (default) or no/false/0
      WEBHOOK_URL: https://example.com/webhook # optional: POST status JSON here
  # Optional custom filenames for uploads (pick one depending on compression)
      DUMP_FILENAME: ""                 # optional: final name for uncompressed uploads, e.g. latest.dump
      GZIP_FILENAME: ""                 # optional: final name for compressed uploads, e.g. latest.dump.gz
      S3_REGION: region
      S3_ACCESS_KEY_ID: key
      S3_SECRET_ACCESS_KEY: secret
      S3_BUCKET: my-bucket
      S3_PREFIX: backup
      S3_ENDPOINT: https://s3.example.com # optional: for non-AWS S3 storage
      POSTGRES_HOST: postgres
      POSTGRES_DATABASE: dbname
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
```


| Variable               | Required | Default | Description                                                     |
| ---------------------- | -------- | ------- | --------------------------------------------------------------- |
| `SCHEDULE`             | ❌        | —       | Backup frequency (see [Schedule Examples](#-schedule-examples)) |
| `RUN_BACKUP_ON_START`  | ❌        | `false` | Run an immediate backup on container start                      |
| `BACKUP_KEEP_DAYS`     | ❌        | —       | Delete backups older than N days from S3                        |
| `GZIP_ENABLED`         | ❌        | `yes`   | Compress backup (`yes`/`true`/`1`) or store plain dump          |
| `WEBHOOK_URL`          | ❌        | —       | Send POST request with backup result                            |
| `DUMP_FILENAME`        | ❌        | —       | Override final object name when compression is disabled (e.g., `latest.dump`) |
| `GZIP_FILENAME`        | ❌        | —       | Override final object name when compression is enabled (e.g., `latest.dump.gz`) |
| `S3_REGION`            | ✅        | —       | S3 region                                                       |
| `S3_ACCESS_KEY_ID`     | ✅        | —       | S3 access key                                                   |
| `S3_SECRET_ACCESS_KEY` | ✅        | —       | S3 secret key                                                   |
| `S3_BUCKET`            | ✅        | —       | Target S3 bucket                                                |
| `S3_PREFIX`            | ✅        | —       | Path/prefix for storing backups                                 |
| `S3_ENDPOINT`          | ❌        | —       | Custom S3 endpoint (for MinIO, etc.)                            |
| `POSTGRES_HOST`        | ✅        | —       | PostgreSQL server hostname                                      |
| `POSTGRES_DATABASE`    | ✅        | —       | Database name                                                   |
| `POSTGRES_USER`        | ✅        | —       | Database username                                               |
| `POSTGRES_PASSWORD`    | ✅        | —       | Database password                                               |



| Value            | Meaning                            |
| ---------------- | ---------------------------------- |
| `@hourly`        | Every hour at minute 0             |
| `@daily`         | Every day at midnight              |
| `@weekly`        | Every Sunday at midnight           |
| `@monthly`       | First day of the month at midnight |
| `@every 2h`      | Every 2 hours from container start |
| `0 2 * * *`      | Every day at 02:00 UTC             |
| `0 */15 * * * *` | Every 15 minutes                   |
| `30 3 * * 1-5`   | Weekdays (Mon–Fri) at 03:30 UTC    |
| `0 23 * * 5`     | Every Friday at 23:00 UTC          |


🔔 Webhook Callback
If WEBHOOK_URL is set, the container will send an HTTP POST request after every backup attempt — both success and failure.

Request body example:

json
Copy
Edit
{
  "status": "success",        // "success" or "error"
  "message": "Backup completed successfully",
  "file": "dbname_2025-08-10_120000.dump.gz",
  "database": "dbname",
  "host": "postgres",
  "timestamp": "2025-08-10T12:00:00Z"
}
Fields:

status – "success" or "error".

message – Short description of the result.

file – Backup file name stored in S3.

database – Name of the PostgreSQL database.

host – Hostname or IP of the PostgreSQL server.

timestamp – UTC time when the backup finished.

Example curl:

sh
Copy
Edit
curl -X POST https://example.com/webhook \
  -H "Content-Type: application/json" \
  -d '{
        "status": "success",
        "message": "Backup completed successfully",
        "file": "mydb_2025-08-10_120000.dump.gz",
        "database": "mydb",
        "host": "postgres",
        "timestamp": "2025-08-10T12:00:00Z"
      }'

### 📄 Custom filenames

You can override the final uploaded filename via environment variables:

- When gzip is enabled (default), set `GZIP_ENABLED=yes` and optionally `GZIP_FILENAME` (e.g., `latest.dump.gz`).
- When gzip is disabled, set `GZIP_ENABLED=no` and optionally `DUMP_FILENAME` (e.g., `latest.dump`).

Notes:
- If you omit these variables, the default pattern is `<db>_<timestamp>.dump[.gz]`.
- If your override doesn’t include the proper extension, it will be appended automatically.
- Using a static name (like `latest.dump.gz`) will overwrite the previous object in S3 on each run.

