# Batfish Docker Images

This repo contains the files necessary to build [Batfish](https://github.com/batfish/batfish) and `allinone` (Batfish plus [Pybatfish](https://github.com/batfish/pybatfish) and Jupyter) docker images.  Using one of the prebuilt containers from [Docker hub](https://hub.docker.com/u/batfish/dashboard/) is the quickest and easiest way to get started using Batfish.


## Building and Pushing

The `build_images.sh` script builds a Batfish docker image, tests it with Pybatfish integration tests, builds an `allinone` docker image (with Jupyter, Pybatfish, and Batfish), and finally pushes both of these images to the public Batfish organization on docker hub.  Specific Batfish and Pybatfish commit hashes can be passed into the script to build from those commits instead of head (the default).  For example, the following command will build images from the Batfish commit `3337ec...` and Pybatfish commit `ddcb50...`:
```
sh build_images.sh 3337ecf49f9f754d502e8aa5443919bea18afdd6 ddcb50bb8c05cbcfa71c261c146bc1360e581961
```
Any image built will be tagged with the corresponding Batfish and Pybatfish commits.


## Running Containers

### Allinone
To run the Batfish + Pybatfish + Jupyter docker image for the first time, run:
```
mkdir -p networks
docker run -v $(pwd)/networks:/notebooks/custom_networks:ro -v /etc/group:/etc/group:ro -v /etc/passwd:/etc/passwd:ro --user=$(id -u) --env HOME="/notebooks" -p 8888:8888 batfish/allinone:latest
```
This does several things to enable data to be passed into the container from the host:
* Creates `networks` directory on the host owned and accessible by the current user
* Runs Batfish and Jupyter processes in the container as the current user
* Mounts the host's `networks` dir as read-only for the container (specifically Jupyter) to view its contents
* Mounts the host's `group` and `passwd` files so the host user can run Batfish and Jupyter inside the container (so any files created are owned and accessible by them on the host as well as in the container)
* Forwards the container Jupyter port to the host's port 8888, so notebooks can be accessed from the host machine with `http://localhost:8888/`

Can alternatively run the following to gain access to the Batfish data saves on disk (and make that data persistent):
```
mkdir -p networks
mkdir -p data
docker run -v $(pwd)/networks:/notebooks/custom_networks:ro -v $(pwd)/data:/data -v /etc/group:/etc/group:ro -v /etc/passwd:/etc/passwd:ro --user=$(id -u) --env HOME="/notebooks" -p 8888:8888 batfish/allinone:latest
```

### Batfish
To run the docker image just containing Batfish, run:
```
docker run -p 9997:9997 -p 9996:9996 batfish/batfish:latest
```
