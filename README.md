# Artello Builder

Artello Builder is the base image that sets everything up for an Artello Cluster. 

It builds / tests the code and ships it to the package manager and also orchestrates deployments and upgrades inside the cluster.

# Dependencies

+ Buildkite - Buildkite is the CI service that will orchestrate the build process. This image will look for the BUILDKITE_AGENT_TOKEN so attach a profile with the following config

```yml
config:
  user.BUILDKITE_AGENT_TOKEN: youragenttoken
```

# Usage

Use Packer to build the image from your local computer, set the default as your target cluster so packer will build and place the image on your cluster.

```bash
packer build packer.json
```
