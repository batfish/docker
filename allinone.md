# Allinone Batfish docker image

This image contains the [Batfish service][bf], the [Pybatfish client][pybf], and the example
Jupyter notebooks for convenient introduction to Batfish capabilities.

It requires [Docker][docker] to be installed and running.

## Running the image

There are three main options for running the Docker image, detailed below:
* [Running the image stand-alone](#running-the-image-stand-alone) - simplest configuration; recommended for first time users just exploring Batfish
* [Running with custom networks](#running-with-your-own-network-configurations) - allows users to pass data into the container; recommended for users interested in analyzing their networks with Batfish
* [Running with persistent storage](#running-with-persistent-storage-and-your-own-network-configurations) - allows data produced by Batfish to persist across different instantiations of the docker image; recommended for advanced users or developers

Note that after the container starts, Jupyter will show a token required to access notebooks (e.g. token=`abcdef123456...`).  Once the container is running, navigate to `http://localhost:8888` in a web browser on the host machine and enter the Jupyter token in the "Password or token:" prompt.

### Running the image stand-alone

To run the `allinone` docker image, and use the notebooks and example network bundled with the image:

1. Run `docker run -p 8888:8888 batfish/allinone`.


### Running with your own network configurations

To use your own network configurations, instead of those bundled in the Docker image:

1. `mkdir -p networks` -- Sets up a folder for you to put network configurations (can be empty for now)
2. Run the docker container:
    ```
    docker run \
      -v $(pwd)/networks:/notebooks/custom_networks:ro \
      -p 8888:8888 batfish/allinone
    ```

    This gives the container (specifically Jupyter) read-only access to the networks directory created above.

### Running with persistent storage (and your own network configurations)

To allow Batfish to store data on your disk (to make internal Batfish data persist across container instances and make it accessible by the current user on the host machine):

1. `mkdir -p networks` -- Sets up a folder for you to put network configurations (can be empty for now)
2. `mkdir -p data` -- Sets up a folder for persistent storage
3. Run the docker container:
    ```
    docker run \
      -v $(pwd)/networks:/notebooks/custom_networks:ro \
      -v $(pwd)/data:/data -v /etc/group:/etc/group:ro \
      -v /etc/passwd:/etc/passwd:ro --user=$(id -u):$(id -g) \
      -p 8888:8888 batfish/allinone
    ```

## Upgrading

To upgrade the docker container, simply run:

1. `docker stop $(docker ps -f "ancestor=batfish/allinone" -q)` -- Stops the currently running allinone container
2. `docker pull batfish/allinone` -- Pulls the latest image from Docker Hub

    Then you can use the same docker run command you used to start the container (e.g. `docker run -p 8888:8888 batfish/allinone`).

    Note if running with persistent storage, previously uploaded network snapshots may be incompatible with newer version of Batfish and may need to be re-uploaded.


[bf]: https://github.com/batfish/batfish
[docker]: https://www.docker.com/get-started
[pybf]: https://github.com/batfish/pybatfish