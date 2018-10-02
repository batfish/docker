# Batfish service docker image

This image contains only the core Batfish service.

There are two main options for running the Docker image, detailed below:
* Running the image (stand alone) - simplest configuration; good for most users working with Batfish
* Running with persistent storage - allows data produced by Batfish to persist across different instantiations of the docker image; good for some advanced users or developers

## Running the image (stand alone)

To run the Batfish service, simply run the following command:

`docker run -p 9997:9997 -p 9996:9996 batfish/batfish`

You can now use the [Pybatfish client](https://github.com/batfish/pybatfish) on the host machine to interact with the service.

## Running with persistent storage

If you'd like to save Batfish state across different invocations of the container, simply mount a folder (or volume) over `/data`, like so:

`mkdir data && docker run -v $(pwd)/data:/data -p 9997:9997 -p 9996:9996 batfish/batfish`
