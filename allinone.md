# Allinone Batfish docker image

This image contains the [Batfish service][bf], the [Pybatfish client][pybf], and the example
Jupyter notebooks for convenient introduction to Batfish capabilities.

It requires [Docker](https://www.docker.com/get-started) to be installed and running.

## Available tags
Currently the `latest` tag is the most preferred way to get a working version.

## Running the image

To run the `allinone` docker image for the first time, using the notebooks and example network bundled with the image:

1. Run `docker run -p 8888:8888 batfish/allinone`.  Note that after the container starts, Jupyter will show a token required to access notebooks (e.g. token=`abcdef123456...`).
2. Navigate to `http://localhost:8888` in a web browser on the host machine and enter the Jupyter token in the "Password or token:" prompt.


### Passing custom networks in

To instead run on your own network configurations:

1. `docker pull batfish/allinone` -- This pulls the latest image from Docker Hub
2. `mkdir -p networks` -- Sets up a folder for you to put network configurations (can be empty for now)
3. Run the docker container:
    ```
    docker run \
      -v $(pwd)/networks:/notebooks/custom_networks:ro \
      -p 8888:8888 batfish/allinone:latest
    ```

    This gives the container (specifically Jupyter) read-only access to the networks directory created above.

### Running with persistent storage

1. `docker pull batfish/allinone` -- This pulls the latest image from Docker Hub
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
    internal Batfish data remains (and is accessible by the current user).

[bf]: https://github.com/batfish/batfish
[pybf]: https://github.com/batfish/pybatfish
