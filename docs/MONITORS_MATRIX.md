# Monitors Matrix

Quick reference for each monitor: inputs, outputs, and common actions.

| Monitor | Config inputs | Output highlights | Common actions |
| --- | --- | --- | --- |
| preflight_check | none | dependency/ssh readiness (SKIP/WARN) | install missing tools, verify ssh, run `linux-maint check` |
| config_validate | linux-maint.conf, conf.d/*.conf | config format/duplicate key warnings | fix invalid lines, remove duplicates |
| health_monitor | none | CPU/mem/disk/load summary | investigate resource saturation |
| filesystem_readonly_monitor | none | RO filesystem detection | remount rw, fix storage issues |
| resource_monitor | none | top CPU/mem offenders | restart/reconfigure offenders |
| inode_monitor | none | inode usage | clean up inodes / log rotation |
| disk_trend_monitor | none | disk growth trend | investigate growth, increase capacity |
| network_monitor | network_targets.txt | reachability/latency checks | fix DNS/firewall/routes |
| service_monitor | services.txt | systemd service status | start/enable failing services |
| timer_monitor | none | systemd timer health | enable/start timers |
| last_run_age_monitor | none | last run age | check cron/systemd timer |
| ntp_drift_monitor | none | NTP drift | fix time sync |
| patch_monitor | none | pending updates | apply patch workflow |
| storage_health_monitor | none | SMART/storage health | replace failing disks |
| kernel_events_monitor | none | kernel errors/oom | review dmesg/journal |
| log_spike_monitor | none | log spikes | inspect noisy services |
| cert_monitor | certs.txt | certificate expiry | renew certs |
| nfs_mount_monitor | none | NFS mount health | fix mount/export |
| ports_baseline_monitor | ports_baseline.txt | unexpected open ports | investigate, update baseline |
| config_drift_monitor | config_paths.txt | file drift vs baseline | update baseline or remediate |
| user_monitor | baseline_users.txt, baseline_sudoers.txt | user/sudoers drift | update baseline or remediate |
| backup_check | backup_targets.csv | backup freshness | fix backup job |
| inventory_export | none | inventory snapshot | review inventory output |
