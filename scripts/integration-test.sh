#!/bin/bash
# Copyright 2016 VMware, Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -x

apt-get update && apt-get install -y jq
curl -sSL https://get.docker.com/ | sh

apt-get install -y gcc python-dev python-setuptools python-pip libffi-dev libssl-dev
pip install pyasn1 gsutil --upgrade

gsutil version -l

make integration-tests
rc="$?"

timestamp=$(date +%s)
outfile="vic_install_logs_$timestamp.tar"
logs=$(find . -type f \( -name "install-*.tar.gz" \) )
if [ -n "${logs}" ]; then
  for f in ${logs}; do
    if [ -s "$f" ]; then
      tar --append $f -f $outfile
    fi
  done
  if [ -s "$outfile" ]; then
    shasum -a 256 $outfile
  else
    echo "Zero sized install logs found, no output"
  fi
else
  echo "No install logs found"
fi


# GC credentials
set +x
keyfile="vic-ci-logs.key"
echo -en $GS_PRIVATE_KEY > $keyfile
chmod 400 vic-ci-logs.key
echo "[Credentials]" >> ~/.boto
echo "gs_service_key_file = vic-ci-logs.key" >> ~/.boto
echo "gs_service_client_id = $GS_CLIENT_EMAIL" >> ~/.boto
echo "[GSUtil]" >> ~/.boto
echo "content_language = en" >> ~/.boto
echo "default_project_id = $GS_PROJECT_ID" >> ~/.boto
set -x

if [ -f "$outfile" ]; then
  gsutil cp $outfile gs://vic-ci-logs
else
  echo "No log output file to upload"
fi

if [ -f "$keyfile" ]; then
  rm -f $keyfile
fi

exit $rc
