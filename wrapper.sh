#!/bin/bash
# Copied from docker docs https://docs.docker.com/config/containers/multi-service_container/

# Start Batfish
java -XX:-UseCompressedOops -XX:+UseContainerSupport -XX:MaxRAMPercentage=80 \
  -Dlog4j.configurationFile=log4j2.yaml \
  -cp allinone-bundle.jar org.batfish.allinone.Main \
  -runclient false \
  -loglevel warn \
  -coordinatorargs "-templatedirs questions -containerslocation /data/containers"&
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start batfish: $status"
  exit $status
fi

# Start Jupyter notebook
cd notebooks
jupyter notebook --allow-root --ip=0.0.0.0 --port=8888 &
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start Jupyter notebook: $status"
  exit $status
fi

# Check that Batfish and Jupyter are still running every minute
while sleep 60; do
  ps aux |grep java |grep -q -v grep
  PROCESS_1_STATUS=$?
  ps aux |grep jupyter |grep -q -v grep
  PROCESS_2_STATUS=$?
  # If either stops, go ahead and shutdown
  if [ $PROCESS_1_STATUS -ne 0 ]; then
    echo "Java has exited."
    exit 1
  fi
  if [ $PROCESS_2_STATUS -ne 0 ]; then
    echo "Jupyter has exited."
    exit 1
  fi
done
