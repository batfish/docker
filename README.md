**Got questions, feedback, or feature requests? Join our community on [Slack!](https://join.slack.com/t/batfish-org/shared_invite/enQtMzA0Nzg2OTAzNzQ1LTUxOTJlY2YyNTVlNGQ3MTJkOTIwZTU2YjY3YzRjZWFiYzE4ODE5ODZiNjA4NGI5NTJhZmU2ZTllOTMwZDhjMzA)**

# Batfish Docker Containers

This repo has the source files to build `Batfish` and `allinone` docker containers that provide a quick way to start using Batfish. The `Batfish` container has only the core [Batfish](https://github.com/batfish/batfish) service, and the `allinone` container also inlcudes [Pybatfish](https://github.com/batfish/pybatfish).

We recommend using the `Batfish` container if you plan to analyze your own network data, and the `allinone` container if you want to just play with the example data and Jupyter notebooks bundled with `Pybatfish`.

## Using the `allinone` container

Detailed instructions are [here](allinone.md), but a short version is:

1. Start the container
```
mkdir -p data
mkdir -p networks
docker run \
  -v $(pwd)/networks:/notebooks/custom_networks:ro \
  -v $(pwd)/data:/data -v /etc/group:/etc/group:ro \
  -v /etc/passwd:/etc/passwd:ro --user=$(id -u):$(id -g) \
  --env HOME="/notebooks" -p 9995:8888 -p 9996:9996 \
  -p 9997:9997 batfish/allinone:latest
```

2. Step through Jupyter notebooks with the example networks
    * When the Docker container starts, Jupyter will show a token required for access (e.g. token=abcdef123456...)
    * Navigate to http://localhost:9995 in a web browser on the host machine and enter this token in the "Password or token:" prompt to access the notebooks
    * Select one of the notebooks (`Getting started with Batfish.ipynb` is a good place to start!)

## Going further (with custom networks)

1. Install `Pybatfish` on your host machine:
```
pip install git+git://github.com/batfish/pybatfish.git#egg=pybatfish
```

2. Put your network snapshots in the `networks/` directory created in the previous steps (see [here for details on how to package a network snapshot](https://github.com/batfish/batfish/wiki/Packaging-snapshots-for-analysis)).

3. See [here](https://pybatfish.readthedocs.io/en/latest/index.html) for the `Pybatfish` getting started guide and complete documentation of `Pybatfish` APIs.

## Building and pushing containers

If you are a developer of `Batfish`, see [dev instructions](README.dev.md) on how to build images and push them to Docker Hub.
