# Cloud & Kubernetes Interview Prep Course

Start with Module 0 and the `two-tier-app/` starter (Python/Flask): one container with a web service on your laptop, then build up. Module 3b is the Google "Getting started with Kubernetes" demo ported to Python (`k8s-workshop/`). Module 8 maps everything to the Wiz Technical Account Manager role: CNAPP vocabulary, threat models, and the TAM motion.

Modules:

- [How to use this course](modules/00-how-to-use-and-lab-setup.md)
- [Module 0: Start on your laptop, one container at a time](modules/01-start-on-your-laptop.md)
- [Module 1: Cloud foundations and the two-tier application](modules/02-cloud-foundations-two-tier-app.md)
- [Module 1b: Compute, infrastructure as code, and their security implications](modules/02b-compute-iac-cloudformation-security.md)
- [Module 2: Containerizing the two-tier app](modules/03-containerizing-the-app.md)
- [Module 3: Kubernetes fundamentals and deploying a cluster](modules/04-kubernetes-fundamentals-and-cluster.md)
- [Module 3b: The Google "Getting started with Kubernetes" demo, in Python](modules/04b-getting-started-with-kubernetes-demo-python.md)
- [Module 4: Deploying the two-tier app on Kubernetes](modules/05-deploying-the-app-on-kubernetes.md)
- [Module 5: CI/CD pipelines](modules/06-ci-cd-pipelines.md)
- [Module 6: Cloud native security](modules/07-cloud-native-security.md)
- [Module 7: Observability, troubleshooting, and day-2 operations](modules/08-observability-and-day-2-ops.md)
- [Module 8: The Wiz Technical Account Manager lens](modules/08b-wiz-tam-lens.md)
- [Teardown: delete everything the labs created](modules/09-teardown-script.md)
- [Interview question bank and answer frameworks](modules/10-interview-question-bank.md)
- [7-day study plan and lab checklist](modules/11-study-plan-and-lab-checklist.md)

Code and scripts:

- [two-tier-app/](two-tier-app/): the starter repo used by every module (README has the Module 0 steps)
- [k8s-workshop/](k8s-workshop/): hello / auth / nginx frontend demo in Python, with the Module 3b commands in its README
- [charts/api/](charts/api/): Helm chart for the API tier with staging and prod values (Lab 4.3)
- [teardown.sh](teardown.sh): deletes every cloud resource the labs create (`PROJECT=my-project ./teardown.sh --dry-run` first)

Full course in one file: [cloud-kubernetes-interview-prep-course.md](cloud-kubernetes-interview-prep-course.md)
