#这个文件用不着，是我模仿的来源
######################################################
FROM oraclelinux:7-slim

# Maintainer
# ----------
MAINTAINER Gerald Venzl <gerald.venzl@oracle.com>

# Environment variables required for this build (do NOT change)
# -------------------------------------------------------------
ENV ORACLE_BASE=/opt/oracle \
    ORACLE_HOME=/opt/oracle/product/12.2.0.1/dbhome_1 \
    INSTALL_FILE_1="linuxx64_12201_database.zip" \
    INSTALL_RSP="db_inst.rsp" \
    CONFIG_RSP="dbca.rsp.tmpl" \
    PWD_FILE="setPassword.sh" \
    RUN_FILE="runOracle.sh" \
    START_FILE="startDB.sh" \
    CREATE_DB_FILE="createDB.sh" \
    SETUP_LINUX_FILE="setupLinuxEnv.sh" \
    CHECK_SPACE_FILE="checkSpace.sh" \
    CHECK_DB_FILE="checkDBStatus.sh" \
    USER_SCRIPTS_FILE="runUserScripts.sh" \
    INSTALL_DB_BINARIES_FILE="installDBBinaries.sh"

# Use second ENV so that variable get substituted
ENV INSTALL_DIR=$ORACLE_BASE/install \
    PATH=$ORACLE_HOME/bin:$ORACLE_HOME/OPatch/:/usr/sbin:$PATH \
    LD_LIBRARY_PATH=$ORACLE_HOME/lib:/usr/lib \
CLASSPATH=$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib

# Copy binaries
# -------------
COPY $INSTALL_FILE_1 $INSTALL_RSP $SETUP_LINUX_FILE $CHECK_SPACE_FILE $INSTALL_DB_BINARIES_FILE $INSTALL_DIR/
COPY $RUN_FILE $START_FILE $CREATE_DB_FILE $CONFIG_RSP $PWD_FILE $CHECK_DB_FILE $USER_SCRIPTS_FILE $ORACLE_BASE/

RUN chmod ug+x $INSTALL_DIR/*.sh && \
sync && \

#------------------------------------------------------check space---------------------------------------------------------
REQUIRED_SPACE_GB=12
AVAILABLE_SPACE_GB=`df -PB 1G / | tail -n 1 | awk '{ print $4 }'`

if [ $AVAILABLE_SPACE_GB -lt $REQUIRED_SPACE_GB ]; then
  script_name=`basename "$0"`
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "$script_name: ERROR - There is not enough space available in the docker container."
  echo "$script_name: The container needs at least $REQUIRED_SPACE_GB GB, but only $AVAILABLE_SPACE_GB GB are available."
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  exit 1;
fi;
#---------------------------------------------------------------------------------------------------------------------------

#---------------------------------------------------set up linux env--------------------------------------------------------
mkdir -p $ORACLE_BASE/scripts/setup && \
mkdir $ORACLE_BASE/scripts/startup && \
ln -s $ORACLE_BASE/scripts /docker-entrypoint-initdb.d && \
mkdir $ORACLE_BASE/oradata && \
chmod ug+x $ORACLE_BASE/*.sh && \
yum -y install oracle-rdbms-server-12cR1-preinstall unzip tar openssl && \
rm -rf /var/cache/yum && \
echo oracle:oracle | chpasswd && \
chown -R oracle:dba $ORACLE_BASE
#---------------------------------------------------------------------------------------------------------------------------

USER oracle
RUN
#---------------------------------------------------install db binaries------------------------------------------------------
if [ "$ORACLE_BASE" == "" ]; then
   echo "ERROR: ORACLE_BASE has not been set!"
   echo "You have to have the ORACLE_BASE environment variable set to a valid value!"
   exit 1;
fi;

# Check whether ORACLE_HOME is set
if [ "$ORACLE_HOME" == "" ]; then
   echo "ERROR: ORACLE_HOME has not been set!"
   echo "You have to have the ORACLE_HOME environment variable set to a valid value!"
   exit 1;
fi;

#通过先前设置好的环境变量更换rsp文件中的变量，说明rsp文件几乎是相同的
# Replace place holders
sed -i -e "s|###ORACLE_EDITION###|$EDITION|g" $INSTALL_DIR/$INSTALL_RSP && \
sed -i -e "s|###ORACLE_BASE###|$ORACLE_BASE|g" $INSTALL_DIR/$INSTALL_RSP && \
sed -i -e "s|###ORACLE_HOME###|$ORACLE_HOME|g" $INSTALL_DIR/$INSTALL_RSP

#正式开始安装
# Install Oracle binaries
cd $INSTALL_DIR       && \
unzip $INSTALL_FILE_1 && \
rm $INSTALL_FILE_1    && \
unzip $INSTALL_FILE_2 && \
rm $INSTALL_FILE_2    && \
$INSTALL_DIR/database/runInstaller -silent -force -waitforcompletion -responsefile $INSTALL_DIR/$INSTALL_RSP -ignoresysprereqs -ignoreprereq && \
cd $HOME

#删除用不着的组件，减少空间，即可选项
# Remove not needed components
rm -rf $ORACLE_HOME/apex && \
rm -rf $ORACLE_HOME/jdbc && \
# ZDLRA installer files
rm -rf $ORACLE_HOME/lib/ra*.zip && \
rm -rf $ORACLE_HOME/ords && \
rm -rf $ORACLE_HOME/sqldeveloper && \
rm -rf $ORACLE_HOME/ucp && \
# OUI backup
rm -rf $ORACLE_HOME/inventory/backup/* && \
# Network tools help
rm -rf $ORACLE_HOME/network/tools/help/mgr/help_* && \
# Temp location
rm -rf /tmp/* && \
# Database files directory
rm -rf $INSTALL_DIR/database


# Link password reset file to home directory
ln -s $ORACLE_BASE/$PWD_FILE $HOME/
#----------------------------------------------------------------------------------------------------------------------

USER root
RUN $ORACLE_BASE/oraInventory/orainstRoot.sh && \
    $ORACLE_HOME/root.sh && \
rm -rf $INSTALL_DIR

USER oracle
WORKDIR /home/oracle

VOLUME ["$ORACLE_BASE/oradata"]
EXPOSE 1521 5500
HEALTHCHECK --interval=1m --start-period=5m \
    CMD
#----------------------------------------------------------------------------------------

#---------------------------------------------------------------------------------------

CMD
#-------------------------------run db or (create db and run it)------------------------------------
#首先把日志输出到宿主机，但也可以不做，这里不显示了
#检查了容器的内存，这里不显示了
#export ORACLE_CHARACTERSET=${ORACLE_CHARACTERSET:-AL32UTF8} 密码 SID 写入dbca.rsp
cp $ORACLE_BASE/$CONFIG_RSP $ORACLE_BASE/dbca.rsp
sed -i -e "s|###ORACLE_SID###|$ORACLE_SID|g" $ORACLE_BASE/dbca.rsp
sed -i -e "s|###ORACLE_PDB###|$ORACLE_PDB|g" $ORACLE_BASE/dbca.rsp
sed -i -e "s|###ORACLE_PWD###|$ORACLE_PWD|g" $ORACLE_BASE/dbca.rsp
sed -i -e "s|###ORACLE_CHARACTERSET###|$ORACLE_CHARACTERSET|g" $ORACLE_BASE/dbca.rsp

#dbca内存可以自动控制，将TOTALMEMORY注释掉即可
dbca -silent -responseFile $ORACLE_BASE/dbca.rsp 

