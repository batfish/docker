# Setting the parent image to ubuntu
FROM ubuntu:20.04
LABEL vendor="The Batfish Open Source Project"

ARG GOOGLE_JAVA_FORMAT_VERSION=1.10.0
ARG JACOCO_VERSION=0.8.2
ARG MAVEN_VERSION=3.8.3
ARG BAZELISK_VERSION=1.10.1
ARG USERNAME=batfish
ARG UID=2000

# Set a Working Dir
User root
WORKDIR /root/workdir

# Installing Java, python
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    binutils \
    ca-certificates \
    curl \
    gcc \
    git \
    jq \
    net-tools \
    openjdk-11-jdk \
    python3-distutils \
    rsync \
    software-properties-common \
    unzip \
    zip \
&&  rm -rf /var/lib/apt/lists/* \
&&  apt-get clean

# Install pip and virtualenv
RUN curl -L https://bootstrap.pypa.io/get-pip.py | python3 \
&& python3 -m pip install 'virtualenv==20.0.5'

# Install bazelisk
RUN curl -L https://github.com/bazelbuild/bazelisk/releases/download/v${BAZELISK_VERSION}/bazelisk-linux-amd64 -o bazelisk-linux-amd64 \
&&  install -m0755 bazelisk-linux-amd64 /usr/local/bin/bazelisk \
&&  ln -s /usr/local/bin/bazelisk /usr/local/bin/bazel \
&&  rm bazelisk-linux-amd64

##### Switch to non-root-user

RUN groupadd -g ${UID} ${USERNAME} \
&& useradd -m -r -u ${UID} -g ${USERNAME} ${USERNAME} \
&& mkdir -p /home/${USERNAME}/workdir \
&& chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}
USER ${USERNAME}
WORKDIR /home/${USERNAME}/workdir

# Create AWS-CLI virtualenv
RUN python3 -m virtualenv .venv-aws && . .venv-aws/bin/activate && python3 -m pip install 'awscli==1.18.5' && deactivate

# Install maven
RUN curl -L https://apache.osuosl.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.zip -o apache-maven-${MAVEN_VERSION}-bin.zip \
&& unzip apache-maven-${MAVEN_VERSION}-bin.zip \
&& rm -f apache-maven-${MAVEN_VERSION}-bin.zip

# Setup JAVA_HOME
ENV JAVA_HOME /usr/lib/jvm/java-11-openjdk-amd64/

# Add Maven to PATH
ENV PATH $PATH:/home/${USERNAME}/workdir/apache-maven-${MAVEN_VERSION}/bin:/home/${USERNAME}/bin

# Fetch all the current Maven dependencies and bazel version
RUN git clone --depth=1 --branch=master https://github.com/batfish/batfish \
&& cd batfish \
&& mvn -f projects verify -DskipTests=false \
&& mvn -f projects dependency:get -Dartifact=com.google.googlejavaformat:google-java-format:${GOOGLE_JAVA_FORMAT_VERSION}:jar:all-deps \
&& mvn -f projects dependency:get -Dartifact=org.jacoco:org.jacoco.cli:${JACOCO_VERSION}:jar:nodeps \
&& bazel version \
&& cd .. \
&& rm -rf batfish
