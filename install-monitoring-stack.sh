#!/bin/bash

set -e

PROM_VERSION="2.55.1"
ALERT_VERSION="0.27.0"
NODE_VERSION="1.11.1"
REGION="ap-south-1"

SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:?Please export SLACK_WEBHOOK_URL first}"

WORKDIR="/opt/monitoring"

echo "========================================="
echo " Installing Monitoring Stack"
echo "========================================="

sudo mkdir -p ${WORKDIR}
cd ${WORKDIR}

############################################
# Update OS
############################################

sudo dnf update -y

############################################
# Prometheus User
############################################

sudo useradd --no-create-home --shell /sbin/nologin prometheus || true
sudo useradd --no-create-home --shell /sbin/nologin node_exporter || true

############################################
# Prometheus
############################################

cd ${WORKDIR}

curl -LO https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz

tar -xzf prometheus-${PROM_VERSION}.linux-amd64.tar.gz

cd prometheus-${PROM_VERSION}.linux-amd64

sudo mkdir -p /etc/prometheus
sudo mkdir -p /var/lib/prometheus

sudo cp prometheus /usr/local/bin/
sudo cp promtool /usr/local/bin/

sudo cp -r consoles /etc/prometheus/
sudo cp -r console_libraries /etc/prometheus/

sudo chown -R prometheus:prometheus /etc/prometheus
sudo chown -R prometheus:prometheus /var/lib/prometheus

############################################
# Alertmanager
############################################

cd ${WORKDIR}

curl -LO https://github.com/prometheus/alertmanager/releases/download/v${ALERT_VERSION}/alertmanager-${ALERT_VERSION}.linux-amd64.tar.gz

tar -xzf alertmanager-${ALERT_VERSION}.linux-amd64.tar.gz

cd alertmanager-${ALERT_VERSION}.linux-amd64

sudo cp alertmanager /usr/local/bin/
sudo cp amtool /usr/local/bin/

sudo mkdir -p /etc/alertmanager
sudo mkdir -p /var/lib/alertmanager

############################################
# Node Exporter
############################################

cd ${WORKDIR}

curl -LO https://github.com/prometheus/node_exporter/releases/download/v${NODE_VERSION}/node_exporter-${NODE_VERSION}.linux-amd64.tar.gz

tar -xzf node_exporter-${NODE_VERSION}.linux-amd64.tar.gz

cd node_exporter-${NODE_VERSION}.linux-amd64

sudo cp node_exporter /usr/local/bin/

sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

############################################
# Alert Rules
############################################

sudo tee /etc/prometheus/alert.rules.yml > /dev/null <<'EOF'
groups:

- name: system-alerts

  rules:

  - alert: InstanceDown
    expr: up == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Instance Down"
      description: "{{ $labels.instance }} is down"

  - alert: HighCPUUsage
    expr: (100 - (avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100)) > 10
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "High CPU Usage"
      description: "{{ $labels.instance }} CPU above 80%"

  - alert: HighMemoryUsage
    expr: (1 - (node_memory_MemAvailable_bytes/node_memory_MemTotal_bytes)) * 100 > 10
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "High Memory Usage"
      description: "{{ $labels.instance }} Memory above 10%"

  - alert: HighDiskUsage
    expr: |
      (1 - (
        node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"}
        /
        node_filesystem_size_bytes{fstype!~"tmpfs|overlay"}
      )) * 100 > 10
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "High Disk Usage"
      description: "{{ $labels.instance }} Disk above 10%"	  
EOF

############################################
# Alertmanager Config
############################################

sudo tee /etc/alertmanager/alertmanager.yml > /dev/null <<EOF
global:
  resolve_timeout: 5m

route:
  receiver: slack

receivers:
- name: slack
  slack_configs:
  - api_url: '${SLACK_WEBHOOK_URL}'
    send_resolved: true
    title: '[{{ .Status | toUpper }}] {{ .CommonLabels.alertname }}'
    text: |
      Alert: {{ .CommonLabels.alertname }}
      Instance: {{ .CommonLabels.instance }}
      Severity: {{ .CommonLabels.severity }}
EOF

############################################
# Prometheus Config
############################################

sudo tee /etc/prometheus/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s

rule_files:
  - "alert.rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - localhost:9093

scrape_configs:

  - job_name: prometheus
    static_configs:
      - targets:
        - localhost:9090

  - job_name: ec2-node-exporters

    ec2_sd_configs:
      - region: ${REGION}
        port: 9100

        filters:
          - name: tag:monitor
            values:
              - node_server

    relabel_configs:

      - source_labels:
          [__meta_ec2_private_ip]

        target_label: __address__
        replacement: \$1:9100

      - source_labels:
          [__meta_ec2_tag_Name]

        target_label: instance
EOF

############################################
# Prometheus Service
############################################

sudo tee /etc/systemd/system/prometheus.service > /dev/null <<'EOF'
[Unit]
Description=Prometheus
After=network-online.target

[Service]
User=prometheus
Group=prometheus

ExecStart=/usr/local/bin/prometheus \
 --config.file=/etc/prometheus/prometheus.yml \
 --storage.tsdb.path=/var/lib/prometheus \
 --web.enable-lifecycle

Restart=always

[Install]
WantedBy=multi-user.target
EOF

############################################
# Alertmanager Service
############################################

sudo tee /etc/systemd/system/alertmanager.service > /dev/null <<'EOF'
[Unit]
Description=Alertmanager

[Service]
User=prometheus

ExecStart=/usr/local/bin/alertmanager \
 --config.file=/etc/alertmanager/alertmanager.yml \
 --storage.path=/var/lib/alertmanager

Restart=always

[Install]
WantedBy=multi-user.target
EOF

############################################
# Node Exporter Service
############################################

sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<'EOF'
[Unit]
Description=Node Exporter
After=network-online.target

[Service]
User=node_exporter

ExecStart=/usr/local/bin/node_exporter

Restart=always

[Install]
WantedBy=multi-user.target
EOF

############################################
# Grafana
############################################

sudo tee /etc/yum.repos.d/grafana.repo > /dev/null <<EOF
[grafana]
name=Grafana
baseurl=https://rpm.grafana.com
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
EOF

sudo dnf install -y grafana

############################################
# Validation
############################################

sudo /usr/local/bin/promtool check config /etc/prometheus/prometheus.yml
sudo /usr/local/bin/promtool check rules /etc/prometheus/alert.rules.yml
sudo /usr/local/bin/amtool check-config /etc/alertmanager/alertmanager.yml

############################################
# Start Services
############################################

sudo systemctl daemon-reload

sudo systemctl enable prometheus --now
sudo systemctl enable alertmanager --now
sudo systemctl enable node_exporter --now
sudo systemctl enable grafana-server --now

############################################
# Status
############################################

echo ""
echo "========================================="
echo "Installation Completed"
echo "========================================="
echo "Prometheus   : http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9090"
echo "Grafana      : http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000"
echo "Alertmanager : http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9093"
echo ""
echo "Grafana Login"
echo "Username : admin"
echo "Password : admin"
echo "========================================="
