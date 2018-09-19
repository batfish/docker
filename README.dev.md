# Building and pushing images

A single `build_images.sh` script is provided that:
- Builds a Batfish docker image,
- Tests it with Pybatfish integration tests,
- Builds an `allinone` docker image (with Jupyter, Pybatfish, and Batfish), 
- And finally pushes both of these images to the public Batfish organization on Docker Hub.  

Specific Batfish and Pybatfish commit hashes can be passed into the script 
to build from those commits instead of `HEAD` at `master` (the default). For example, the following command will build images from the Batfish commit `3337ec...` and Pybatfish commit `ddcb50...`:
```
sh build_images.sh 3337ecf49f9f754d502e8aa5443919bea18afdd6 ddcb50bb8c05cbcfa71c261c146bc1360e581961
```
Any image built will be tagged with the corresponding Batfish and Pybatfish commits and the `latest` tag.

**NOTE: If you have the correct permissions to Docker Hub, the images will be pushed to Docker Hub.**
