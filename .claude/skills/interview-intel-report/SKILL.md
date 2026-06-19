---
name: interview-intel-report
description: Generate a comprehensive, preparation brief for a job interview. Use when the user is preparing for a job interview and wants a data-driven business intelligence report on a company and role — including company background, financials, security posture, and tailored talking points. Trigger when the user provides a company name, position title, and/or resume and asks for interview prep, an "intel report", a company briefing, or research before an interview.
---

# Interview Intel Report

## Purpose

Produce a comprehensive, data-driven interview-preparation briefing that combines the
user's provided materials (company, role, job description, resume) with Open Source
Intelligence (OSINT) research into reputable public sources. The deliverable is a single
Markdown report that follows the exact framework defined below.

## Persona

Adopt the persona of an OSINT and Corporate Intelligence Analyst: skilled at data
aggregation, talent-acquisition analysis, and synthesizing publicly available information
into actionable insights for the candidate.

## Step 1 — Gather required inputs

Confirm you have the following before researching. If any of the first two are missing,
ask the user for them. The rest are optional but improve the report.

- **Company Name** (required)
- **Position Title** (required)
- **Company Website / URL** (optional but recommended)
- **Job Description** — pasted text, attached file, or URL (optional)
- **Resume** — attached `.pdf`, `.docx`, or `.txt` (optional; required only for the
  "Talking Points" section). If provided, read it with the Read tool and use it to tailor
  the alignment talking points.

If the user has not provided a job description or resume, proceed with the rest of the
report and note that the relevant sections are limited by missing inputs.

## Step 2 — Research

Use `WebSearch` and `WebFetch` to research the company. Follow these rules strictly:

- **Reputable sources only.** Use authoritative sources: official company filings
  (SEC EDGAR), the company's own website, major financial news outlets, and established
  business-data providers. Do not rely on low-quality or unverifiable sources.
- **Hyperlink every reference.** Embed direct hyperlinks inline in the text, e.g.
  "According to their recent [10-K filing](URL)...". Every factual claim drawn from
  research should carry a link to its source.
- **Handle missing information with `?`.** For any field that cannot be answered from
  reputable, publicly available sources, output a single question mark (`?`). Do **not**
  speculate, and do **not** write phrases like "Information Not Publicly Available."
  (Exception: a few fields below specify `N/A` or a specific "not found" sentence — use
  those where indicated.)
- **Public companies:** look up filings on SEC EDGAR and read the most recent 8-K and
  10-K reports as instructed in the framework.
- **Data-provider profiles:** search RocketReach, UpLead, ZoomInfo, and Crunchbase for the
  company profile page and link it; if no profile exists, output `N/A`.

## Step 3 — Generate the report

Populate the framework below **exactly**. Output requirements:

- Markdown format.
- Use `#` (H1) and `##` (H2) headers for readability.
- Where the framework calls for a table or a chart/graph, produce a Markdown table; for a
  financial-performance chart, render the data as a Markdown table of values per year (and
  describe the trend) since charts cannot be embedded in Markdown — if data is unavailable,
  output `?`.

## Step 4 — Quality control

Before delivering, double-check:

- Accuracy and truthfulness of every claim.
- That every reference link is present, correct, and points to the cited source.
- That unanswerable fields use `?` (or `N/A`/the specified sentence) rather than
  speculation.

---

## Report Generation Framework

Produce the report using this structure verbatim (substituting the actual company name and
position title).

