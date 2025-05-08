---
title: "Azure BCDR Review – Turning Inherited Cloud Infrastructure into a Resilient Recovery Strategy"
date:
  created: 2025-05-08
  updated: 2025-05-08
authors:
  - matthew
description: "A high-level walkthrough of how to assess and formalise a business continuity and disaster recovery (BCDR) posture in Azure, following an inherited landing zone handover."
categories:
  - Azure
  - BCDR
  - Cloud Architecture
tags:
  - azure
  - bcdr
  - site recovery
  - disaster recovery
  - cloud strategy
---

# ⚙️ Azure BCDR Review – Turning Inherited Cloud Infrastructure into a Resilient Recovery Strategy

When we inherited our Azure estate from a previous MSP, some of the key technical components were already in place — ASR was configured for a number of workloads, and backups had been partially implemented across the environment.

What we didn’t inherit was a documented or validated BCDR strategy.

There were no formal recovery plans defined in ASR, no clear failover sequences, and no evidence that a regional outage scenario had ever been modelled or tested. The building blocks were there — but there was no framework tying them together into a usable or supportable recovery posture.

This post shares how I approached the challenge of assessing and strengthening our Azure BCDR readiness. It's not about starting from scratch — it's about applying structure, logic, and realism to an environment that had the right intentions but lacked operational clarity.

Whether you're stepping into a similar setup or planning your first formal DR review, I hope this provides a practical and relatable blueprint.

---

## 🎯 Where We Started: Technical Foundations, Operational Gaps

We weren’t starting from zero — but we weren’t in a position to confidently recover the environment either.

**What we found:**

- 🟢 ASR replication was partially implemented  
- 🟡 VM backups were present but inconsistent  
- ❌ No Recovery Plans existed in ASR  
- ❌ No test failovers had ever been performed  
- ⚠️ No documented RTO/RPO targets  
- ❓ DNS and Private Endpoints weren’t accounted for in DR  
- 🔒 Networking had not been reviewed for failover scenarios  
- 🚫 No capacity reservations had been made

This review was the first step in understanding whether our DR setup could work in practice — not just in theory.

---

## 🛡️ 1️⃣ Workload Protection: What’s Covered, What’s Not

Some workloads were actively replicated via ASR. Others were only backed up. Some had both, a few had neither. There was no documented logic to explain why.

Workload protection appeared to be driven by convenience or historical context — not by business impact or recovery priority.

What we needed was a structured tiering model:

- 🧠 Which workloads are mission-critical?
- ⏱️ Which ones can tolerate extended recovery times?
- 📊 What RTOs and RPOs are actually achievable?

This became the foundation for everything else.

---

## 🧩 2️⃣ The Missing Operational Layer

We had technical coverage — but no operational recovery strategy.

There were no Recovery Plans in ASR. No sequencing, no post-failover validation, and no scripts or automation.

In the absence of structure, recovery would be entirely manual — relying on individual knowledge, assumptions, and good luck during a critical event.

Codifying dependencies, failover order, and recovery steps became a priority.

---

## 🌐 3️⃣ DNS, Identity and Private Endpoint Blind Spots

DNS and authentication are easy to overlook — until they break.

Our name resolution relied on internal DNS via AD-integrated zones, with no failover logic for internal record switching. No private DNS zones were in place.

Private Endpoints were widely used, but all existed in the primary region. In a DR scenario, they would become unreachable.

Identity was regionally redundant, but untested and not AZ-aware.

We needed to promote DNS, identity, and PE routing to first-class DR concerns.

---

## 💾 4️⃣ Storage and Data Access Risk

Azure Storage backed a range of services — from SFTP and app data to file shares and diagnostics.

Replication strategies varied (LRS, RA-GRS, ZRS) with no consistent logic or documentation. Critical storage accounts weren’t aligned with workload tiering.

Some workloads used Azure Files and Azure File Sync, but without defined mount procedures or recovery checks.

In short: compute could come back, but data availability wasn’t assured.

---

## 🔌 5️⃣ The Networking Piece (And Why It Matters More Than People Think)

NSGs, UDRs, custom routing, and SD-WAN all played a part in how traffic flowed.

But in DR, assumptions break quickly.

There was no documentation of network flow in the DR region, and no validation of inter-VM or service-to-service reachability post-failover.

Some services — like App Gateways, Internal Load Balancers, and Private Endpoints — were region-bound and would require re-deployment or manual intervention.

Networking wasn’t the background layer — it was core to recoverability.

---

## 📦 6️⃣ Capacity Risk: When DR Isn’t Guaranteed

VM replication is only half the story. The other half is whether those VMs can actually start during a DR event.

Azure doesn’t guarantee regional capacity unless you've pre-purchased it.

In our case, **no capacity reservations** had been made. That meant no assurance that our Tier 0 or Tier 1 workloads could even boot if demand spiked during a region-wide outage.

This is a quiet but critical risk — and one worth addressing early.

---

## ✅ Conclusion: From Discovery to Direction

This review wasn’t about proving whether DR was in place — it was about understanding whether it would actually work.

The tooling was present. The protection was partial. The process was missing.

By mapping out what was covered, where the gaps were, and how recovery would actually unfold, we created a baseline that gave us clarity and control.

---

## 📘 Coming Next: Documenting the Plan

In the next post, I’ll walk through how I formalised the review into a structured BCDR posture document — including:

- 🧱 Mapping workloads by tier and impact  
- ⏳ Defining current vs target RTO/RPO  
- 🛠️ Highlighting gaps in automation, DNS, storage, and capacity  
- 🧭 Building a recovery plan roadmap  
- ⚖️ Framing cost vs risk for stakeholder alignment  

If you're facing a similar situation — whether you're inheriting someone else's cloud estate or building DR into a growing environment — I hope this series helps bring structure to the complexity.

Let me know if you'd find it useful to share templates or walkthroughs in the next post.

---
