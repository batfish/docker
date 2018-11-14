# Batfish service docker container

This container contains the core Batfish service.

## Running the container

To start the service, make sure that the Docker daemon is running, and then run the following commands:
```
mkdir -p data
docker run -v $(pwd)/data:/data -p 9997:9997 -p 9996:9996 batfish/batfish
```
The first command creates a folder on the host machine where Batfish will persist data across container reboots. The second command starts the service after mapping this folder from within the container and mapping the needed ports. 
    
You can now use the [Pybatfish client](https://github.com/batfish/pybatfish) to interact with the service.

## Upgrading the container

To upgrade the container, simply run:
```
docker stop $(docker ps -f "ancestor=batfish/batfish" -q)
docker pull batfish/batfish
docker run -v $(pwd)/data:/data -p 9997:9997 -p 9996:9996 batfish/batfish
```

The first two commands stop the currently running container and pull the latest image from Docker Hub. 

The third command restarts the container. It assumes that you are running it from the same folder where you originally started the container. If running from other folders, make appropriate modifications to the `$(pwd)/data` part of the command.

**Note:** After upgrading the container, previously uploaded network snapshots may sometimes become incompatible with newer versions of Batfish and may need to be re-initialized.
