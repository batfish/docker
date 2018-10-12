**Got questions, feedback, or feature requests? Join our community on [Slack!](https://join.slack.com/t/batfish-org/shared_invite/enQtMzA0Nzg2OTAzNzQ1LTUxOTJlY2YyNTVlNGQ3MTJkOTIwZTU2YjY3YzRjZWFiYzE4ODE5ODZiNjA4NGI5NTJhZmU2ZTllOTMwZDhjMzA)**

# Batfish Docker Containers

This repo has the source files to build `Batfish` and `allinone` docker containers that provide a quick way to start using Batfish. The `Batfish` container has only the core [Batfish](https://github.com/batfish/batfish) service, and the `allinone` container also inlcudes [Pybatfish](https://github.com/batfish/pybatfish).

We recommend using the `allinone` container to get started, as it comes bundled with `Pybatfish` and example networks and notebooks.

## Setting up the `allinone` container

Additional instructions are located [here](allinone.md), but a short version is:

Create data directories and start the container:
```
mkdir -p data
mkdir -p custom_networks
docker run \
  -v $(pwd)/custom_networks:/notebooks/custom_networks:ro -v $(pwd)/data:/data \
  -v /etc/group:/etc/group:ro -v /etc/passwd:/etc/passwd:ro --user=$(id -u):$(id -g) \
  --env HOME="/notebooks" -p 9995:8888 -p 9996:9996 -p 9997:9997 batfish/allinone:latest
```
    The docker command above passes current user information into the container (so files created by the container are owned by and visible to the user running docker) and mounts the `data/` and `custom_networks/` directories in order to pass data between the host machine and the container.

## Exploring bundled networks and notebooks

Navigate to the Jupyter notebooks:
    * When the Docker container starts, Jupyter will show a token on the console output, required for access (e.g. token=abcdef123456...)
    * Navigate to http://localhost:9995 in a web browser on the host machine and enter this token in the "Password or token:" prompt to access the notebooks
    * Select and step through one of the notebooks (`Getting started with Batfish.ipynb` is a good place to start!)

## Going further (with custom networks)

1. Install `Pybatfish` on your host machine:
    ```
    pip install git+git://github.com/batfish/pybatfish.git#egg=pybatfish
    ```

2. Put your network snapshots in the `custom_networks/` directory created in the previous steps (see [here for details on how to package a network snapshot](https://github.com/batfish/batfish/wiki/Packaging-snapshots-for-analysis)).

3. See [here](https://pybatfish.readthedocs.io/en/latest/index.html) for the `Pybatfish` getting started guide and complete documentation of APIs.

## Building and pushing containers

If you are a developer of `Batfish`, see [dev instructions](README.dev.md) on how to build images and push them to Docker Hub.
