#!/bin/bash
#1.检查容器空间是否足够,这步骤我省略了，一般不小于15G

#2.设置容器内环境且安装前置包
mkdir $ORACLE_BASE/oradata
yum -y install oracle-rdbms-server-11gR2-preinstall unzip tar openssl
rm -rf /var/cache/yum
echo oracle:oracle | chpasswd
chown -R oracle:dba $ORACLE_BASE

#解压安装并删除
su -p oracle <<EOF

cd $INSTALL_DIR && unzip $INSTALL_FILE_1 && rm $INSTALL_FILE_1 && unzip $INSTALL_FILE_2 && rm $INSTALL_FILE_2 && \
$INSTALL_DIR/database/runInstaller -silent -force -waitforcompletion -responsefile $INSTALL_DIR/$INSTALL_RSP -ignoresysprereqs -ignoreprereq && \
rm -rf $INSTALL_DIR/database

exit;
EOF

sh $ORACLE_BASE/oraInventory/orainstRoot.sh && \
sh $ORACLE_HOME/root.sh && \
rm -rf $INSTALL_DIR

