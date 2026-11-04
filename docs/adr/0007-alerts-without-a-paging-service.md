# 0007. Alerts go to email and Slack, without a paging service

Status: accepted

## Context

PagerDuty or Grafana OnCall add schedules, escalation, and phone alerts. They
need an outside account and someone on call.

## Decision

Alertmanager and CloudWatch alarms publish to a regional SNS topic with an
email subscription, and Alertmanager also posts warnings and critical alerts to
Slack when enabled. Every alert links to a runbook.

## Consequences

Nobody is woken up; alerts are seen when someone reads email or Slack. Adding a
paging service later is one more Alertmanager receiver and one more SNS
subscription.
