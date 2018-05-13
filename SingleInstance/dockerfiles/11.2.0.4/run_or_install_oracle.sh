#!/bin/bash
#以下脚本将进行检测信号，并进行优雅退出。
#进程号1的进程可以检测到信号，外部命令将导致进程1阻塞而妨碍检测信号。

function _int(){
	echo "停止容器与数据库中..."
	sqlplus / as sysdba <<EOF
		shutdown immediate;
		exit;
EOF
	lsnrctl stop
}

function _term(){
	echo "停止容器与数据库中..."
	sqlplus / as sysdba <<EOF
		shutdown immediate;
		exit;
EOF
	lsnrctl stop
}

function _kill(){
	echo "强制关闭容器与数据库中..."
	sqlplus / as sysdba <<EOF
		shutdown abort;
		exit;
EOF
	lsnrctl stop
}


#原始官方脚本中做了一个链接，暂时省略。
#内存不少于1.5G
######################################

if [ `cat /sys/fs/cgroup/memory/memory.limit_in_bytes` -lt 1610612736 ]; then
	echo "容器 Memory < 1.5G，退出"
	exit 1;
fi;

trap _int SIGINT

trap _term SIGTERM

trap _kill SIGKILL

#原版检测oracle_sid是否符合规范，此处跳过

#数据据字符集，可以自行修改，此处用中文常见字符集
#将此处内存设置乘1536，本人实验环境内存有限

export ORACLE_CHARACTERSET=ZHS16GBK
export ORACLE_SID=ORCL
#export ORACLE_TOTALMEMORY=1536


#检测库是否已经存在或者创建
if [ -d $ORACLE_BASE/oradata/$ORACLE_SID ];then
	lsnrctl start
	sqlplus / as sysdba <<EOF
		startup;
		exit;
EOF
else
	#cp $ORACLE_BASE/$INSTALL_DBCA_RSP $ORACLE_BASE/dbca.rsp
	sed -i -e "s|###ORACLE_SID###|$ORACLE_SID|g" $ORACLE_BASE/dbca.rsp
	sed -i -e "s|###ORACLE_CHARACTERSET###|$ORACLE_CHARACTERSET|g" $ORACLE_BASE/dbca.rsp
	#sed -i -e "s|###ORACLE_TOTALMEMORY###|$ORACLE_TOTALMEMORY|g" $ORACLE_BASE/dbca.rsp

	dbca -silent -responseFile $ORACLE_BASE/dbca.rsp
fi;



status=`sqlplus -s / as sysdba <<EOF
	set heading off;
	set pagesize 0;
	SELECT OPEN_MODE FROM v\\$database;
	exit;
EOF`

ret=$?
if [ $ret -eq 0 ] && [ "$status" = "READ WRITE" ];then
	echo "数据库已打开"
else
	echo "数据库存在异常"
fi;
#最后循环防止退出，直接拷贝官方
tail -f $ORACLE_BASE/diag/rdbms/*/*/trace/alert*.log &
childPID=$!
wait $childPID