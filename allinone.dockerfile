FROM ubuntu:24.04

# ASSETS is the directory containing allinone-bundle.jar (the Batfish jar)
# and questions/ directory (containing question templates to be loaded by Batfish)
ARG ASSETS

# Make /data dir available to any user, so this container can be run by any user
RUN mkdir -p /data
RUN chmod a+rw /data
COPY ${ASSETS} ./
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64/
ENV JAVA_LIBRARY_PATH=/usr/lib
ENV HOME=/data

COPY ${ASSETS} ./
RUN chmod a+x wrapper.sh

# Base package setup
RUN apt-get update \
    && apt-get install -y \
       openjdk-17-jre-headless \
       python3 \
       python3-pip \
       python3-wheel \
    && apt-get upgrade -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/oracle*

# Python setup.
RUN pip3 install --break-system-packages \
    $(ls pybatfish-*.whl) \
    attrdict \
    jupyter \
    matplotlib \
    networkx \
    && rm pybatfish-*.whl \
    && find notebooks -type d -exec chmod 777 {} \; \
    && find notebooks -type f -exec chmod 666 {} \;

# Batfish, Jupyter
EXPOSE 9996 8888

# Run both Batfish and Jupyter notebook
ENTRYPOINT ["./wrapper.sh"]
