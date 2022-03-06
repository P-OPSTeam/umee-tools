global:
  scrape_interval: 10s
  scrape_timeout: 3s
  evaluation_interval: 5s

# Rules and alerts are read from the specified file(s)
rule_files:
  - rules/alert.rules.yaml
  - rules/umee.rules.yaml

# Alerting specifies settings related to the Alertmanager
alerting:
  alertmanagers:
    - static_configs:
      - targets:
        # Alertmanager's default port is 9093
        - alertmanager:9093

scrape_configs:
  - job_name: Umee
    static_configs:
      - targets: ['PUBLIC_IP:26660']

  - job_name: prometheus
    static_configs:
      - targets: ['localhost:9090','cadvisor:8080','node-exporter:9100']
