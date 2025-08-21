# Dashboard Restore Instructions

## To restore a specific dashboard:
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -u admin:admin \
  -d @grafana-backups/dashboards/{DASHBOARD_UID}.json \
  http://54.234.120.173:10001/api/dashboards/db
```

## To restore all dashboards:
```bash
for file in grafana-backups/dashboards/*.json; do
  curl -X POST \
    -H "Content-Type: application/json" \
    -u admin:admin \
    -d @"$file" \
    http://54.234.120.173:10001/api/dashboards/db
  echo "Restored: $(basename "$file")"
done
```
