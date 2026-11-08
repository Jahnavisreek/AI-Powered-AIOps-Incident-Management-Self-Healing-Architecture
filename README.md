# AI-Powered-AIOps-Incident-Management-Self-Healing-Architecture
End-to-end Monitoring, Alerting, and Auto-Remediation Architecture using Prometheus, Alert-manager, Node Exporter, and Slack on AWS EC2.

# 🤖 AI-Powered AIOps Incident Management & Self-Healing Architecture

An automated infrastructure monitoring, metric aggregation, and incident-response stack deployed on AWS EC2 using Prometheus, Alertmanager, Node Exporter, and Grafana.

---

## 📐 Architecture Overview

![Architecture](architecture.png)

### Incident Workflow Lifecycle:
1. **Telemetry & Collection:** Node Exporter captures host-level compute, memory, and filesystem metrics across target Linux nodes.
2. **Dynamic Service Discovery:** Prometheus scrapes EC2 instances automatically via native AWS EC2 Service Discovery (`ec2_sd_configs`), filtering on the tag `monitor: node_server`.
3. **Alert Rule Evaluation:** Real-time PromQL expressions evaluate infrastructure conditions and trigger alerts for node downtime, high CPU, high memory, and disk saturation.
4. **Alert Routing & Notification:** Alertmanager groups notifications, inhibits duplicate noise, and dispatches rich incident summaries to Slack channels via webhooks.

---

## 📂 Repository Contents

| File | Description |
| :--- | :--- |
| `architecture.png` | Comprehensive AIOps system architecture and workflow diagram |
| `install-monitoring-stack.sh` | Automated deployment script for Prometheus, Alertmanager, Node Exporter, and Grafana |
| `node-exporter.sh` | Lightweight client agent installation script for target EC2 instances |

---

## 🚀 Deployment Guide

### 1. Provision Monitoring Host (Prometheus, Alertmanager, Grafana)

Execute this script on your central monitoring EC2 instance (Amazon Linux 2023 / RHEL):

```bash
export SLACK_WEBHOOK_URL="[https://hooks.slack.com/services/YOUR/WEBHOOK/URL](https://hooks.slack.com/services/YOUR/WEBHOOK/URL)"
chmod +x install-monitoring-stack.sh
sudo ./install-monitoring-stack.sh
