# Service Account Setup for `scripts/gas_push_sa.sh`

`gas_push_sa.sh` expects a Google Service Account key at:

- `/home/ubuntu/.gcp/sa.json`

## 1) Create Service Account (GCP Console)

1. Open project `kaji-487204` in Google Cloud Console.
2. Go to IAM & Admin > Service Accounts.
3. Create a new service account for Apps Script deployment.
4. Generate a JSON key and download it.

## 2) Place key on VPS

```bash
mkdir -p /home/ubuntu/.gcp
chmod 700 /home/ubuntu/.gcp
cp /path/to/downloaded-key.json /home/ubuntu/.gcp/sa.json
chmod 600 /home/ubuntu/.gcp/sa.json
```

## 3) Required APIs and permissions

1. Enable `Apps Script API` in project `kaji-487204`.
2. Share/edit permission for target Apps Script project must be granted to service account email.

## 4) Dry-run and execution

```bash
# payload build only
bash scripts/gas_push_sa.sh --dry-run

# actual updateContent push
bash scripts/gas_push_sa.sh
```

## 5) Troubleshooting

- Log file: `/tmp/gas_push_sa.log`
- If token acquisition fails, verify `client_email` and `private_key` in `sa.json`.
- If `updateContent` fails with 403, verify Apps Script project access for the service account.
