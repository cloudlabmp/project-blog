---
title: "Azure BCDR – How I Turned a DR Review into a Strategic Recovery Plan"
date:
  created: 2025-05-08
  updated: 2025-05-08
authors:
  - matthew
description: "Part 2 of a real-world Azure BCDR journey: how I transformed a discovery-led review into a structured recovery plan with prioritised actions and stakeholder alignment."
categories:
  - Azure
  - BCDR
  - Cloud Architecture
tags:
  - azure
  - bcdr
  - disaster recovery
  - site recovery
  - strategy
---

# 🧾 Azure BCDR – How I Turned a DR Review into a Strategic Recovery Plan

In [Part 1](#) of this series, I shared how we reviewed our Azure BCDR posture after inheriting a partially implemented cloud estate. The findings were clear: while the right tools were in place, the operational side of disaster recovery hadn’t been addressed.

There were no test failovers, no documented Recovery Plans, no automation, and several blind spots in DNS, storage, and private access.

This post outlines how I took that review and turned it into a practical recovery strategy — one that we could share internally, align with our CTO, and use as a foundation for further work with our support partner.

To provide context, our estate is deployed primarily in the **UK South** Azure region, with **UK West** serving as the designated DR target region.

It’s not a template — it’s a repeatable, real-world approach to structuring a BCDR plan when you’re starting from inherited infrastructure, not a clean slate.

---

## 🧭 1. Why Documenting the Plan Matters

Most cloud teams can identify issues. Fewer take the time to formalise the findings in a way that supports action and alignment.

Documenting our BCDR posture gave us three things:

- 🧠 Clarity — a shared understanding of what’s protected and what isn’t  
- 🔦 Visibility — a way to surface risk and prioritise fixes  
- 🎯 Direction — a set of realistic, cost-aware next steps  

We weren’t trying to solve every problem at once. The goal was to define a usable plan we could act on, iterate, and eventually test — all while making sure that effort was focused on the right areas.

---

## 🧱 2. Starting the Document

I structured the document to speak to both **technical stakeholders** and **senior leadership**. It needed to balance operational context with strategic risk.

### ✍️ Core sections included

- **Executive Summary** – what the document is, why it matters  
- **Maturity Snapshot** – a simple traffic-light view of current vs target posture  
- **Workload Overview** – what’s in scope and what’s protected  
- **Recovery Objectives** – realistic RPO/RTO targets by tier  
- **Gaps and Risks** – the areas most likely to cause DR failure  
- **Recommendations** – prioritised, actionable, and cost-aware  
- **Next Steps** – what we can handle internally, and what goes to the MSP

Each section followed the same principle: clear, honest, and focused on action. No fluff, no overstatements — just a straightforward review of where we stood and what needed doing.

---

## 🧩 3. Defining the Current State

Before we could plan improvements, we had to document what actually existed. This wasn’t about assumptions — it was about capturing the **real configuration and coverage** in Azure.

### 🗂️ Workload Inventory

We started by categorising all VMs and services:

- Domain controllers
- Application servers (web/API/backend)
- SQL Managed Instances
- Infrastructure services (file, render, schedulers)
- Management and monitoring VMs

Each workload was mapped by **criticality** and **recovery priority** — not just by type.

### 🛡️ Protection Levels

For each workload, we recorded:

- ✅ Whether it was protected by ASR
- 🔁 Whether it was backed up only
- 🚫 Whether it had no protection (with justification)

We also reviewed the **geographic layout** — e.g. which services were replicated into UK West, and which existed only in UK South.

### 🧠 Supporting Services

Beyond the VMs, we looked at:

- Identity services (AD, domain controllers, replication health)
- DNS architecture (AD-integrated zones, private DNS zones)
- Private Endpoints and their region-specific availability
- Storage account replication types (LRS, RA-GRS, ZRS)
- Network security and routing configurations in DR

The aim wasn’t to build a full asset inventory — just to gather enough visibility to start making risk-based decisions about what mattered, and what was missing.

---

## ⏱️ 4. Setting Recovery Objectives

Once the current state was mapped, the next step was to define what “recovery” should actually look like — in terms that could be communicated, challenged, and agreed.

We focused on two key metrics:

- **RTO** (Recovery Time Objective): How long can this system be offline before we see significant operational impact?
- **RPO** (Recovery Point Objective): How much data loss is acceptable in a worst-case failover?

These weren’t guessed or copied from a template. We worked with realistic assumptions based on our tooling, team capability, and criticality of the services.

### 📊 Tiered Recovery Model

Each workload was assigned to one of four tiers:

| Tier        | Description                                  |
|-------------|----------------------------------------------|
| Tier 0      | Core infrastructure (identity, DNS, routing) |
| Tier 1      | Mission-critical production workloads         |
| Tier 2      | Important, but not time-sensitive services    |
| SQL MI      | Treated separately due to its PaaS nature     |

We then applied RTO and RPO targets based on what we could achieve today vs what we aim to reach with improvements.

### 🔥 Heatmap Example

| Workload Tier     | RPO (Current) | RTO (Current) | RPO (Optimised) | RTO (Optimised) |
|-------------------|---------------|---------------|------------------|------------------|
| Tier 0 – Identity | 5 min         | 60 min        | 5 min            | 30 min           |
| Tier 1 – Prod     | 5 min         | 360 min       | 5 min            | 60 min           |
| Tier 2 – Non-Crit | 1440 min      | 1440 min      | 60 min           | 240 min          |
| SQL MI            | 0 min         | 60 min        | 0 min            | 30 min           |

---

## 🚧 5. Highlighting Gaps and Risks

With recovery objectives defined, the gaps became much easier to identify — and to prioritise.

We weren’t trying to protect everything equally. The goal was to focus attention on the areas that introduced the **highest risk to recovery** if left unresolved.

### ⚠️ What We Flagged

- ❌ No test failovers had ever been performed  
- ❌ No Recovery Plans existed  
- 🌐 Public-facing infrastructure only existed in one region  
- 🔒 Private Endpoints lacked DR equivalents  
- 🧭 DNS failover was manual or undefined  
- 💾 Storage accounts had inconsistent replication logic  
- 🚫 No capacity reservations existed for critical VM SKUs  

Each gap was documented with its impact, priority, and remediation options.

---

## 🛠️ 6. Strategic Recommendations

We split our recommendations into what we could handle internally, and what would require input from our MSP or further investment.

### 📌 Internal Actions

- Build and test Recovery Plans for Tier 0 and Tier 1 workloads  
- Improve DNS failover scripting  
- Review VM tags to reflect criticality and protection state  
- Create sequencing logic for application groups  
- Align NSGs and UDRs in DR with production  

### 🤝 MSP-Led or Partner Support

- Duplicate App Gateways / ILBs in UK West  
- Implement Private DNS Zones  
- Review and implement capacity reservations  
- Test runbook-driven recovery automation  
- Conduct structured test failovers across service groups  

---

## 📅 7. Making It Actionable

A plan needs ownership and timelines. We assigned tasks by role and defined short-, medium-, and long-term priorities using a simple planning table.

We treat the BCDR document as a **living artefact** — updated quarterly, tied to change control, and used to guide internal work and partner collaboration.

---

## 🔚 8. Closing Reflections

The original goal wasn’t to build a perfect DR solution — it was to understand where we stood, make recovery realistic, and document a plan that would hold up when we needed it most.

We inherited a functional technical foundation — but needed to formalise and validate it as part of a resilient DR posture.

By documenting the estate, defining recovery objectives, and identifying where the real risks were, we turned a passive DR posture into something we could act on. We gave stakeholders clarity. We gave the support partner direction. And we gave ourselves a roadmap.

---

## 🔜 What’s Next

In the next part of this series, I’ll walk through how we executed the plan:

- Building and testing our first Recovery Plan  
- Improving ASR coverage and validation  
- Running our first failover drill  
- Reviewing results and updating the heatmap  

---

If you're stepping into an inherited cloud environment or starting your first structured DR review, I hope this gives you a practical view of what’s involved — and what’s achievable without overcomplicating the process.

Let me know if you'd like to see templates or report structures from this process in a future post.

---
