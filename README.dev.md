# Building and pushing images

A single `build_images.sh` script is provided that:
- Builds a Batfish docker image
- Tests it with Pybatfish integration tests
- Builds an `allinone` docker image (with Jupyter, Pybatfish, and Batfish)
- And optionally pushes both of these images to the public Batfish organization on Docker Hub

The script takes in three optional, ordered parameters:
- build|push (default is to build the images, not push them)
- specific Batfish commit (default is to use `HEAD` at `master`)
- specific Pybatfish commit (default is to use `HEAD` at `master`)

For example, the following command will build and push images from the Batfish commit `3337ec...` and Pybatfish commit `ddcb50...`:
```
sh build_images.sh push 3337ecf49f9f754d502e8aa5443919bea18afdd6 ddcb50bb8c05cbcfa71c261c146bc1360e581961
```
To build from head, simply run:
```
sh build_images.sh
```
Any image built will be tagged with the corresponding Batfish and Pybatfish commits and the `latest` tag.
