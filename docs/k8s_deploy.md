# AuraLog Kubernetes Deployment Guide

## Apply order

```bash
kubectl apply -f infra/k8s/namespace.yaml
kubectl apply -f infra/k8s/configmap.yaml
kubectl apply -f infra/k8s/secret.example.yaml
kubectl apply -f infra/k8s/pvc.yaml
kubectl apply -f infra/k8s/deployment.yaml
kubectl apply -f infra/k8s/service.yaml
kubectl apply -f infra/k8s/pdb.yaml
kubectl apply -f infra/k8s/hpa.yaml
kubectl apply -f infra/k8s/networkpolicy.yaml
```

## Mandatory edits before production

- Replace image `ghcr.io/your-org/auralog:latest`
- Create real secret from `infra/k8s/secret.example.yaml`
- Size PVC according to retention and ingest load

## Health probes

- readiness: `GET /health`
- liveness: `GET /health`

## HA considerations

- DuckDB embedded storage implies single writable replica semantics.
- Keep Deployment replicas at 1 unless you add a writer-coordination strategy.
- HPA is included as baseline, but should be enabled only after architecture update for multi-writer.

## Rollback

```bash
kubectl rollout undo deployment/auralog -n auralog
kubectl rollout status deployment/auralog -n auralog
```
