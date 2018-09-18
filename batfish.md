# Batfish service docker image

This image contains only the core batfish service. 

## Available tags

Currently the `latest` tag is the most preferred way to get a working version

## Running the container

To run the Batfish service run the following:

 1. `docker pull batfish/batfish`
 2. `docker run -p 9997:9997 -p 9996:9996 batfish/batfish`

You can now use the Pybatfish client to interact with the service.

### Running with persistent storage

If you'd like to save batfish state across different invocations of the container, 
simply mount a folder (or volume) over `/data`, like so:

`mkdir data && docker run -v $(pwd)/data:/data -p 9997:9997 -p 9996:9996 batfish/batfish`
