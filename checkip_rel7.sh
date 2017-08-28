#!/bin/sh

NIC=$1
IP=$2
PING_INTERVAL=$3

#  chequeo que el argumento se parezca a una IP

echo $IP | grep -E -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' > /dev/null 2>&1
if [ $? -ne 0 ]; then
   exit -1
fi

# Se chequea que el dev identificado en NIC este UP
/sbin/ip addr | /bin/grep -Eq ": ${NIC}:.*state UP" > /dev/null 2>&1
if [ $? -ne 0 ]; then
   exit -1   
fi

# Se verifica que la IP este configurada en NIC
/sbin/ip addr show ${NIC} | grep $IP > /dev/null 2>&1
if [ $? -ne 0 ]; then
   exit -1   
fi

# Se verifica que la IP este configurada y que responda
if [ "xx${PING_INTERVAL}" == "xx" ]; then
  PING_INTERVAL=1
fi
/bin/ping -c 3 ${IP} -i $PING_INTERVAL > /dev/null 2>&1
if [ $? -ne 0 ]; then
   exit -1
fi

# todo esta correcto
exit 0
