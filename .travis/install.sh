set -x -e

if [[ $TRAVIS_OS_NAME == 'linux' ]]; then
   ### install python packages
   echo -e "\n   ............. Installing pip"
   sudo -H apt-get -y install python-pip || exit 1
   pip --version || exit 1
elif [[ $TRAVIS_OS_NAME == 'osx' ]]; then
   echo $PATH
   export PATH=/usr/local/share/python:$PATH
   java -version || exit 1
   javac -version || exit 1
   which pip || easy_install pip || exit 1
   pip --version || exit 1
else
   echo "Unsupported TRAVIS_OS_NAME: $TRAVIS_OS_NAME"
   exit 1 # CI not supported in this case
fi
