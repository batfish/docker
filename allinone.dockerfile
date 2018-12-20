ARG TAG=latest
FROM arifogel/batfish:$TAG

# ASSETS is the directory containing the Pybatfish Python wheel, wrapper.sh,
# and the notebooks/ directory (containing the Jupyter notebooks)
ARG ASSETS
# PYBATFISH_VERSION is the version number embedded in the Python wheel in the ASSETS dir
ARG PYBATFISH_VERSION

COPY ${ASSETS} ./
RUN chmod a+x wrapper.sh

# Base package setup
RUN sed -i.bak -e 's/\(archive\|security\).ubuntu.com/us-west-1.ec2.archive.ubuntu.com.s3.amazonaws.com/g' \
      /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y \
      python3 \
      python3-pip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


# Pybatfish + Jupyter
EXPOSE 8888
RUN pip3 install \
      pybatfish-${PYBATFISH_VERSION}-py2.py3-none-any.whl \
      attrdict \
      jupyter \
      matplotlib \
      networkx \
    && rm pybatfish-${PYBATFISH_VERSION}-py2.py3-none-any.whl \
    && find notebooks -type d -exec chmod 777 {} \; \
    && find notebooks -type f -exec chmod 666 {} \;

# Run both Batfish and Jupyter notebook
ENTRYPOINT ["./wrapper.sh"]
