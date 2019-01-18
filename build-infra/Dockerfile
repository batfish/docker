# Setting the parent image to ubuntu
FROM ubuntu:16.04
LABEL vendor="The Batfish Open Source Project"

ARG GOOGLE_JAVA_FORMAT_VERSION=1.7
ARG JACOCO_VERSION=0.8.2
ARG MAVEN_VERSION=3.6.0
ARG BAZEL_VERSION=0.21.0
ARG USERNAME=batfish
ARG UID=2000

# Set a Working Dir
WORKDIR /root/workdir

# Installing Java, python, z3 dependencies
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    binutils \
    ca-certificates \
    curl \
    gcc \
    git \
    jq \
    lsb-release \
    net-tools \
    openjdk-8-jdk \
    python-minimal \
    python3-dev \
    software-properties-common \
    unzip \
    wget \
    zip \
&&  rm -rf /var/lib/apt/lists/* \
    /var/cache/oracle-jdk8-installer \
&&  apt-get clean

# Install pip and virtualenv
RUN curl https://bootstrap.pypa.io/get-pip.py | python3 \
&& python3 -m pip install virtualenv

# Install Z3
RUN wget --no-verbose https://raw.githubusercontent.com/batfish/batfish/master/tools/install_z3.sh \
&& bash install_z3.sh \
&& rm -r ~/.batfish_z3_cache \
&& rm install_z3.sh

##### Switch to non-root-user

RUN groupadd -g ${UID} ${USERNAME} \
&& useradd -m -r -u ${UID} -g ${USERNAME} ${USERNAME} \
&& mkdir -p /home/${USERNAME}/workdir \
&& chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}
USER ${USERNAME}
WORKDIR /home/${USERNAME}/workdir

# Create AWS-CLI virtualenv
RUN python3 -m virtualenv .venv-aws && . .venv-aws/bin/activate && python3 -m pip install awscli && deactivate

# Install bazel
RUN wget --no-verbose https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-installer-linux-x86_64.sh -O install_bazel.sh \
&& chmod +x install_bazel.sh \
&& ./install_bazel.sh --user \
&& rm -f install_bazel.sh

# Install maven
RUN wget --no-verbose https://www-us.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.zip \
&& unzip apache-maven-${MAVEN_VERSION}-bin.zip \
&& rm -f apache-maven-${MAVEN_VERSION}-bin.zip

# Setup JAVA_HOME
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/
# Set Java to obey cgroup limits
ENV _JAVA_OPTIONS -XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap -XX:MaxRAMFraction=1

# Add Bazel and Maven to PATH
ENV PATH $PATH:/home/${USERNAME}/workdir/apache-maven-${MAVEN_VERSION}/bin:/home/${USERNAME}/bin

# Fetch all the current Maven and bazel dependencies
RUN git clone --depth=1 --branch=master https://github.com/batfish/batfish \
&& cd batfish \
&& mvn -f projects verify -DskipTests=false \
&& mvn dependency:get -Dartifact=com.google.googlejavaformat:google-java-format:${GOOGLE_JAVA_FORMAT_VERSION}:jar:all-deps \
&& mvn dependency:get -Dartifact=org.jacoco:org.jacoco.cli:${JACOCO_VERSION}:jar:nodeps \
&& cd .. \
&& rm -rf batfish
