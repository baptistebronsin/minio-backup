#!/bin/bash

# Environment variables
MINIO_ENDPOINT=${MINIO_ENDPOINT}
MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY}
MINIO_SECRET_KEY=${MINIO_SECRET_KEY}
MINIO_BUCKET=${MINIO_BUCKET}

BACKUP_DIR=${BACKUP_DIR}
BACKUP_MAX_BEFORE_DELETE=${BACKUP_MAX_BEFORE_DELETE}
BACKUP_COMPRESSION=${BACKUP_COMPRESSION}

S3_ENDPOINT=${S3_ENDPOINT}
S3_ACCESS_TOKEN=${S3_ACCESS_TOKEN}
S3_SECRET_ACCESS_TOKEN=${S3_SECRET_ACCESS_TOKEN}
S3_BUCKET=${S3_BUCKET}

# Validate environment variables
if [ -z "${MINIO_ENDPOINT}" ] || [ -z "${MINIO_ACCESS_KEY}" ] || [ -z "${MINIO_SECRET_KEY}" ] || [ -z "${MINIO_BUCKET}" ] || [ -z "${S3_ENDPOINT}" ] || [ -z "${S3_ACCESS_TOKEN}" ] || [ -z "${S3_SECRET_ACCESS_TOKEN}" ] || [ -z "${S3_BUCKET}" ]; then
    echo "Error: Missing environment variables."
    exit 1
fi

# Use personalized timezone
if [ -n "${TZ}" ]; then
  export TZ="${TZ}"
fi

# Validate BACKUP_DIR
if [ -n "${BACKUP_DIR}" ]; then
    echo "Validating BACKUP_DIR environment variable..."
    
    if [[ ! "${BACKUP_DIR}" =~ ^[a-zA-Z0-9_/-]+$ ]]; then
        echo "Error: BACKUP_DIR can only contain alphanumeric characters, underscores, slashes and hyphens."
        exit 1
    fi

    if [[ "${BACKUP_DIR}" == /* ]]; then
        echo "Warning: BACKUP_DIR must not start with a slash."
        BACKUP_DIR=$(echo "${BACKUP_DIR}" | sed 's|^/||')
    fi

    if [[ "${BACKUP_DIR}" == */ ]]; then
        echo "Warning: BACKUP_DIR must not end with a slash."
        BACKUP_DIR=$(echo "${BACKUP_DIR}" | sed 's|/$||')
    fi
fi

# Validate BACKUP_MAX_BEFORE_DELETE
if [ -n "${BACKUP_MAX_BEFORE_DELETE}" ]; then
    echo "Validating BACKUP_MAX_BEFORE_DELETE environment variable..."

    if ! [[ "${BACKUP_MAX_BEFORE_DELETE}" =~ ^[0-9]+$ ]]; then
        echo "Error: BACKUP_MAX_BEFORE_DELETE must be an integer."
        exit 1
    elif [ "${BACKUP_MAX_BEFORE_DELETE}" -lt 1 ]; then
        echo "Error: BACKUP_MAX_BEFORE_DELETE must be greater than 0."
        exit 1
    fi
fi

# Create the file name
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
# Create the container backup directory
LOCAL_BACKUP_DIR=${BACKUP_DIR:-tmp}
ABSOLUTE_BACKUP_DIR="/home/backupuser/${LOCAL_BACKUP_DIR}"
ABSOLUTE_BACKUP_FILE="${ABSOLUTE_BACKUP_DIR}/${TIMESTAMP}"

if [ -z "${BACKUP_DIR}" ]; then
    S3_BACKUP_FILE="${TIMESTAMP}"
else
    S3_BACKUP_FILE="${BACKUP_DIR}/${TIMESTAMP}"
fi

# Create the backup directory if it doesn't exist
mkdir -p "${ABSOLUTE_BACKUP_DIR}"
echo "Folder '${ABSOLUTE_BACKUP_DIR}' created."

# Configure MinIO Client
mc alias set myminio ${MINIO_ENDPOINT} ${MINIO_ACCESS_KEY} ${MINIO_SECRET_KEY}

# Save the bucket
echo "Saving bucket ${MINIO_BUCKET}..."
minio_dump_output=$(mc cp --recursive myminio/${MINIO_BUCKET} "${ABSOLUTE_BACKUP_DIR}" 2>&1)

if [ $? -ne 0 ]; then
    echo "Error: Failed to save the bucket. Details:"
    echo "${minio_dump_output}"
    exit 1
fi

echo "Successful backup in '${ABSOLUTE_BACKUP_DIR}'."

# Compress the backup
if [ -z "${BACKUP_COMPRESSION}" ]; then
    BACKUP_COMPRESSION="zip"
    echo "BACKUP_COMPRESSION not set. Defaulting to 'zip'."
fi

cd "/home/backupuser"

