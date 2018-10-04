# Batfish service docker image

This image contains only the core Batfish service.

## Running the image

There are two main options for running the Docker image, detailed below:
* [Running the image stand-alone](#running-the-image-stand-alone) - simplest configuration; recommended for most users working with Batfish
* [Running with persistent storage](#running-with-persistent-storage) - allows data produced by Batfish to persist across different instantiations of the docker image; recommended for advanced users or developers

### Running the image stand-alone

To run the Batfish service, simply run the following command:

1. `docker run -p 9997:9997 -p 9996:9996 batfish/batfish`

You can now use the [Pybatfish client](pybf) on the host machine to interact with the service.

### Running with persistent storage

If you'd like to save Batfish state across different invocations of the container, simply mount a folder (or volume) over `/data` in the container, like so:

1. `mkdir -p data`
2. `docker run -v $(pwd)/data:/data -p 9997:9997 -p 9996:9996 batfish/batfish`

## Upgrading

To upgrade the docker container, simply run:

1. `docker stop $(docker ps -f "ancestor=batfish/batfish" -q)` -- Stops the currently running container
2. `docker pull batfish/batfish` -- Pulls the latest image from Docker Hub

    Then you can restart the container with same docker run command you used to start it (e.g. `docker run -p 9997:9997 -p 9996:9996 batfish/batfish`).

    Note if running with persistent storage, previously uploaded network snapshots may be incompatible with newer version of Batfish and may need to be re-uploaded.


[pybf]: https://github.com/batfish/pybatfish