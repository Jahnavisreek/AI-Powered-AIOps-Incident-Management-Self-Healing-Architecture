# AI-Powered-AIOps-Incident-Management-Self-Healing-Architecture
End-to-end Monitoring, Alerting, and Auto-Remediation Architecture using Prometheus, Alert-manager, Node Exporter, and Slack on AWS EC2.

# 🤖 AI-Powered AIOps Incident Management & Self-Healing Architecture

An automated infrastructure monitoring, metric aggregation, and incident-response stack deployed on AWS EC2 using Prometheus, Alertmanager, Node Exporter, and Grafana.

---

## 📐 Architecture Overview

### Detailed Workflow Stages:

1. **Metric Exposition & Continuous Scraping**
   * **Node Exporter** collects host telemetry (CPU idle time, available RAM, disk IO, and filesystem thresholds) on target EC2 nodes.
   * **Prometheus** polls targets every 15 seconds using dynamic AWS EC2 Service Discovery, identifying nodes tagged with `monitor: node_server`.

2. **Threshold Evaluation & Alert State Transition**
   * When conditions cross predefined thresholds (e.g., node down or CPU > 80%), Prometheus enters the **`Pending`** state.
   * If the condition persists longer than the rule duration (1–2 minutes), the state escalates to **`Firing`**.

3. **Intelligent Alert Grouping & Routing**
   * Firing alerts are dispatched to **Alertmanager** at `localhost:9093`.
   * Alertmanager de-duplicates alerts, clusters co-occurring alarms from the same instance, and suppresses flapping events using a 5-minute resolve timeout.

4. **Telemetry Dispatch & Diagnostics**
   * Alerts route through the configured webhook endpoint directly to the incident operations channel.
   * Incident payloads contain exact alert labels, instance identifiers, and severity classifications (`critical` / `warning`).

5. **ChatOps Notification & Incident Verification**
   * The team receives formatted, rich alert cards in **Slack** detailing the root issue.
   * When metric values drop back below warning thresholds, Prometheus and Alertmanager automatically send a `[RESOLVED]` notification.

## 🏗️ Service Architecture & Component Roles

The platform is structured into distinct, modular service layers that handle metric collection, rules processing, routing, and notifications:

| Service / Component | Layer | Port | Runtime Role & Functionality |
| :--- | :--- | :--- | :--- |
| **Node Exporter** | Data Collection | `9100` | Lightweight system agent installed on target Linux/EC2 nodes. Collects and exposes raw kernel and OS metrics (CPU usage, RAM allocation, disk filesystem utilization, network I/O) as plain-text scrape targets. |
| **Prometheus** | Monitoring & Alerting | `9090` | Time-series database and core monitoring engine. Performs automated AWS EC2 service discovery (`ec2_sd_configs`), scrapes Node Exporter metrics every 15s, stores telemetry, and continuously evaluates PromQL alert rule thresholds. |
| **Alertmanager** | Alert Routing & Deduplication | `9093` | Alert lifecycle management. Ingests raw firing alerts from Prometheus, deduplicates repeated alarms, groups incidents by instance/label, enforces a 5-minute resolve timeout, and dispatches JSON payloads to the configured webhook. |
| **Grafana** | Visualization & Observability | `3000` | Operational dashboard UI. Connects to Prometheus as a primary data source to visualize compute utilization, active instance count, and historical telemetry trends. |
| **Slack Integration** | Incident & ChatOps | Webhook (HTTPS) | Incident receiver endpoint. Parses incoming Alertmanager payloads and posts formatted incident notifications directly to the operations channel with alert status, severity, and host tags. |

---

### How the Services Interact (Communication Flow):

1. **Target Node Exporter (`:9100`) $\rightarrow$ Prometheus (`:9090`):**
   Prometheus queries the AWS EC2 API to find servers with the tag `monitor: node_server`, then initiates an HTTP `GET /metrics` request every 15 seconds to pull hardware data.

2. **Prometheus (`:9090`) $\rightarrow$ Alertmanager (`:9093`):**
   When a metric threshold fails (e.g., CPU > 80% for 2 minutes), Prometheus creates an alert state (`Pending` $\rightarrow$ `Firing`) and forwards an alert event to Alertmanager over port 9093.

3. **Alertmanager (`:9093`) $\rightarrow$ External Slack Webhook:**
   Alertmanager groups related alerts to prevent notification spam, matches the route (`receiver: slack`), and sends an HTTPS POST request containing incident summary details and severity labels.

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
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
chmod +x install-monitoring-stack.sh
sudo ./install-monitoring-stack.sh
```

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

