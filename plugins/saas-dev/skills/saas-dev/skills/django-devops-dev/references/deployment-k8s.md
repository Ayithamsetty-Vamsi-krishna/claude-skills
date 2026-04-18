# DevOps: Kubernetes Rolling Deployment

## Purpose
Kubernetes replaces Docker Compose + nginx + systemd with a single orchestrator.
Use K8s when:
- You need horizontal autoscaling (HPA)
- More than ~5 backend instances or multi-region
- You want rolling deploys with automatic health gating
- You need canary/blue-green built-in via Argo Rollouts or similar
- You're already running other services on K8s

**Skip K8s for smaller projects** — Docker blue/green (see `deployment-bluegreen.md`)
has a simpler operational model and fewer moving parts below 20 instances.

---

## Directory structure

```
k8s/
├── namespace.yaml
├── configmap.yaml
├── secret.yaml              ← managed outside git (sealed-secrets or External Secrets)
├── postgres.yaml            ← or use managed RDS/Cloud SQL
├── redis.yaml               ← or use managed ElastiCache/Memorystore
├── backend-deployment.yaml
├── backend-service.yaml
├── backend-hpa.yaml
├── celery-deployment.yaml
├── celery-beat-deployment.yaml
├── ingress.yaml
└── migration-job.yaml
```

---

## ConfigMap (non-secret config)

```yaml
# k8s/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: autoserve-prod
data:
  DJANGO_SETTINGS_MODULE: config.settings.production
  ALLOWED_HOSTS: api.yourapp.com
  CORS_ALLOWED_ORIGINS: https://yourapp.com
  DB_HOST: postgres.autoserve-prod.svc.cluster.local
  REDIS_URL: redis://redis.autoserve-prod.svc.cluster.local:6379/0
  OTEL_EXPORTER_OTLP_ENDPOINT: http://otel-collector:4317
  PROMETHEUS_MULTIPROC_DIR: /tmp/prometheus
  SENTRY_ENVIRONMENT: production
```

---

## Secret (managed via External Secrets or sealed-secrets)

```yaml
# k8s/secret.yaml — example template; actual values from secret manager
apiVersion: v1
kind: Secret
metadata:
  name: backend-secret
  namespace: autoserve-prod
type: Opaque
stringData:
  SECRET_KEY:              ${VAULT:/autoserve/prod/django/secret_key}
  DB_PASSWORD:             ${VAULT:/autoserve/prod/postgres/password}
  STRIPE_SECRET_KEY:       ${VAULT:/autoserve/prod/stripe/secret}
  AUTH_SECRET:             ${VAULT:/autoserve/prod/nextauth/secret}
  FERNET_KEYS:             ${VAULT:/autoserve/prod/fernet/keys}
  SENTRY_DSN:              ${VAULT:/autoserve/prod/sentry/dsn}
```

In practice use **External Secrets Operator** (`external-secrets.io`) pointing
at AWS Secrets Manager / Vault / GCP Secret Manager. Secret YAML committed
to git is a template; actual secret is generated from the external store.

---

## Backend deployment

```yaml
# k8s/backend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: autoserve-prod
  labels: {app: backend, tier: web}
spec:
  replicas: 3                           # starting point; HPA will scale 3-10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0                 # never let all pods die
      maxSurge: 1                       # only 1 extra during rollout

  selector:
    matchLabels: {app: backend, tier: web}

  template:
    metadata:
      labels: {app: backend, tier: web}
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8000"
        prometheus.io/path: "/metrics/"

    spec:
      serviceAccountName: backend
      containers:
        - name: backend
          image: ${REGISTRY}/backend:${VERSION}
          command:
            - gunicorn
            - config.wsgi:application
            - --bind=0.0.0.0:8000
            - --workers=4
            - --worker-class=sync
            - --config=config/gunicorn.py

          ports:
            - {containerPort: 8000, name: http}

          envFrom:
            - configMapRef: {name: backend-config}
            - secretRef:    {name: backend-secret}

          env:
            - name: POD_NAME
              valueFrom: {fieldRef: {fieldPath: metadata.name}}
            - name: POD_NAMESPACE
              valueFrom: {fieldRef: {fieldPath: metadata.namespace}}

          resources:
            requests: {memory: "256Mi", cpu: "100m"}
            limits:   {memory: "1Gi",   cpu: "1000m"}

          livenessProbe:
            httpGet: {path: /healthz/, port: 8000}
            initialDelaySeconds: 30
            periodSeconds:       10
            timeoutSeconds:      3

          readinessProbe:
            httpGet: {path: /readyz/, port: 8000}
            initialDelaySeconds: 10
            periodSeconds:       5
            timeoutSeconds:      3
            failureThreshold:    3

          lifecycle:
            preStop:
              exec:
                # Grace period for in-flight requests (see "Graceful shutdown")
                command: ["sh", "-c", "sleep 15"]

          volumeMounts:
            - name: prometheus-tmp
              mountPath: /tmp/prometheus

      volumes:
        - name: prometheus-tmp
          emptyDir: {}

      terminationGracePeriodSeconds: 30
```

