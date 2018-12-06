# Building and pushing images

1. Run `sh build_images.sh build`
    
   Upon successful build, the build script should output names and tags of the containers built (the tags contain SHAs of the source used to build the containers):
    
   ```
   ...
   Built batfish/batfish:sha_ABCDEF
   Built batfish/allinone:sha_ABCDEF_123456
   ```
   
2. Set env vars based on the SHA values (make sure to replace the SHA values with those from the output of the previous step):
    
   ```
   BATFISH_TAG=ABCDEF
   PYBATFISH_TAG=123456
   ```
   
3. Start the new `allinone` container:
    
   ```
   mkdir -p data
   docker run -v $(pwd)/data:/data -p 8888:8888 batfish/allinone:sha_${BATFISH_TAG}_${PYBATFISH_TAG}
   ```
   
4. Open browser to https://localhost:8888

5. Step through a couple notebooks, making sure they run as expected

6. If all goes well, push the containers

   ```
   docker push batfish/batfish:sha_${BATFISH_TAG}
   docker push batfish/batfish:latest
   docker push batfish/allinone:sha_${BATFISH_TAG}_${PYBATFISH_TAG}
   docker push batfish/allinone:latest
   ```

## build_images.sh Usage
A `build_images.sh` script is provided that:
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
