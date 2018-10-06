# Batfish Docker Containers

This repo has the source files to build `Batfish` and `allinone` docker containers. The former has only the core [Batfish](https://github.com/batfish/batfish) service, and the latter also inlcudes [Pybatfish](https://github.com/batfish/pybatfish) and Jupyter. These containers provide a quick way to start using Batfish.

## Running the containers

We recommend the `Batfish` container if you plan to analyze your own network data. Use the `allinone` container if you want to just play with the data and Jupyter notebooks bundled with Pybatfish. 

#### `Batfish` container

Detailed instructions for the `Batfish` container are [here](batfish.md), but a short version is:
```
mkdir -p data
docker run -v $(pwd)/data:/data -p 9997:9997 -p 9996:9996 batfish/batfish
```
These commands start the service, and you can then use [Pybatfish](https://github.com/batfish/pybatfish) to interact with it.

#### `allinone` container

Detailed instructions for the `allinone` container are [here](allinone.md), but a short version is:
```
docker run -p 8888:8888 batfish/allinone
```
When this container starts, Jupyter will show a token required to access notebooks (e.g. token=abcdef123456...). Navigate to http://localhost:8888 in a web browser on the host machine and enter this token in the "Password or token:" prompt to access the notebooks.

## Building and pushing containers

If you are a developer of Batfish, see [dev instructions](README.dev.md) on how to build images and push them to Docker Hub.
