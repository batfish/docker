**Got questions, feedback, or feature requests? Join our community on [Slack!](https://join.slack.com/t/batfish-org/shared_invite/enQtMzA0Nzg2OTAzNzQ1LTUxOTJlY2YyNTVlNGQ3MTJkOTIwZTU2YjY3YzRjZWFiYzE4ODE5ODZiNjA4NGI5NTJhZmU2ZTllOTMwZDhjMzA)**

# Batfish Docker Containers

This repo has the source files to build `Batfish` and `allinone` docker containers that provide a quick way to start using Batfish. 

Follow the instructions in the [Batfish README](https://github.com/batfish/batfish/blob/master/README.md) to start using the container.


## Upgrading the `Batfish` container

```
docker stop $(docker ps -f "ancestor=batfish/batfish" -q)
docker pull batfish/batfish
```

## Upgrading the `allinone` container

```
docker stop $(docker ps -f "ancestor=batfish/allinone" -q)
docker pull batfish/allinone
```

## Building and pushing containers

If you are a developer of Batfish, see [dev instructions](README.dev.md) on how to build images and push them to Docker Hub.
