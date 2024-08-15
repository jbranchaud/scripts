# scripts

## Harvest

### Typical commands

See hours for current month, formatted by `jq`:

```bash
$ ruby harvest/detailed_harvest_summary.rb --current-month --client ClientCorp | jq
```

See hours for previous month, formatted by `jq`:

```bash
$ ruby harvest/detailed_harvest_summary.rb --previous-month --client ClientCorp | jq
```

See hours for two months ago, formatted by `jq`:

```bash
$ ruby harvest/detailed_harvest_summary.rb --months-ago 2 --client ClientCorp | jq
```

See count of hours across all clients for current week:

```bash
$ ruby harvest/harvest_hours.rb
```
