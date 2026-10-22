# Module 8: The Wiz Technical Account Manager lens

The target role is [Technical Account Manager (Mid-Atlantic) at Wiz](https://www.wiz.io/careers/job/4688850006/technical-account-manager-mid-atlantic?gh_jid=4688850006), remote US, on the Technical Solutions Management team, application deadline October 31, 2026. Modules 0 to 7 cover the technical bar in the posting; this module covers what the posting adds: Wiz's product and the CNAPP category, cloud threat models and how to talk about them, and the TAM motion itself (onboarding, success plans, QBRs, a book of up to 15 customers, renewals and expansion). Budget 3 hours plus two labs.

**Part A: The posting, mapped to this course**

| Posting requirement | Where the course covers it | Gap to close here |
| --- | --- | --- |
| Architecture of at least one CSP (AWS, GCP, Azure, OCI) | Modules 1, 1b, 3, 4 on GCP with AWS/Azure equivalents at every step; CloudFormation in 1b | Be ready to whiteboard the same two-tier app on AWS from memory |
| Container technologies and their security considerations | Modules 0, 2, 3b, 4, 6 | Frame findings the way a CNAPP does: image CVE + exposure + privilege, not CVE alone (Part C) |
| DevOps tools: CI/CD, IaC, version control | Modules 1b and 5 | Where a security platform plugs into each stage: IaC scanning in PR, image scanning in CI, admission at deploy (Part B) |
| Linux and Windows OS concepts | Modules 0 and 7 (processes, users, systemd, namespaces, cgroups) | Windows: know that agentless snapshot scanning covers Windows VMs; runtime sensors are Linux/eBPF first |
| 5+ years technical customer-facing (TAM, PS, SE, Support, CSE, Architect) | Your Google Cloud sales engineering and PM background | Tell those stories in TAM language: adoption, value realization, renewal, expansion (Part E) |
| Preferred: CSP certification | GCP certified | Mention it; have one sentence on which exam and when |
| Preferred: cloud-security best practices, common threat models, CNAPP use cases | Module 6 (4Cs, IAM, RBAC, PSA, NetworkPolicy, secrets, supply chain) | Threat models as attack paths and the CNAPP vocabulary (Parts B and C) |
| Preferred: OS runtime sensing | Module 6 mentions Falco | eBPF sensors, what runtime adds to agentless (Part B) |
| Preferred: book of 5 to 10+ customers, enterprise relationships, exceeding targets | Not covered by a technical course | The TAM motion and templates (Part D) |
| Preferred: CRM or log analysis tools to monitor customer health | Module 7 observability is the technical half | Customer health signals and how to read them (Part D) |
| Ambiguity, refining the TAM function |  | Stories about building process from scratch (Part E) |

The posting's "what you'll do" has five headings: be the product and cloud-security expert; drive adoption, value realization, and satisfaction; advocate for customers; manage the book of business and revenue objectives; build the TAM organization. Expect one interview round per heading, roughly: a technical deep dive, a customer scenario or mock QBR, a product-feedback or cross-functional scenario, a commercial judgment conversation, and a culture or leadership conversation.

**Part B: How Wiz works, and the CNAPP vocabulary**

A CNAPP (cloud-native application protection platform) consolidates the point tools a security team used to buy separately into one platform with one data model, so that a finding about a container image can be ranked by whether the container is internet-exposed, what identity it runs as, and what data it can reach. Wiz's version of that data model is the Security Graph, and its one-sentence positioning is that it unifies security from code to production and surfaces the "toxic combinations" of risks across a cloud estate ([Wiz, "Is Wiz a runtime security tool?"](https://wiz.io/blog/is-wiz-a-runtime-security-tool)).

| Term | What it means | The course lab that produced the same signal by hand |
| --- | --- | --- |
| Agentless Cloud Connector | Read-only API integration per cloud account; Wiz snapshots workload disks and scans them out of band, so onboarding needs no agents, no downtime, no code changes. Customers are typically connected in 10 to 15 minutes with first critical findings within the hour ([Wiz evaluation FAQ](https://www.wiz.io/academy/cloud-security/how-to-evaluate-wiz-faq)) | Lab 6.1's IAM review and Lab 2.3's Trivy scan, done once per resource by a human |
| Security Graph | The correlation engine: resources, identities, network exposure, vulnerabilities, secrets, data, all as nodes and edges | The architecture diagram in Module 1, if it also knew every CVE, role binding, and bucket ACL |
| Toxic combination / attack path | Several individually medium risks that together form an exploitable route, e.g. public exposure + critical CVE + over-privileged identity + reachable sensitive data | Part C below rebuilds the labs' app as one |
| Critical issue vs. vulnerability | Wiz ranks by exploitability, exposure, privilege, data access, and business impact rather than CVSS alone; "Zero Critical" is a customer milestone | Module 7's debugging ladder, applied to risk instead of outages |
| Wiz Cloud | Agentless visibility and risk prioritization across cloud estates; the CSPM, CIEM, DSPM, KSPM, vulnerability-management capabilities live here | Modules 1 to 4 and 6 |
| Wiz Code | Shift-left: IaC (Terraform, CloudFormation, Kubernetes manifests), secrets, SBOMs, container images, CI/CD pipelines, with cloud-to-code correlation and fixes in IDE, PR, and pipeline | Lab 1b.4 (Checkov, cfn-lint, gitleaks) and Lab 5.1 (Trivy, cosign, SBOM) |
| Wiz Defend | Runtime detection and response: threat detections, Wiz Forensics evidence capture, containment Workflows, an AI investigator | Module 6's runtime-and-detection section (Falco, audit logs) |
| Wiz Runtime Sensor | Lightweight eBPF sensor on Linux containers, Kubernetes, VMs, serverless, Windows; adds live process, network, and file signals and feeds them back into the graph for prioritization ("is this vulnerable package actually loaded?") | Lab 7.1's `kubectl exec` and `docker stats`, continuously and at scale |
| CSPM | Cloud security posture: misconfigurations against benchmarks (CIS, SOC 2, PCI) | Lab 6.1 default-SA check, Lab 3.2's private-cluster flags |
| CIEM | Cloud infrastructure entitlement management: who or what can do what, effective permissions, over-privilege, missing MFA | Labs 6.1 and 6.2, Module 1b D2 metadata risk |
| DSPM | Data security posture: where sensitive data is, who can reach it | Not in the labs; the Cloud SQL instance with customer rows is the asset |
| KSPM | Kubernetes security posture: RBAC, PSA, NetworkPolicy, exposed services, cluster config | Labs 6.2 to 6.4, Module 3b |
| AI-SPM / AI-BOM | Inventory and posture of AI services, models, SDKs | Not in the labs; the question will come up given the Google context |
| Projects and RBAC | Scoping findings and access by team, business unit, or environment inside Wiz | Namespaces and RBAC in Module 6, applied to the security tool itself |
| Integrations | Ticketing (Jira, ServiceNow), chat (Slack, Teams), SIEM/SOAR (Splunk, Sentinel, PagerDuty), CI/CD (GitHub, GitLab, Jenkins, Terraform), identity (Okta, Entra), cloud (Security Hub, Pub/Sub) | Lab 5.1's pipeline is where the GitHub and Terraform integrations attach |

**Where a CNAPP plugs into the pipeline you built in Module 5**

| Stage | Course tool | CNAPP equivalent | TAM talking point |
| --- | --- | --- | --- |
| Developer IDE / PR | Checkov, gitleaks | Wiz Code: IaC and secrets scanning in the PR with cloud context ("this bucket will be public and already holds PII") | Shift-left reduces findings before they reach production; measure by findings per PR trending down |
| Image build | Trivy, syft SBOM | Image scanning in CI with the same policy as production, SBOM retained | One policy from code to cloud; no "it passed CI but Wiz flagged it" surprises |
| Deploy | Binary Authorization, Kyverno | Admission controller: block images with critical issues or no scan | Guardrail, not gate: start in audit mode, then enforce |
| Running | Falco, audit logs | Agentless graph plus Runtime Sensor; Defend detections and forensics | Runtime context tells you which 2 percent of CVEs are loaded in memory |
| Operate | Prometheus, SLOs | Issues, SLAs, remediation workflows, Jira sync, dashboards per Project | Security SLOs: time-to-remediate criticals, Zero Critical streak |

**Objections you will hear and how a TAM answers them**

- "Agentless cannot see runtime." True for the connector alone; that is what the Runtime Sensor adds, and the graph lets a customer deploy it selectively on the workloads that matter instead of everywhere on day one.
- "We already have a CSPM / a vulnerability scanner / a SIEM." A CNAPP's value is correlation across those signals, not any one of them; show one toxic combination the existing tools each saw a third of.
- "Too many findings." Prioritization by attack path, Projects to route findings to owners, SLAs, and remediation bundles; the onboarding target is a short critical list each team actually owns, not a 10,000-row export.
- "Scanning our disks is a privacy or performance concern." Snapshots are read-only, out of band, in the customer's cloud account region; no production I/O.

Check product specifics against current Wiz documentation before the interview; names and packaging change, and the posting notes Wiz is now part of Google.

**Part C: Threat models and attack paths**

A threat model answers three questions: what are we protecting, who would come for it and how, and which controls break the path. In cloud the "how" is almost always a chain of individually unremarkable weaknesses. Be able to narrate the seven below, name the control that breaks each link, and point at the lab where you set that control.

| Attack path | Links in the chain | Control that breaks it | Lab |
| --- | --- | --- | --- |
| Internet-exposed workload with a critical CVE | Public LB or NodePort → vulnerable library in the image → RCE in the container | Image scanning with an exposure-aware priority; admission policy; patch cadence | 2.3, 5.1, 6.6 |
| Metadata credential theft (SSRF to IMDS) | App fetches a user-supplied URL → `169.254.169.254` → node or VM service-account token → cloud API | Per-workload identity (Workload Identity, IRSA), IMDSv2, metadata concealment, egress NetworkPolicy | 6.1, 6.4, 1b D2 |
| Over-privileged identity | Compromised pod or CI job → identity with Editor/Owner or `*:*` → lateral movement to every project | Least-privilege roles, CIEM review of effective permissions, no default SA | 6.1, 1b.2 iam.tf |
| Leaked long-lived keys | Service-account key JSON or AWS access key in a repo, image layer, or CI log → direct API access from anywhere | OIDC federation instead of keys, secret scanning, key rotation, org policy that forbids key creation | 5.1, 1b.4 |
| Public data store | Bucket or database reachable from the internet, often by a one-line misconfiguration | CSPM check on public access, private IP only for databases, org-level deny on public buckets | 1.1, 1b.2 database.tf |
| Container escape and lateral movement | Privileged pod or host mount → node root → every pod on the node → cluster | Pod Security `restricted`, no host mounts, non-root images, NetworkPolicy default deny | 6.3, 6.4 |
| Software supply chain | Compromised base image, dependency, or pipeline action → malicious code shipped with a valid tag | Pinned digests, SBOM, signing and verification at admission, pinned Actions by SHA | 2.1, 5.1, 6.6 |

**The labs' app as a toxic combination.** Take the Module 4 deployment and imagine four small lapses: the image was built from an old `python:3.12` base with a critical CVE in a system library; the Ingress is public (it is meant to be); `api-sa` was given `roles/editor` "temporarily" during a debugging session; and the Cloud SQL instance holds customer records. Each on its own is a medium finding a team might defer. Together they are one path: internet → RCE in the API pod → Workload Identity token for `api-sa` → every project resource including the database and its backups. A CNAPP ranks that one path above a thousand isolated CVEs on internal batch jobs. As a TAM, this is the story you tell in the first onboarding call: "here is the one thing to fix this week."

**Lab 8.1 (45 min): build the toxic combination, then break it link by link**

```bash
# 1. the weak image: rebuild on an old full base and push it
sed -i 's#python:3.12-slim#python:3.12.0#' Dockerfile.step1
docker build -f Dockerfile.step1 -t us-central1-docker.pkg.dev/PROJECT/apps/api:weak . && docker push us-central1-docker.pkg.dev/PROJECT/apps/api:weak
trivy image --severity CRITICAL,HIGH us-central1-docker.pkg.dev/PROJECT/apps/api:weak | tail -5

# 2. the over-privileged identity
gcloud projects add-iam-policy-binding PROJECT --member serviceAccount:api-sa@PROJECT.iam.gserviceaccount.com --role roles/editor

# 3. deploy it behind the public Ingress from Module 4
kubectl -n two-tier set image deployment/api api=us-central1-docker.pkg.dev/PROJECT/apps/api:weak

# 4. prove the path from inside the pod: the token the attacker would get
kubectl -n two-tier exec deploy/api -c api -- python3 -c "import urllib.request as u;print(u.urlopen(u.Request('http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token',headers={'Metadata-Flavor':'Google'})).read()[:60])"

# now break the links, one at a time, and after each one say out loud what the attacker can no longer do
gcloud projects remove-iam-policy-binding PROJECT --member serviceAccount:api-sa@PROJECT.iam.gserviceaccount.com --role roles/editor   # least privilege
kubectl -n two-tier set image deployment/api api=us-central1-docker.pkg.dev/PROJECT/apps/api@sha256:GOOD_DIGEST                      # patched image by digest
kubectl apply -f k8s/networkpolicy.yaml                                                                                               # default deny egress except DB and DNS (Lab 6.4)
git checkout Dockerfile.step1
```

Write the finding up in four lines the way you would for a customer: asset, exposure, weakness, blast radius, fix. Then the sentence that matters in a QBR: "this class of issue is now blocked at admission, so it cannot recur."

**Lab 8.2 (45 min): produce a findings list with open-source scanners and triage it like a TAM**

```bash
pip install prowler && prowler gcp --project-ids PROJECT --output-formats csv --output-directory ./prowler   # CSPM-style posture checks
kube-bench run --targets node,policies 2>/dev/null | grep -E "\[FAIL\]|\[WARN\]" | head -40                   # KSPM-style CIS benchmark (run in a kind or GKE node)
trivy k8s --report summary cluster                                                                            # workload CVEs and misconfigs across the cluster
checkov -d infra/ --compact                                                                                   # IaC posture
```

You will get hundreds of rows. Do what a CNAPP does by hand: tag each finding with exposure (internet, internal, none), privilege (what identity it touches), and data (what it can reach), then sort. The top five after that sort are your "critical issues"; everything else is backlog with an SLA. Bring the before-and-after counts to the interview; it is the most concrete way to show you understand prioritization rather than scanning.

**Frameworks to name without lecturing about them.** MITRE ATT&CK for Cloud and Containers (the tactic names: initial access, credential access, lateral movement, exfiltration); CIS Benchmarks for GCP, AWS, Azure, and Kubernetes (what CSPM checks encode); OWASP Kubernetes Top 10; NIST CSF for the customer's compliance mapping; shared responsibility as the frame for "whose control is it."

**Part D: The TAM motion**

A TAM owns the customer's outcome after the sale: deployed, adopted, showing value, renewed, expanded. The posting says up to 15 customers, C-level to practitioner relationships, and measurable success plans. Below is the lifecycle with what good looks like at each stage, then four templates you can bring to the interview as artifacts.

| Stage | What you do | Measure | Risk signal |
| --- | --- | --- | --- |
| Kickoff (week 0) | Confirm the "why we bought": compliance deadline, incident, consolidation, board ask. Name the executive sponsor, the champion, and the practitioners. Agree on success criteria | Success plan signed off | No executive sponsor; the buyer is not the user |
| Onboarding (weeks 1 to 2) | Connect every cloud account and cluster; the goal is 100 percent coverage, since the graph is only as good as its inputs. Set up Projects and RBAC so each team sees its own findings. Wire Slack and Jira | Percent of accounts connected; time to first critical list | Only the sandbox account connected after two weeks |
| Operationalize (weeks 2 to 8) | Turn findings into a workflow: owners, SLAs by severity, a weekly critical review, remediation bundles, CI integration so new issues are caught in PRs. Train practitioners; run office hours | Criticals open, MTTR by severity, percent of findings with an owner | Findings pile up with no owner; the champion is the only login |
| Value realization (quarterly) | Show the before-and-after: Zero Critical reached, MTTR down, tools consolidated, audit hours saved, risky identities removed. Map to the original "why we bought" | QBR with numbers the sponsor cares about | Metrics only a security engineer understands |
| Renewal and expansion | 120 days out, confirm value is documented and the sponsor agrees. Expansion comes from adoption gaps you already see: Wiz Code when PR findings are the pain, Defend when they ask about runtime, DSPM when data classification comes up | Renewal forecast, expansion pipeline sourced by TAM | Champion left; usage flat; executive has never seen a QBR |
| Advocacy | Log feature requests with the customer's words, business impact, and workaround; close the loop when shipped or declined | Requests with outcomes communicated | Customer hears "we passed it to product" and nothing else |

**Customer health, read from data.** The posting asks for comfort with CRM and log tools to monitor health. The signals: login frequency and breadth (one user or twenty), coverage trend (accounts connected over time), issue trend (criticals opened vs. closed), integration usage (are tickets being created), support ticket sentiment and volume, time since last executive touch, and contract events (renewal date, payment terms). A customer with falling logins and a renewal in 90 days is the one you call this week.

**Template 1: 30-60-90 onboarding plan**

```
Day 30: all production accounts and clusters connected; Projects per BU; Slack + Jira live;
        first critical list reviewed with security lead; 3 toxic combinations fixed; 10 practitioners trained
Day 60: SLAs enforced (critical 7d, high 30d); weekly critical review running without me;
        IaC scanning in the main repo's PRs; MTTR baseline published
Day 90: Zero Critical on production; executive readout delivered; runtime sensor piloted on one cluster;
        success plan metrics updated; renewal/expansion conversation scheduled with AE
```

**Template 2: success plan (one page)**

```
Customer:            ACME Corp         Sponsor: CISO        Champion: Cloud Security Lead
Why they bought:     SOC 2 renewal in Q2; two cloud incidents last year; 4 overlapping tools
Goal 1 (compliance): SOC 2 CC6/CC7 evidence from the platform by <date>        Metric: controls passing %
Goal 2 (risk):       Zero Critical on prod accounts by <date>                   Metric: open criticals, MTTR
Goal 3 (efficiency): retire 2 of 4 tools by <date>                             Metric: tools retired, $ saved
Blockers:            no owner for legacy account X; CI team not engaged
Next 3 actions:      (owner, date) ...
```

**Template 3: QBR agenda (45 min)**

```
1. Where we started (5)     the why-we-bought and the day-0 numbers
2. What changed (15)        coverage, criticals trend, MTTR, tools retired, audit evidence; one story of a path closed
3. What is in the way (10)  adoption blockers by people / process / technology, and asks of the sponsor
4. What is next (10)        roadmap items that matter to them, next quarter's goals, expansion if it serves a goal
5. Feedback (5)             what should we do differently
```

**Template 4: feature request / blocker record**

```
Customer + ARR:  ...      Requested by (role): ...      Date: ...
In their words:  "..."
Business impact: what they cannot do, what it costs them, deadline if any
Workaround:      what we offered; accepted / not accepted
Product ask:     one sentence; link to internal ticket
Loop closed:     date and outcome communicated to customer
```

**Working with the other teams.** Sales and renewals own the commercial conversation; you supply the value evidence and the risk flags early. Support owns tickets; you own the pattern across tickets and the escalation path for your accounts. Product and engineering own priorities; you own the quality of the signal you send them. Solutions engineering owns pre-sales; the handoff to you should carry the success criteria they promised.

**Part E: TAM interview questions, scenarios, and stories**

Answer scenarios in the same shape every time: clarify the goal and who is in the room, diagnose with data, propose the next two actions with owners, and say what you would escalate and to whom. Two minutes, then stop.

| Type | Question | What a strong answer contains |
| --- | --- | --- |
| Scenario | A new customer connected one account three weeks ago and has not logged in since | Call the champion, not email; find the blocker (no owner, no time, waiting on another team); get the sponsor to assign one; book a working session to connect the rest and produce the first critical list live |
| Scenario | Customer says the platform is too noisy, 8,000 findings | Separate noise from volume: Projects to route by owner, filter to attack paths and production, SLAs by severity, remediation bundles; agree a "top 10 this month" list; measure criticals, not totals |
| Scenario | The champion just left the company | Within a week: meet the sponsor, identify the new owner, re-run a short onboarding for them, re-validate the success plan, log it as a renewal risk with the AE |
| Scenario | Security team loves it, platform engineering refuses to add it to CI | Find their objection (false positives, build time, trust); pilot on one repo in audit mode with a shared dashboard; show findings-per-PR falling; let their lead present it |
| Scenario | Customer asks for a feature you know is not on the roadmap | Understand the underlying job; offer the workaround honestly; log the request with impact; set expectations on follow-up and keep them; never promise a date |
| Scenario | Renewal in 90 days, usage flat, sponsor has never been in a QBR | Build the value story from data you have (coverage, criticals closed, paths fixed), request a 30-minute executive readout, bring the AE, surface the risk internally now |
| Scenario | A customer is in an active incident and asks you what to do | You are not their IR team: help them use the platform to scope (what else is exposed, what identity was involved, forensics if Defend is deployed), loop in support and the account team, document, and follow up with a post-incident review on which controls would have broken the path |
| Scenario | Two customers' asks conflict with your week; one is 10x the ARR | Prioritize by impact and commitment, not only ARR; tell the smaller customer when they will get what; ask your manager if both are at risk |
| Technical | Walk me through how you would onboard a customer with 40 AWS accounts and 6 EKS clusters | Organization-level connector, Projects per BU, coverage check, KSPM for the clusters, first critical review within the week, sensor pilot later |
| Technical | A customer asks whether agentless is enough | Yes for posture, vulnerabilities, identities, data, and attack paths; add the runtime sensor where they need detection and "is it actually loaded" context; recommend sensor on internet-facing and crown-jewel workloads first |
| Technical | Explain a toxic combination to a CFO | Three unlocked doors in a row versus one; we fix the row, not every door in the building |
| Commercial | How do you find expansion without being salesy | Expansion is an adoption gap you can name: they asked twice about runtime, their PR findings are rising, they are doing data classification by hand. Bring it to the AE with the evidence |
| Building | We are still defining the TAM function; what would you build first | A standard onboarding runbook and a health scorecard, because they make every other conversation measurable; then mentoring and documentation |
| Motivation | Why Wiz, why a TAM role after product management | Your words; a credible version connects wanting ownership of customer outcomes with the cloud-security problem being the one you want to work on |

**Stories to prepare (STAR, 90 seconds each), drawn from your own history**

- A customer or stakeholder who was stuck in adoption and what you did to unblock them; end with the metric that moved.
- A time you carried a customer's requirement into a product decision and what shipped or did not, and how you closed the loop.
- Running a cross-functional program with people who did not report to you (your YouTube Data Platform work is the natural source).
- A technical escalation you owned end to end as a sales engineer: what was broken, how you diagnosed it, who you pulled in, how you communicated to the customer.
- Exceeding a target, with the number, and the process you built to get there.
- Operating in ambiguity: a function or process you defined from nothing.
- A time you said no to a customer and kept the relationship.

**Questions to ask them**

- How is the book assigned, and what does the mix look like (segment, cloud, maturity)?
- What does a successful first 90 days look like for a TAM here, measured how?
- How do TAM, Solutions Engineering, Support, and Customer Success divide responsibilities today, and where is that still being defined?
- What has changed, or will, for the TAM function since joining Google?
- Which customer outcomes does leadership track on the dashboard?
