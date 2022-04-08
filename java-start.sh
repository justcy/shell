#!/bin/bash

path="$(cd "$(dirname $0)";pwd)"
JAVA_CMD=/usr/local/java/jdk1.8.0_201/bin/java
SERVER_PUBLIC=47.116.74.105
EUREKA_HOST=$SERVER_PUBLIC:8761
SERVER=172.19.248.72
APP_NAME=one-service
ports=("8666" "8667")
LOG_PATH=$path/logs
DELAY=40
checkpid(){
    pid=`ps -ef |grep $path/$APP_NAME-1.0.0-$1-SNAPSHOT.jar |grep -v grep |awk '{print $2}'`
}
stop_eureka(){
  echo "http://$EUREKA_HOST/eureka/apps/$APP_NAME/$SERVER:$APP_NAME:$1/status?value=DOWN"
  curl -X "PUT"  "http://$EUREKA_HOST/eureka/apps/$APP_NAME/$SERVER:$APP_NAME:$1/status?value=DOWN"
  sleep $DELAY
}
start_eureka(){
  echo "http://$EUREKA_HOST/eureka/apps/$APP_NAME/$SERVER:$APP_NAME:$1/status?value=UP"
  curl -X "DELETE"  "http://$EUREKA_HOST/eureka/apps/$APP_NAME/$SERVER:$APP_NAME:$1/status?value=UP"
}
start(){
  if [ $# != 1 ] ; then
      ports=($@)
      unset ports["$1"]
  fi
  for port in ${ports[*]}
  do
    checkpid $port
    if [ ! -n "$pid" ]; then
      echo "Starting $APP_NAME:$port"
      nohup $JAVA_CMD -Xmx1024m -Xms512m -XX:SurvivorRatio=8 -XX:+UseConcMarkSweepGC -Djava.security.egd=file:/dev/./urandom  -jar -Dfile.encoding=utf-8 $path/$APP_NAME-1.0.0-$port-SNAPSHOT.jar --server.port=$port  > $LOG_PATH/$APP_NAME-$port.log 2>1&
      echo "Started"
      # 到日志文件夹中寻找最新的一个日志文件
      LOG_FILE=`ls -t $LOG_PATH/$APP_NAME-$port.log | head -1`
      # 打印启动日志，如果发现日志中包含Tomcat started这个字符说明启动成功，结束打印进程
      tail -f $LOG_FILE|while read line
      do
          kw=`echo $line|grep "Tomcat started"|wc -l`
          if [ $kw -lt 1 ];then
              echo $line
          else
          tail_pid=`ps -ef |grep $LOG_FILE |grep -v grep |awk '{print $2}'`
          kill -9 $tail_pid
          fi
      done
      echo "Success stared"
    else
        echo "$APP_NAME:$PORT is runing PID: $pid"
    fi
    start_eureka $port
  done
}
stop(){
   if [ $# != 1 ] ; then
      ports=($@)
      unset ports["$1"]
   fi
   for port in ${ports[*]}
   do
    checkpid $port
    stop_eureka $port
    if [ ! -n "$pid" ]; then
     echo "$APP_NAME:$port not runing"
    else
      echo "$APP_NAME:$port stop..."
      kill $pid
      sleep 2s
      kill -9 $pid
    fi
  done

}
restart(){
  if [ $# != 1 ] ; then
    echo $@
    ports=($@)
    unset ports["$1"]
  fi
  for port in ${ports[*]}
    do
      sh $0 stop $port
      sh $0 start $port
  done
}
reload(){
  if [ $# != 1 ] ; then
    echo $@
    ports=($@)
    unset ports["$1"]
  fi
  for port in ${ports[*]}
    do
      sh $0 stop $port
      cp $path/$APP_NAME-1.0.0-SNAPSHOT.jar $path/$APP_NAME-1.0.0-$port-SNAPSHOT.jar
      sh $0 start $port
  done
}
status(){
   if [ $# != 1 ] ; then
      ports=($@)
      unset ports["$1"]
   fi
   for port in ${ports[*]}
     do
       checkpid $port
       if [ ! -n "$pid" ]; then
         echo "$APP_NAME:$port not runing"
       else
         echo "$APP_NAME:$port runing PID: $pid"
       fi
     done
}
case "$1" in
    start) start $@;;
    stop)  stop $@;;
    restart)  restart $@;;
    reload)  reload $@;;
    status)  status $@;;
        *)  echo "require start|stop|restart|reload|status"  ;;
esac