```markdown
# Interview Preparation Brief: [Company Name]

## Job Description
Concise summary of the core responsibilities and objectives of the [Position Title] role.

## Desired Skills
The top 5–7 most critical skills and qualifications required for this position (from the job description).

## Position History
- Catalyst behind this job opportunity? Is an existing person leaving?
- Is a project or company initiative requiring this role?
- (If no reliable information is available, put `?`)

## Needs / Projects
- The top 3 projects for this role within the company.
- (If no reliable information is available, put `?`)

# About the Company

## About
- **RocketReach Profile:** link to the company profile on https://rocketreach.co, or `N/A`.
- **UpLead Profile:** link to the company profile on https://www.uplead.com, or `N/A`.
- **ZoomInfo Profile:** link to the company profile on https://www.zoominfo.com, or `N/A`.
- **Crunchbase Profile:** link to the company profile on https://www.crunchbase.com, or `N/A`.
- **Company Overview:** high-level summary of the company, its history, and its evolution.
- **Culture:** high-level sampling of company-culture temperature from https://glassdoor.com, including recent (past 12–18 months) Glassdoor reviews.

## Company Profile Summary
A profile table for the company (company name, industry, founded, HQ, employees, ownership, website, etc.).

## Mission, Vision & Values
- **Niche:** the company's specific operating niche.
- **Mission:** the company's stated mission or purpose.
- **Values:** the company's core values.

# Financial & Market Position

## Revenue & Ownership
- **Estimated Revenue:** most recent estimated annual revenue.
- **Ownership Status:** Privately held or Publicly Traded.

## Public Company Financial Performance
(Complete only if the company is Publicly Traded.)
- **SEC Profile:** link to the company profile on https://www.sec.gov/search-filings, or `N/A`.
- **SEC 8-K Reports:** read the 2 most recent 8-K reports; provide summary analysis, key findings, and interview-relevant highlights.
- **SEC 10-K Reports:** read the 2 most recent 10-K reports; provide summary analysis, key findings, and interview-relevant highlights.
- **Financial Performance Analysis:** a table of revenue or EBITDA over the past 4 years with a trend description; if unavailable, `?`.

## Product / Services
The main products or services the company offers.

## Markets
- **Target Industries:**
- **Target Markets:** (geographic or demographic)

## Customer Profiles
- **Target Customer Profiles:**

# Company Footprint

## Sites
- **# Sites / Offices:** how many offices, and where.
- **Company Headquarters:** location.
- **Company Subsidiaries:** subsidiaries owned, or `No`.

## Size
- **# Employees:** current estimated number of employees.
- **# Customers:** current estimated number of customers.

## M&A
Acquisitions in the last 3–5 years. If any, produce a table (Target, Date, Value, Rationale). If none, state "No recent M&A activity found."

## Departments
All known operating departments of the company. If no reliable information is available, `?`.

# Technology & Security

## IT / Infrastructure
- **Infrastructure:** technology infrastructure used (e.g., AWS, Azure, GCP).
- **Endpoints:** does the company provide company-owned endpoints (desktops/laptops)? If yes, estimated total quantity.

## Development
- **SSDLC:** does the company practice Secure Software Development Lifecycle practices?

## Compliance
- **Compliance Frameworks:** security frameworks complied with (e.g., ISO 27001, SOC 2).
- **Regulatory Frameworks:** regulations complied with (e.g., GDPR, FedRAMP).
- **Trust Center:** does the company have a Security Trust Center?

## Security
- **Cyber Maturity:** current cyber-maturity level assessed against NIST CSF or CIS CSC.
- **Defense in Depth:** security tools used to practice Defense in Depth.

## Data
- **Data Types:** data types the company stores, processes, or is exposed to.
- **Data Controller / Processor:** is the company a Data Controller or Processor?

## Privacy
- **Privacy Program:** does the company have a privacy program complying with regulations (e.g., GDPR, CCPA)?

## Data Breaches
Publicly reported data breaches. If any, summarize what happened, how attackers gained access, and the impact (data exposed, financial cost, regulatory fines). If none found in reputable sources, state "No publicly reported data breaches found."

## Exposed Risk
- Full list of publicly published CVEs affecting the company's assets or public infrastructure.
- Full list of public internet scans affecting the company's assets or public infrastructure.
- List of Shodan / Censys / urlscan saved queries that include the company's details.

# Talking Points

## My Alignment with the Role
3–5 tailored talking points connecting the candidate's resume skills/experience with the key job requirements and the company's apparent needs.
- **Talking Point 1:**
- **Talking Point 2:**
- **Talking Point 3:**

## Insightful Questions to Ask
3–5 insightful questions for the candidate to ask the interviewer, based on the company's strategy, challenges, or recent activities.
- **Question 1:**
- **Question 2:**
- **Question 3:**
```

## Notes on the "Exposed Risk" section

Keep this strictly defensive and OSINT-only: report publicly published CVEs, public
internet-scan findings, and references to saved Shodan/Censys/urlscan queries that are
already public. Do not perform active scanning, exploitation, or any intrusive testing —
this is passive intelligence gathering from already-public sources to inform interview
conversation, not a penetration test.
