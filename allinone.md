# Allinone Batfish docker image

This image contains the [Batfish service][bf], the [Pybatfish client][pybf], and the example
Jupyter notebooks for convenient introduction to Batfish capabilities.

It requires [Docker][docker] to be installed and running.

There are three main ways to run the Docker image, detailed below:
* Running the image (stand alone) - simplest, isolated configuration; good for first time users just exploring Batfish
* Running with custom networks - this mounts a read-only directory from the host machine in the docker container, so custom networks can be passed into the container; good for most users interested in analyzing their networks
* Running with persistent storage - this builds on the previous invocation and adds a read-write directory for the data produced by Batfish to persist across different instantiations of the docker image

## Running the image (stand alone)

To run the `allinone` docker image for the first time, using the notebooks and example network bundled with the image:

1. Run `docker run -p 8888:8888 batfish/allinone`.  Note that after the container starts, Jupyter will show a token required to access notebooks (e.g. token=`abcdef123456...`).
2. Navigate to `http://localhost:8888` in a web browser on the host machine and enter the Jupyter token in the "Password or token:" prompt.


## Running with custom networks

To run on your own network configurations, instead of those bundled in the Docker image:

1. `docker pull batfish/allinone` -- This pulls the latest image from Docker Hub
2. `mkdir -p networks` -- Sets up a folder for you to put network configurations (can be empty for now)
3. Run the docker container:
    ```
    docker run \
      -v $(pwd)/networks:/notebooks/custom_networks:ro \
      -p 8888:8888 batfish/allinone
    ```

    This gives the container (specifically Jupyter) read-only access to the networks directory created above.

## Running with persistent storage

To allow Batfish to store data on your disk (to make internal Batfish data persist across container instances and make it accessible by the current user on the host machine):

1. `docker pull batfish/allinone` -- This pulls the latest image from Docker Hub
2. `mkdir -p networks` -- Sets up a folder for you to put network configurations (can be empty for now)
3. `mkdir -p data` -- Sets up a folder for persistent storage
4. Run the docker container:
    ```
    docker run \
      -v $(pwd)/networks:/notebooks/custom_networks:ro \
      -v $(pwd)/data:/data -v /etc/group:/etc/group:ro \
      -v /etc/passwd:/etc/passwd:ro --user=$(id -u):$(id -g) \
      -p 8888:8888 batfish/allinone
    ```

[bf]: https://github.com/batfish/batfish
[docker]: https://www.docker.com/get-started
[pybf]: https://github.com/batfish/pybatfish
