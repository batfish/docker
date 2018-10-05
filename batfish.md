# Batfish service docker image

This image contains only the core Batfish service.

## Running the image

To start the Batfish service, run the following commands:

1. `mkdir -p data`
2. `docker run -v $(pwd)/data:/data -p 9997:9997 -p 9996:9996 batfish/batfish`

    You can now use the [Pybatfish client](pybf) on the host machine to interact with the service.

## Upgrading

To upgrade the docker container, simply run:

1. `docker stop $(docker ps -f "ancestor=batfish/batfish" -q)` -- Stops the currently running container
2. `docker pull batfish/batfish` -- Pulls the latest image from Docker Hub

    Then you can restart the container with same docker run command you used to start it (e.g. `docker run -v $(pwd)/data:/data -p 9997:9997 -p 9996:9996 batfish/batfish`).

    Note when running with persistent storage, previously uploaded network snapshots may be incompatible with newer versions of Batfish and may need to be re-uploaded.


[pybf]: https://github.com/batfish/pybatfish