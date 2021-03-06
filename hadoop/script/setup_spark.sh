#!/bin/bash

# unofficial bash strict mode
set -euo pipefail
IFS=$'\n\t'

# run from any directory (no symlink allowed)
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd -P)
cd ${CURRENT_PATH}

##############################

FILE_PATH="/vagrant/file"
DATA_PATH="/vagrant/.data"
USER_NAME="hadoop"

SPARK_VERSION="2.2.1"
HADOOP_VERSION="2.7"
SPARK_NAME="spark-$SPARK_VERSION-bin-hadoop$HADOOP_VERSION"

##############################

function download_dist {
  local SPARK_MIRROR_DOWNLOAD="http://www-eu.apache.org/dist/spark/spark-$SPARK_VERSION/$SPARK_NAME.tgz"
  echo "[*] download dist"
  wget -q -P $DATA_PATH $SPARK_MIRROR_DOWNLOAD
}

function setup_dist {
  local SPARK_DIST_PATH="$DATA_PATH/$SPARK_NAME*"
  echo "[*] setup dist"

  if [ ! -e $SPARK_DIST_PATH ]; then
    download_dist
  fi

  tar -xf $SPARK_DIST_PATH -C /opt
  ln -s /opt/$SPARK_NAME /usr/local/spark
  chown -R $USER_NAME:$USER_NAME /opt/$SPARK_NAME
}

function setup_config {
  local DATA_PATH_GUEST="/vol/spark"
  local SPARK_BASE_PATH="/usr/local/spark"
  local CONFIG_PATH="$SPARK_BASE_PATH/conf"
  local HISTORY_PATH="/tmp/spark-events"
  local FILES=( "spark-env.sh" "log4j.properties" )

  echo "[*] create directories"
  mkdir -pv \
    $DATA_PATH_GUEST/log \
    $HISTORY_PATH
  
  for FILE in "${FILES[@]}"
  do
    echo "[*] update config: $FILE"
    # backup only if exists
    [ -e $CONFIG_PATH/$FILE ] && mv $CONFIG_PATH/$FILE $CONFIG_PATH/$FILE.orig
    cp $FILE_PATH/spark/config/$FILE $CONFIG_PATH/$FILE
  done

  echo "[*] update permissions"
  chown -R $USER_NAME:$USER_NAME \
    $SPARK_BASE_PATH/ \
    $HISTORY_PATH
  
  echo "[*] update env"
  cp $FILE_PATH/spark/profile-spark.sh /etc/profile.d/profile-spark.sh && \
    source /etc/profile.d/profile-spark.sh
  
  # TODO config spark on yarn as default
  # verify jars/archive path, ports between nodes and memory issues
  # https://www.linode.com/docs/databases/hadoop/install-configure-run-spark-on-top-of-hadoop-yarn-cluster/
  
  # spark-shell --master yarn --deploy-mode client
  # ERROR SparkContext: Error initializing SparkContext
  # org.apache.spark.SparkException: Yarn application has already ended! It might have been killed or unable to launch application master.
  
  # @see spark-defaults.conf
  
  # hadoop fs -ls -h -R /
  # hdfs dfs -mkdir -p /user/spark/{log,share/lib}
  # hadoop fs -put /usr/local/spark/jars/*.jar /user/spark/share/lib/

  # yarn-site.xml
  #<!-- required by Spark -->
  #<property>
  #    <name>yarn.resourcemanager.address</name>
  #    <value>resource-manager.local:8032</value>
  #</property>

  # zip -j /vol/spark/log/spark-archive.zip /usr/local/spark/jars/*.jar
  # hadoop fs -put /vol/spark/log/spark-archive.zip /user/spark/share/spark-archive.zip
}

function main {
  echo "[+] setup spark"
  setup_dist
  setup_config
  echo "[-] setup spark"
}

main
