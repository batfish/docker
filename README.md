# Batfish Docker Images

This repo contains the source files necessary to build [Batfish](https://github.com/batfish/batfish) and 
`allinone` (Batfish plus [Pybatfish](https://github.com/batfish/pybatfish) and Jupyter) docker images.  

Using one of the pre-built containers from [Docker hub](https://hub.docker.com/u/batfish/dashboard/) 
is the quickest and easiest way to get started using Batfish.

## Running Containers

* For a getting started experience, follow the [All-in-one guide](allinone.md).
* For running the Batfish service *only*, follow the [Service guide](batfish.md).

## Building and Pushing images

If you are a developer of batfish see [dev instructions](README.dev.md) on how to build images
and push them to docker hub.