case "${BACKUP_COMPRESSION}" in
    gzip)
        echo "Compressing backup with gzip..."
        compress_output=$(tar -cf "${ABSOLUTE_BACKUP_FILE}.tar" "${LOCAL_BACKUP_DIR}" 2>&1)

        if [ $? -ne 0 ]; then
            echo "Error: Failed to create tar archive. Details:"
            echo "${compress_output}"
            exit 1
        fi

        compress_output=$(gzip -f "${ABSOLUTE_BACKUP_FILE}.tar" 2>&1)

        if [ $? -ne 0 ]; then
            echo "Error: Failed to compress the backup with gzip. Details:"
            echo "${compress_output}"
            exit 1
        fi

        ABSOLUTE_BACKUP_FILE="${ABSOLUTE_BACKUP_FILE}.tar.gz"
        S3_BACKUP_FILE="${S3_BACKUP_FILE}.tar.gz"
        echo "Backup compressed with gzip."
        ;;
    xz)
        echo "Compressing backup with xz..."
        compress_output=$(tar -cf "${ABSOLUTE_BACKUP_FILE}.tar" "${LOCAL_BACKUP_DIR}" 2>&1)

        if [ $? -ne 0 ]; then
            echo "Error: Failed to create tar archive. Details:"
            echo "${compress_output}"
            exit 1
        fi

        compress_output=$(xz -f "${ABSOLUTE_BACKUP_FILE}.tar" 2>&1)

        if [ $? -ne 0 ]; then
            echo "Error: Failed to compress the backup with xz. Details:"
            echo "${compress_output}"
            exit 1
        fi

        ABSOLUTE_BACKUP_FILE="${ABSOLUTE_BACKUP_FILE}.tar.xz"
        S3_BACKUP_FILE="${S3_BACKUP_FILE}.tar.xz"
        echo "Backup compressed with xz."
        ;;
    zip)
        echo "Compressing backup with zip..."
        compress_output=$(zip -r "${ABSOLUTE_BACKUP_FILE}.zip" "${LOCAL_BACKUP_DIR}" 2>&1)

        if [ $? -ne 0 ]; then
            echo "Error: Failed to compress the backup with zip. Details:"
            echo "${compress_output}"
            exit 1
        fi

        ABSOLUTE_BACKUP_FILE="${ABSOLUTE_BACKUP_FILE}.zip"
        S3_BACKUP_FILE="${S3_BACKUP_FILE}.zip"
        echo "Backup compressed with zip."
        ;;
    *)
        echo "Error: Unsupported compression method '${BACKUP_COMPRESSION}'."
        echo "Deleting local backup folder '${ABSOLUTE_BACKUP_DIR}'..."
        rm -rf "${ABSOLUTE_BACKUP_DIR}"
        exit 1
        ;;
esac

echo "Compression successful '${S3_BACKUP_FILE}'."

# Upload to S3
echo "Uploading to S3..."
s3cmd_put_output=$(s3cmd put "${ABSOLUTE_BACKUP_FILE}" s3://${S3_BUCKET}/${S3_BACKUP_FILE} \
    --access_key=${S3_ACCESS_TOKEN} \
    --secret_key=${S3_SECRET_ACCESS_TOKEN} \
    --host=${S3_ENDPOINT} \
    --host-bucket=${S3_ENDPOINT} 2>&1)

if [ $? -ne 0 ]; then
    echo "Error: Failed to upload to S3. Details :"
    echo "${s3cmd_put_output}"
    exit 1
fi

echo "Upload to S3 successful."

if [ -z "${BACKUP_MAX_BEFORE_DELETE}" ]; then
  echo "No limit on the number of backups to keep."
else
    echo "Deleting old backups..."
    BACKUP_LIST=$(s3cmd ls s3://${S3_BUCKET}/${BACKUP_DIR}/ \
        --access_key=${S3_ACCESS_TOKEN} \
        --secret_key=${S3_SECRET_ACCESS_TOKEN} \
        --host=${S3_ENDPOINT} \
        --host-bucket=${S3_ENDPOINT} | sort -r | awk '{print $4}' | tail -n +$((BACKUP_MAX_BEFORE_DELETE + 1)))

    for FILE_PATH in $BACKUP_LIST; do
        echo "Deleting ${FILE_PATH}..."
        s3cmd_del_output=$(s3cmd del ${FILE_PATH} \
        --access_key=${S3_ACCESS_TOKEN} \
        --secret_key=${S3_SECRET_ACCESS_TOKEN} \
        --host=${S3_ENDPOINT} \
        --host-bucket=${S3_ENDPOINT} 2>&1)

        if [ $? -ne 0 ]; then
            echo "Error: Failed to delete '${FILE_PATH}'. Details:"
            echo "${s3cmd_del_output}"
        else
            echo "Successfully deleted '${FILE_PATH}'."
        fi
    done

    echo "Old backups have been sorted."
fi

echo "Cleaning up local backup folder '${ABSOLUTE_BACKUP_DIR}'..."
rm -rf "${ABSOLUTE_BACKUP_DIR}"
