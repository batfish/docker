# Allinone Batfish docker container

This container bundles the Batfish service, the Pybatfish SDK, and its example Jupyter notebooks for convenient introduction to Batfish and Pybatfish.

## Running the container

To run the container, make sure that the Docker daemon is running, and then run:

1. `mkdir -p data` -- Sets up a folder for persistent storage
2. `mkdir -p custom_networks` -- Sets up a folder for you to put network configurations (can be empty for now)
3. Run the docker container:
    ```
    docker run \
      -v $(pwd)/custom_networks:/notebooks/custom_networks:ro -v $(pwd)/data:/data \
      -v /etc/group:/etc/group:ro -v /etc/passwd:/etc/passwd:ro --user=$(id -u):$(id -g) \
      --env HOME="/notebooks" -p 9995:8888 -p 9996:9996 -p 9997:9997 batfish/allinone:latest
    ```

    The above command allows Batfish to pass data to and from the host machine (and to make internal Batfish data persist across container instances) and runs the container as the current user (making any files created by the container owned and accessible by the current user on the host machine).  It also sets up ports to access Jupyter notebooks (9995) and Batfish itself (9996, 9997).

Once the container starts, Jupyter will show a token required for access (e.g. token=`abcdef123456...`).  Navigate to `http://localhost:9995` in a web browser on the host machine and enter this token in the "Password or token:" prompt to access the notebooks.

## Upgrading the container

To upgrade the container, run the following commands:
```
docker stop $(docker ps -f "ancestor=batfish/allinone" -q)
docker pull batfish/allinone
docker run \
  -v $(pwd)/custom_networks:/notebooks/custom_networks:ro -v $(pwd)/data:/data \
  -v /etc/group:/etc/group:ro -v /etc/passwd:/etc/passwd:ro --user=$(id -u):$(id -g) \
  --env HOME="/notebooks" -p 9995:8888 -p 9996:9996 -p 9997:9997 batfish/allinone:latest
```

These commands stop the currently running container, pull the latest one, and then start it.
