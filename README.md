# k8s-static-sites

A Helm Chart to deploy static sites in your kubernetes cluster.

## Installing

You can install the helm chart however you want. I myself run
this cluster by adding it in a Kustomize file and deploy the
chart using ArgoCD.

### Kustomize

You can configure the helm chart by adding this block to your
`kustomize.yaml` file:

```yaml
helmCharts:
  - name: k8s-static-sites
    namespace: sites
    repo: https://charts.mstiekema.nl
    version: vX.Y.Z
    valuesFile: sites-values.yaml
```

You can read more about the values configuration below.

### Local

To install this chart locally, you should first clone the
repository. Then you can configure the `values.yaml` as
described further in the README. Once you have done this you
can run the commands below:

```bash
helm dependency update
helm install k8s-static-sites . -f values.yaml --namespace <your-namespace> --create-namespace
```

To upgrade an existing installation, run:

```yaml
helm upgrade k8s-static-sites . -f values.yaml --namespace <your-namespace>
```

## How does it work?

This chart has the following dependencies:
- [rustfs](https://github.com/rustfs/rustfs): S3-like storage for
storing the built websites.
- [nginx](https://hub.docker.com/_/nginx): Docker image used for
serving files that are stored in `rustfs`.

These two combined with my own templates allow you to sync any of
the GitHub repository releases you can access to the storage and 
is then served by nginx. Each site will get an `HTTPRoute` which
can be connected to any Gateway API implementation of your
choosing.

### Fetching your site

Before you can link any of your repositories, you should add a
simple GitHub action that builds your site when a new change has
been made. I myself have added an action that creates a new release
for each commit pushed to the main branch. It will create a zip
of the dist folder and push that as an artifact to the release.
**Please note** that the name of each release should be unique,
because the script checks the release name to see whether the 
contents of the site should be updated.

### Updating your site

Right now, every 5 minutes a `CronJob` will run in the cluster
checking whether a new release was pushed. If this is the case,
the job will download the artifacts of the latest release and
push it to the linked bucket. If no change has been made, the
job quits.

## Configure

Before you do anything, please configure the following resources on
your own:

### Outside resources

- Create your own secret with the same name you configure in
`values.yaml` (`rustfs.secret.existingSecret`) with
`RUSTFS_ACCESS_KEY` and `RUSTFS_SECRET_KEY` as its keys. Use a
Vault CSI provider, [ESO](https://external-secrets.io/latest/)
or something like
[sealed-secrets](https://github.com/bitnami-labs/sealed-secrets) to
hide your secrets.
- Setup your Gateway API implementation so your sites can be accessed
through the linked `Gateway`. The Gateway has to be set in the
`values.yaml`.

### `values.yaml`

Once you have done that, you can start configuring your `values.yaml`
file. A minimal config should look like this:

```yaml
github:
  user: Mstiekema

gatewayApi:
  parentRef:
    name: gateway
    namespace: networking

sites:
  - name: example
    repo: example-site
    urls:
      - example.com
```

Read below for a more comprehensive explanation on each property
in the values file.

#### `github`

The `github` section contains the information from which user or
organisation you want to pull repositories to pull your sites
from. You should always configure the `user` property here. If you
want to deploy from private repositories, you should also add the
`secret` property as configured below.

```yaml
github:
  user: example
  secret:
    name: github-secret-name
    key: GITHUB_TOKEN
```

If you configure it like this, you should have a secret ready
in your cluster with that name and key configured. That will
allow this chart to pull the latest release of this repository
using the secret.

#### `gatewayApi`

Gateway API is the new standard for serving content to the
outside world. I myself use [Cilium](https://github.com/cilium/cilium)
but you could also use [Traefik](https://github.com/traefik/traefik)
or any other provider for serving the `HTTPRoute` resources.

```yaml
gatewayApi:
  parentRef:
    name: gateway
    namespace: networking
```

Make sure that all the CRDs are installed and you have a `Gateway`
already running with the provided parameters.


#### `nginx`

Some simple configuration for the `nginx` deployment. You don't
have to update/include this.

```yaml
nginx:
  name: nginx-static
  port: 80
```

#### `sites`

To configure the sites you actually want to deploy, you should
configure the `sites` array. Each object consists of the following
key-value pairs:

- `name`: Name of the site that is used in the resource name
and is the name of the bucket inside the storage provider.
- `repo`: The name of the repository in GitHub. For now this
should be a repository that is managed by the same user or
organisation you configure in the `github` object.
- `urls`: Array of strings that should equal the URLs from which
your website should be accessible.

```yaml
sites:
  - name: example
    repo: example-site
    urls:
      - example.com
```

#### `rustfs`

This part of the `values.yaml` enables `rustfs` and allows you
to set any values for your deployment. If you want you can tweak
the chart values as much as you want, but I only have it tested
with the pre-configured values.

```yaml
rustfs:
  enabled: true
  ...
```

## Future work

- Storage agnostic: Right now I've added rustfs as a hard
dependency for this chart. It should be possible to integrate
this chart with any storage/S3-like provider of your choosing.
- Add some better logic for checking whether an update has been
made to the site repository. A cronjob that runs every 5 minutes
is not the most efficient solution.
