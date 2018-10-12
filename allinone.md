# Allinone Batfish docker container

This container bundles the Batfish service, the Pybatfish SDK, and its example Jupyter notebooks for convenient introduction to Batfish and Pybatfish.

## Running the container

To run the container, make sure that the Docker daemon is running, and then run:
```
docker run -p 9995:8888 batfish/allinone
```
Once the container starts, Jupyter will show a token required for access (e.g. token=`abcdef123456...`).  Navigate to `http://localhost:9995` in a web browser on the host machine and enter this token in the "Password or token:" prompt to access the notebooks.

## Upgrading the container

To upgrade the container, run the following commands:
```
docker stop $(docker ps -f "ancestor=batfish/allinone" -q)
docker pull batfish/allinone
docker run -p 9995:8888 batfish/allinone
```

These commands stop the currently running container, pull the latest one, and then start it.
