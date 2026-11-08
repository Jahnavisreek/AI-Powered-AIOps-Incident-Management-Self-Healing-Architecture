# AI-Powered-AIOps-Incident-Management-Self-Healing-Architecture
End-to-end Monitoring, Alerting, and Auto-Remediation Architecture using Prometheus, Alert-manager, Node Exporter, and Slack on AWS EC2.

# 🤖 AI-Powered AIOps Incident Management & Self-Healing Architecture

An automated infrastructure monitoring, metric aggregation, and incident-response stack deployed on AWS EC2 using Prometheus, Alertmanager, Node Exporter, and Grafana.

---

## 📐 Architecture Overview

<img width="1536" height="1024" alt="Architecture" src="https://github.com/user-attachments/assets/1b00ea84-76b5-4ba8-8677-23e8868ced1f" />


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
---

## 🏷️ AWS EC2 Service Discovery Configuration

To allow Prometheus to automatically discover and monitor target EC2 instances without manual configuration, ensure each target instance has the following AWS tag applied:

| Tag Key | Tag Value | Purpose |
| :--- | :--- | :--- |
| `monitor` | `node_server` | Target filter for `ec2_sd_configs` |

> **Note:** Ensure the IAM role attached to your Prometheus EC2 instance includes the `ec2:DescribeInstances` policy permission so it can query instances across the region.

---

## ⚙️ Configured PromQL Alert Rules

The monitoring engine evaluates the following metric conditions and routes incident notifications:

| Alert Name | PromQL Expression | Evaluation Duration | Severity | Triggered Action |
| :--- | :--- | :--- | :--- | :--- |
| **InstanceDown** | `up == 0` | `> 1 min` | `Critical` | Pushes immediate critical downtime alert to Slack |
| **HighCPUUsage** | `(100 - (avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100)) > 80` | `> 2 mins` | `Warning` | Logs runaway process telemetry and alerts Slack |
| **HighMemoryUsage** | `(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 80` | `> 2 mins` | `Warning` | Alerts Slack and captures active memory metrics |
| **HighDiskUsage** | `(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100 > 80` | `> 2 mins` | `Warning` | Flags storage threshold and recommends cache cleanup |