---

## Service

```yaml
# k8s/backend-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: autoserve-prod
  labels: {app: backend}
spec:
  type: ClusterIP
  selector: {app: backend, tier: web}
  ports:
    - {port: 80, targetPort: 8000, protocol: TCP, name: http}
```

---

## Horizontal Pod Autoscaler

```yaml
# k8s/backend-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend
  namespace: autoserve-prod
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend

  minReplicas: 3
  maxReplicas: 10

  metrics:
    - type: Resource
      resource:
        name: cpu
        target: {type: Utilization, averageUtilization: 70}

    - type: Resource
      resource:
        name: memory
        target: {type: Utilization, averageUtilization: 80}

  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300       # wait 5 min before scaling down
      policies:
        - {type: Percent, value: 50, periodSeconds: 60}
    scaleUp:
      stabilizationWindowSeconds: 30
      policies:
        - {type: Percent, value: 100, periodSeconds: 30}   # double if needed
        - {type: Pods,    value: 2,   periodSeconds: 30}
      selectPolicy: Max
```

---

## Celery worker deployment

```yaml
# k8s/celery-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: celery-worker
  namespace: autoserve-prod
spec:
  replicas: 2

  selector: {matchLabels: {app: celery-worker}}

  template:
    metadata: {labels: {app: celery-worker}}
    spec:
      containers:
        - name: worker
          image: ${REGISTRY}/backend:${VERSION}
          command:
            - celery
            - -A
            - config
            - worker
            - --loglevel=info
            - --concurrency=4
            - --max-tasks-per-child=1000     # prevent memory leaks

          envFrom:
            - configMapRef: {name: backend-config}
            - secretRef:    {name: backend-secret}

          resources:
            requests: {memory: "256Mi", cpu: "100m"}
            limits:   {memory: "1Gi",   cpu: "1000m"}

          livenessProbe:
            exec:
              command:
                - celery
                - -A
                - config
                - inspect
                - ping
            initialDelaySeconds: 60
            periodSeconds:       30
            timeoutSeconds:      10

      terminationGracePeriodSeconds: 60    # let task finish
```

---

## Celery beat (singleton — only 1 replica)

```yaml
# k8s/celery-beat-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: celery-beat
spec:
  replicas: 1                             # MUST be 1 — else duplicate scheduled tasks
  strategy: {type: Recreate}              # no rolling — avoid two beats running
  selector: {matchLabels: {app: celery-beat}}
  template:
    metadata: {labels: {app: celery-beat}}
    spec:
      containers:
        - name: beat
          image: ${REGISTRY}/backend:${VERSION}
          command:
            - celery
            - -A
            - config
            - beat
            - --loglevel=info
            - --scheduler=django_celery_beat.schedulers:DatabaseScheduler
          envFrom:
            - configMapRef: {name: backend-config}
            - secretRef:    {name: backend-secret}
```

---

## Ingress (external traffic)

```yaml
# k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backend
  namespace: autoserve-prod
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "30"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "5"
spec:
  ingressClassName: nginx
  tls:
    - hosts: [api.yourapp.com]
      secretName: api-tls
  rules:
    - host: api.yourapp.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: backend
                port: {number: 80}
```

---

## Migration job

Run migrations as a one-off Job before deploying new backend version:

```yaml
# k8s/migration-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: migrate-${VERSION}
  namespace: autoserve-prod
spec:
  ttlSecondsAfterFinished: 300            # cleanup after 5 min
  backoffLimit: 2

  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: migrate
          image: ${REGISTRY}/backend:${VERSION}
          command: [python, manage.py, migrate, --no-input]
          envFrom:
            - configMapRef: {name: backend-config}
            - secretRef:    {name: backend-secret}
```

Apply before `kubectl rollout`:

```bash
envsubst < k8s/migration-job.yaml | kubectl apply -f -
kubectl wait --for=condition=complete --timeout=300s job/migrate-${VERSION}
kubectl set image deployment/backend backend=${REGISTRY}/backend:${VERSION}
kubectl rollout status deployment/backend
```

---

## Graceful shutdown (critical for zero-downtime)

When K8s terminates a pod:
1. Pod receives SIGTERM
2. Pod is removed from Service endpoints (stops getting new traffic)
3. `terminationGracePeriodSeconds` countdown starts (default 30s)
4. After grace period, SIGKILL if still running

Problem: between step 1 and step 2 there's a small window where the pod
gets SIGTERM but is still receiving traffic. The `preStop` hook with
`sleep 15` pauses to let the service endpoint update before gunicorn exits.

Gunicorn configuration:

```python
# config/gunicorn.py
bind = "0.0.0.0:8000"
workers = 4
worker_class = "sync"
timeout = 30
graceful_timeout = 25         # finish in-flight requests before killing worker
```

