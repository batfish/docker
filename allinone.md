# Allinone Batfish docker image

This image contains the [Batfish service][bf], the [Pybatfish client][pybf], and the example
Jupyter notebooks for convenient introduction to Batfish capabilities.

## Available tags
Currently the `latest` tag is the most preferred way to get a working version.

## Running the image, no persistent storage

To run the `allinone` docker image for the first time, run:

1. `docker pull batfish/allinone` -- This pulls the image
2. `mkdir -p networks` -- Sets up a folder for you to put network configurations (can be empty for now)
3. Run the docker container:
```
docker run \
  -v $(pwd)/networks:/notebooks/custom_networks:ro \
  -v /etc/group:/etc/group:ro \
  -v /etc/passwd:/etc/passwd:ro --user=$(id -u):$(id -g) \
  --env HOME="/notebooks" -p 8888:8888 batfish/allinone:latest
```
This does several things to enable data to be passed into the container from the host:
* Makes the `networks` directory on the host owned and accessible by the current user
* Runs Batfish and Jupyter processes in the container as the current user
* Mounts the host's `networks` dir as read-only for the container (specifically Jupyter) to view its contents
* Mounts the host's `group` and `passwd` files so the host user can run Batfish and Jupyter inside the container 
  (so any files created are owned and accessible by them on the host as well as in the container)
* Forwards the container Jupyter port to the host's port 8888, so notebooks can be accessed from the host machine with `http://localhost:8888/`

## Running the image with persistent storage

1. `docker pull batfish/allinone` -- This pulls the image
2. `mkdir -p networks` -- Sets up a folder for you to put network configurations (can be empty for now)
3. `mkdir -p data` -- Sets up a folder for persistent storage
4. Run the docker container:
```
docker run \
  -v $(pwd)/networks:/notebooks/custom_networks:ro \
  -v $(pwd)/data:/data -v /etc/group:/etc/group:ro \
  -v /etc/passwd:/etc/passwd:ro --user=$(id -u):$(id -g) \
  --env HOME="/notebooks" -p 8888:8888 batfish/allinone:latest
```

This allows Batfish to store data on your disk so that if you stop/delete and restart the container, 
internal Batfish data remains.

[bf]: https://github.com/batfish/batfish
[pybf]: https://github.com/batfish/pybatfish
