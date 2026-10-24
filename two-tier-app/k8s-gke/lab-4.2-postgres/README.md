# Lab 4.2: Postgres as a StatefulSet

Run Postgres in the cluster once, so the "why not" answer is from experience.
Everything here is disposable. Delete the namespace at the end so the disk stops billing.

## Apply

```bash
cd two-tier-app/k8s-gke/lab-4.2-postgres
kubectl apply -f 00-namespace.yaml
kubectl -n pg-lab create secret generic postgres-credentials --from-literal=password="$(openssl rand -base64 18)"
kubectl apply -f .
kubectl -n pg-lab get pods -w               # -w takes one resource type at a time
kubectl -n pg-lab get pvc,pv                # PVC Pending until the pod is scheduled (WaitForFirstConsumer), then Bound
```

Expect `postgres-0` Running 1/1 and `data-postgres-0` Bound within a minute.

## A client pod, and the stable DNS name

```bash
export PGPASSWORD=$(kubectl -n pg-lab get secret postgres-credentials -o jsonpath='{.data.password}' | base64 -d)
kubectl -n pg-lab run psql --rm -it --restart=Never --image=postgres:16.6-alpine --env="PGPASSWORD=$PGPASSWORD" -- \
  psql -h postgres-0.postgres.pg-lab.svc.cluster.local -U app -d app
```

`postgres-0.postgres...` is the per-pod name from the headless Service. A Deployment pod has no such name.

## Proof 1: delete the pod, the data survives

Inside psql:

```sql
CREATE TABLE notes (id serial PRIMARY KEY, body text);
INSERT INTO notes (body) VALUES ('written before the pod was deleted');
\q
```

Then:

```bash
kubectl -n pg-lab delete pod postgres-0
kubectl -n pg-lab get pods -w            # a new postgres-0 appears with the same name
kubectl -n pg-lab get pvc                # data-postgres-0 is still Bound, same PV
```

Reconnect with the client command above and run `SELECT * FROM notes;`. The row is there.
The pod was replaced, the PVC was not, and the StatefulSet controller reattached the same disk by name.

## Proof 2: delete the PVC, the data does not survive

```bash
kubectl -n pg-lab delete statefulset postgres     # pod goes away; PVC and PV stay
kubectl -n pg-lab get pvc,pv                      # still Bound: deleting the StatefulSet never deletes data
kubectl -n pg-lab delete pvc data-postgres-0      # reclaimPolicy Delete: the PV and the GCE disk go with it
kubectl get pv                                    # gone
kubectl apply -f 20-statefulset.yaml              # fresh PVC, fresh disk, initdb runs again
```

Reconnect and run `SELECT * FROM notes;`. Relation does not exist. The data lived on the disk, and the disk is gone.

## Cleanup

```bash
kubectl delete namespace pg-lab     # deletes the StatefulSet, pods, Secret, and the PVC, which deletes the disk
kubectl get pv                      # confirm nothing left behind
```

## What this proves, and what it does not

StatefulSet solves: stable pod names, ordered startup and shutdown, one persistent disk per pod that survives pod replacement.

Still yours, with no help from Kubernetes:

- Backups and point-in-time recovery. Nothing here is backed up. Deleting the PVC was the whole dataset.
- Failover. `replicas: 1` is one Postgres. Going to 2 does not give you a replica; it gives you a second empty Postgres on its own disk. Replication, promotion, and client re-routing need an operator (CloudNativePG, Zalando) and still need you to run it.
- Minor-version upgrades, extension management, connection pooling, vacuum tuning, monitoring.
- Disk is zonal. If the node's zone goes down, the pod cannot start anywhere else.

Cloud SQL charges for exactly that list. That is the interview answer: run stateful things in Kubernetes when you must, buy the managed service when you can.
