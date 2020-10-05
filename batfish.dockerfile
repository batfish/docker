FROM ubuntu:18.04

# ASSETS is the directory containing allinone-bundle.jar (the Batfish jar)
# and questions/ directory (containing question templates to be loaded by Batfish)
ARG ASSETS

# Make /data dir available to any user, so this container can be run by any user
RUN mkdir -p /data
RUN chmod a+rw /data
COPY ${ASSETS} ./
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/
ENV JAVA_LIBRARY_PATH /usr/lib
ENV HOME /data

# Base package setup
RUN apt-get update && apt-get install -y \
    binutils \
    libgomp1 \
    lsb-release \
    openjdk-8-jre-headless \
    wget \
    zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/oracle*

# Z3
ADD https://raw.githubusercontent.com/batfish/batfish/master/tools/install_z3.sh .
RUN bash install_z3.sh \
    && rm -r ~/.batfish_z3_cache/

# Batfish
EXPOSE 9996-9997
CMD ["java", \
    "-XX:-UseCompressedOops", \
    "-XX:+UnlockExperimentalVMOptions", \
    "-XX:+UseCGroupMemoryLimitForHeap", \
    "-XX:MaxRAMFraction=1", \
    "-cp", "allinone-bundle.jar", \
    "org.batfish.allinone.Main", \
    "-runclient", "false", \
    "-loglevel", "warn", \
    "-coordinatorargs", "-templatedirs questions -containerslocation /data/containers"]
