set -x -e

if [[ ${TRAVIS_OS_NAME} == 'linux' ]]; then
   sudo apt-get update
   sudo apt-get install python3.5 python3-pip
else
   echo "Unsupported TRAVIS_OS_NAME: $TRAVIS_OS_NAME"
   exit 1 # CI not supported in this case
fi
