# Galaxy Kubernetes Manifests

Files in this folder represent a preliminary version of the Kubernetes
manifest files for running Galaxy. This is largely work-in-progress with plans
for these files to be converted into a Helm Chart but meanwhile used as a proof
of concept and for reference.

## Setup

To deploy available manifests, we'll need a running instance of Kubernetes,
which can easily be obtained by enabling it in your Docker installation.
With that, we'll also need the `kubectl` utility.

We'll also need to deploy [the Kubernetes Dashboard](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/#deploying-the-dashboard-ui) and [the NGINX ingress](https://kubernetes.github.io/ingress-nginx/deploy/).

Last, let's grab a copy of the Galaxy database from
<https://galaxy-helm.s3.amazonaws.com/galaxy-db-146.tar.gz>. For the default
configuration, download the file to `/tmp/docker/volumes/postgres/` and extract
the content.

Next, create a directory for persisting Galaxy's data. By default, this is in
`/tmp/k8s/volumes/galaxy/data`. Finally, clone this repo and change into the
`k8s` subdirectory.

## Deploy PostgreSQL

Run the following set of commands in the specified order to deploy all the
components required to run Postgres:

```bash
kubectl create -f postgres-configmap.yml
kubectl create -f postgres-storage.yml
kubectl create -f postgres-deployment.yml
kubectl create -f postgres-service.yml
```

## Deploy Galaxy

We'll need to run a similar set of commands for Galaxy:

```bash
kubectl create -f galaxy-configmap.yml
kubectl create -f galaxy-pv.yml
kubectl create -f galaxy-web-deployment.yml
kubectl create -f galaxy-job-deployment.yml
kubectl create -f galaxy-service.yml
kubectl create -f galaxy-ingress.yml
```

After a few moments, Galaxy should be accessible under <https://localhost/>.

Resources created can be inspected in the Kubernetes dashboard, and Galaxy's
web/job handlers scaled.