---

## Rolling update mechanics

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0        # never reduce capacity during rollout
    maxSurge: 1              # one extra pod during rollout
```

For 3 replicas:
- K8s creates pod #4 with new version
- Waits for readinessProbe on #4
- Terminates one old pod
- Creates pod #5 with new version
- Waits for readiness
- Terminates old pod #2
- etc.

If readinessProbe fails for new pods, rollout pauses automatically. No
cascading failure.

---

## Rollback

```bash
# Previous revision
kubectl rollout undo deployment/backend

# Specific revision
kubectl rollout history deployment/backend
kubectl rollout undo deployment/backend --to-revision=3
```

K8s keeps last 10 ReplicaSets by default — set via `revisionHistoryLimit`.

---

## GitHub Actions CI/CD

```yaml
# .github/workflows/deploy.yml
name: Deploy to K8s
on:
  push:
    tags: ['v*']

env:
  REGISTRY: ghcr.io/${{ github.repository_owner }}

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions: {contents: read, packages: write}

    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build + push
        uses: docker/build-push-action@v5
        with:
          context: ./backend
          push: true
          tags: |
            ${{ env.REGISTRY }}/backend:${{ github.ref_name }}
            ${{ env.REGISTRY }}/backend:latest
          cache-from: type=gha
          cache-to:   type=gha,mode=max

      - name: Configure kubectl
        uses: azure/k8s-set-context@v4
        with:
          method:      kubeconfig
          kubeconfig:  ${{ secrets.KUBE_CONFIG }}

      - name: Run migrations
        run: |
          export VERSION=${{ github.ref_name }}
          export REGISTRY=${{ env.REGISTRY }}
          envsubst < k8s/migration-job.yaml | kubectl apply -f -
          kubectl wait --for=condition=complete --timeout=300s job/migrate-$VERSION

      - name: Rolling update
        run: |
          kubectl set image deployment/backend backend=${{ env.REGISTRY }}/backend:${{ github.ref_name }}
          kubectl set image deployment/celery-worker worker=${{ env.REGISTRY }}/backend:${{ github.ref_name }}
          kubectl set image deployment/celery-beat beat=${{ env.REGISTRY }}/backend:${{ github.ref_name }}
          kubectl rollout status deployment/backend --timeout=10m
```

---

## NetworkPolicy (security)

Restrict pod-to-pod traffic:

```yaml
# k8s/network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-allow
  namespace: autoserve-prod
spec:
  podSelector: {matchLabels: {app: backend}}

  ingress:
    - from:
        - podSelector: {matchLabels: {app: ingress-nginx}}
      ports: [{port: 8000}]

  egress:
    # Allow DNS
    - to: [{namespaceSelector: {}, podSelector: {matchLabels: {k8s-app: kube-dns}}}]
      ports: [{port: 53, protocol: UDP}]
    # Allow DB
    - to: [{podSelector: {matchLabels: {app: postgres}}}]
      ports: [{port: 5432}]
    # Allow Redis
    - to: [{podSelector: {matchLabels: {app: redis}}}]
      ports: [{port: 6379}]
    # Allow external HTTPS (Stripe, S3, etc.)
    - ports: [{port: 443}]
```

---

## Pros vs. Docker blue/green

**K8s wins when:**
- Horizontal autoscaling required
- Multi-region / multi-zone
- Canary / A/B deployments needed
- Already running on K8s (Team / Co-located services)
- Need self-healing (crashed pod auto-restarts)

**Docker blue/green wins when:**
- < 20 instances
- Small team, no dedicated devops
- Predictable load (no autoscaling needed)
- Simpler mental model

---

## Known gotchas

1. **Beat as Deployment, not StatefulSet** — but MUST be `replicas: 1` with
   `strategy: Recreate`. Two beats = duplicate scheduled tasks.

2. **PROMETHEUS_MULTIPROC_DIR** must be on an `emptyDir` volume, not in the
   container filesystem. Across multiple gunicorn workers, they need a shared
   directory (per pod, not across pods).

3. **Celery worker graceful shutdown** — needs `terminationGracePeriodSeconds`
   long enough for the longest-running task to complete. Or: use `task_acks_late`
   so interrupted tasks get re-queued.

4. **K8s secrets are base64, not encrypted** — attackers with cluster access
   read them plaintext. Use sealed-secrets or External Secrets + proper RBAC.

5. **Cluster autoscaler lag** — if HPA maxes out pods and cluster is full,
   new pods pending for minutes. Provision extra node capacity or use
   overprovisioning.

6. **Migrations during rolling update** — if old pods are running and you add
   a new migration (new column), old pods crash on SELECT *. ALWAYS backward-
   compatible migrations.

7. **`kubectl apply` leaks** — applied secrets/configmaps are never auto-
   deleted. Use kustomize or Helm for declarative cleanup.
