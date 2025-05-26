Assignment: Enhanced JSON Log Analytics System
Objective: Extend your JSON log processing system with advanced analytics and alerting capabilities, simulating real-world production requirements.
Your Mission
You've successfully built a basic JSON log processing system. Now, imagine you're working at a fast-growing startup where the CEO wants to understand user behavior patterns and detect system issues automatically. Your task is to enhance the system with analytics and alerting features.
Requirements
Part 1: Advanced Log Analytics (30 points)

Metrics Aggregation: Track and display metrics like:

Average response times per service
Request count per user (if user_id present)
Error rate trends over time (last 5 minutes)
Most active services by log volume


Time-Series Data: Store metrics in 1-minute buckets and provide an API endpoint that returns time-series data for the last hour.

Part 2: Smart Alerting System (25 points)

Error Rate Alert: Trigger alerts when error rate exceeds 10% in any 1-minute window
Service Down Detection: Alert when a service hasn't sent logs for more than 2 minutes
High Volume Alert: Alert when log volume exceeds 100 logs/minute for any service

Part 3: Enhanced Web Dashboard (25 points)

Real-time Charts: Add line charts showing error rates and log volume over time
Alert Panel: Display active alerts with colors (red for critical, yellow for warning)
Service Health Matrix: Show grid of all services with health status indicators

Part 4: Configuration and Extensibility (20 points)

Configuration File: Create a YAML configuration file for alert thresholds, server settings, and schema paths
Plugin System: Allow custom alert handlers (email, Slack, webhook)

Deliverables

Enhanced Source Code: Modified and new Python files
Configuration File: config.yaml with all settings
Updated Web Interface: Enhanced dashboard with new features
Documentation: README explaining new features and how to configure them
Demo Script: Script that demonstrates all new features working

Acceptance Criteria

System processes 50+ logs/second without performance degradation
Alerts trigger within 5 seconds of threshold breach
Web dashboard updates in real-time (< 2 second refresh)
All new features have unit tests with >80% coverage
System gracefully handles configuration errors
