# MinIO backup

MinIO backup is a backup script for MinIO storage. It copies a bucket, compresses it and stores backups in a S3 bucket on your preferred cloud provider. This project is designed to run in a Docker container, making deployment and management straightforward.

## Configuration

This script requires several environment variables to work properly:

| Variable | Description | Required | Example |
| --- | --- | --- | --- |
| MINIO_ENDPOINT | The host of the minio | yes | minio |
| MINIO_ACCESS_KEY | The minIO access key | yes | dzqikdhei |
| MINIO_SECRET_KEY | The minIO secret key | yes | dqzdqbdkdq |
| MINIO_BUCKET | The minIO bucket name | yes | plannify |
| --- | --- | --- |
| BACKUP_DIR | The directory of the backup	 | no | 'minio/daily', 'minio/weekly', 'minio/monthly' |
| BACKUP_MAX_BEFORE_DELETE | The maximum number of backup before deleting the oldest one | no | 7 |
| BACKUP_COMPRESSION | The compression method to use (gzip, xz, zip) | no | zip | 
| --- | --- | --- |
| S3_ENDPOINT | The bucket endpoint | yes | https://... |
| S3_ACCESS_TOKEN | The access token of your provider account | yes | 1234567890 |
| S3_SECRET_ACCESS_TOKEN | The secret access token of your provider account | yes | 1234567890 |
| S3_BUCKET | The S3 bucket of your account | yes | plannify |

## Usage

This script is designed to be run in a Docker container. You can use it in a kubernetes CronJob or in a Docker container directly.

## Examples

This section provides config examples of how to use the script with different cloud providers.

### Cloudflare R2

```yaml
S3_ENDPOINT: https://<account_id>.r2.cloudflarestorage.com
S3_ACCESS_TOKEN: 1234567890
S3_SECRET_ACCESS_TOKEN: 1234567890
S3_BUCKET: plannify
```

### AWS S3

```yaml
S3_ENDPOINT: https://s3.amazonaws.com
S3_ACCESS_TOKEN: 1234567890
S3_SECRET_ACCESS_TOKEN: 1234567890
S3_BUCKET: plannify
```

### GCP Cloud Storage

```yaml
S3_ENDPOINT: https://storage.googleapis.com
S3_ACCESS_TOKEN: 1234567890
S3_SECRET_ACCESS_TOKEN: 1234567890
S3_BUCKET: plannify
```

### Azure Blob Storage

```yaml
S3_ENDPOINT: https://<account_name>.blob.core.windows.net
S3_ACCESS_TOKEN: 1234567890
S3_SECRET_ACCESS_TOKEN: 1234567890
S3_BUCKET: plannify
```