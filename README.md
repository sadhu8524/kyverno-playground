# Kyverno playground

Can a platform team give new Pods a default logging label while letting workload owners choose their own? This Minikube lab uses a Kyverno admission policy to try that design. A namespace owner opts in once. A developer can override the default on an individual Pod or a Deployment’s Pod template.

| Namespace opts in | Label submitted with the Pod | Expected label after admission |
| --- | --- | --- |
| Yes | Absent | `log-type=infrastructure` |
| Yes | `log-type=application` | `log-type=application` |
| No | Absent | Absent |

## Run it locally

Use a running Docker engine with Linux containers, Minikube, kubectl, Helm and Bash (WSL works on Windows). Run these commands from the repository root. Allow Docker at least four CPUs and 6 GiB of memory for the cluster.

```bash
minikube start -p kyverno-lab --driver=docker --cpus=4 --memory=6144 --kubernetes-version=v1.34.1
helm upgrade --install kyverno kyverno --repo https://kyverno.github.io/kyverno/ \
  --version '~3.6.0' --namespace kyverno --create-namespace \
  --kube-context kyverno-lab --wait --timeout 10m
kubectl --context kyverno-lab apply -f namespaces.yaml -f policy.yaml
kubectl --context kyverno-lab wait --for=condition=Ready clusterpolicy/default-infra-log-label --timeout=2m
bash verify.sh
```

The test submits three Pod creation requests with server-side dry run. Each assertion reads the label returned by the API server. A successful run prints three PASS lines and starts no containers.

## Read the rule

The namespace selector in [policy.yaml](policy.yaml) matches `infra-logging=enabled`. Kyverno’s `+(log-type)` add anchor supplies a value when the key is absent. The rule acts on newly created Pods, including Pods created by a Deployment. Existing Pods keep their labels until replaced. The example demonstrates classification at admission. Routing logs would also require a collector configured to select that label.

To inspect a real Pod in the lab:

```bash
kubectl --context kyverno-lab -n logging-demo create deployment sample --image=nginx:alpine
kubectl --context kyverno-lab -n logging-demo get pods -l app=sample -L log-type
```

Re-run the second command once the Deployment creates its Pod. Look for `infrastructure` in the LOG-TYPE column.

## Pause or remove the playground

`minikube stop -p kyverno-lab` pauses the cluster. Resume with `minikube start -p kyverno-lab`. To discard the cluster and its resources, run `minikube delete -p kyverno-lab`.

[Kyverno mutation rules](https://kyverno.io/docs/policy-types/cluster-policy/mutate/) · [Minikube](https://minikube.sigs.k8s.io/docs/start/)

## Four CEL policies

This second exercise uses the four Kyverno policy kinds in the 1.16 release line. It runs in the separate `cel-demo` namespace. Start the Minikube profile and install Kyverno with the Helm command above first.

| Policy | Try it |
| --- | --- |
| [MutatingPolicy](cel/policies/mutate.yaml) | Create a Pod without a logging label. Admission supplies `log-type=infrastructure`. |
| [ValidatingPolicy](cel/policies/validate.yaml) | Supply `application` as an override. Try `typo` to see the admission denial. |
| [GeneratingPolicy](cel/policies/generate.yaml) | Create or update the `logging-bootstrap` ConfigMap. The background controller creates `logging-settings` with `format=json`. |
| [DeletingPolicy](cel/policies/delete.yaml) | Label the `cleanup-sample` ConfigMap `disposable=true`. The cleanup controller checks every minute. |

From the repository root, run:

```bash
kubectl --context kyverno-lab create ns cel-demo --dry-run=client -o yaml | kubectl --context kyverno-lab apply -f -
kubectl --context kyverno-lab apply -f cel/permissions.yaml
kubectl --context kyverno-lab apply -f cel/policies/
kubectl --context kyverno-lab wait --for=condition=Ready -f cel/policies/ --timeout=2m
bash cel/verify.sh
```

The Pod tests use server-side dry run. The generation and deletion tests use real ConfigMaps so the asynchronous controllers can observe them. Generation on the first run verifies creation, while repeat runs also check the existing settings. The additional cleanup Role grants delete permission only for the named fixture in this namespace. The binding assumes the Helm release and controller names from the quickstart.

To remove the second exercise, delete its policies first, then its namespace:

```bash
kubectl --context kyverno-lab delete -f cel/policies/
kubectl --context kyverno-lab delete ns cel-demo
```
