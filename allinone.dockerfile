ARG TAG=latest
FROM batfish/batfish:$TAG

# ASSETS is the directory containing the Pybatfish Python wheel, wrapper.sh,
# and the notebooks/ directory (containing the Jupyter notebooks)
ARG ASSETS

COPY ${ASSETS} ./
RUN chmod a+x wrapper.sh

RUN apt-get update \
    && apt-get install -y \
       python3 \
       python3-pip \
    && apt-get upgrade -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install --upgrade pip

# Pybatfish + Jupyter
EXPOSE 8888
RUN pip3 install $(ls pybatfish-*.whl) \
    attrdict \
    jupyter \
    matplotlib \
    networkx \
    && rm pybatfish-*.whl \
    && find notebooks -type d -exec chmod 777 {} \; \
    && find notebooks -type f -exec chmod 666 {} \;

# Run both Batfish and Jupyter notebook
ENTRYPOINT ["./wrapper.sh"]
