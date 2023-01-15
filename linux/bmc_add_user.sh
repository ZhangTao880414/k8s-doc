#!/bin/bash
VERSION=0.0.1
MODIFY_DATE=20170824

#判断当前bmc是否是活的
function judgeActive()
{
    res=`ipmitool -I lanplus -H $IP_ADDR -U $USER_NAME -P $PASSWD mc info`
    if [ $? -ne 0 ]
    then
        echo "ip:$IP_ADDR not available"
        return 1
    fi
    echo "ip:$IP_ADDR is available"
    return 0
}

#获取user1用户的userid
function judgeUserID()
{
    USER_ID=`ipmitool -H $IP_ADDR -U $USER_NAME -P $PASSWD -I lanplus user list | grep " $USER_NAME " | awk '{print $1}'`
    if [ $? -ne 0 ]
    then
        return 1
    fi
    return 0
}

#判断user2是否是活的
function checkNewUser()
{
    res=`ipmitool -I lanplus -H $IP_ADDR -U $USER_NAME2 -P $PASSWD2 mc info`
    if [ $? -ne 0 ]
    then
        echo "ip:$IP_ADDR $USER_NAME2 $PASSWD2 not available"
        return 1
    fi
    echo "ip:$IP_ADDR $USER_NAME2 $PASSWD2 is available"
    return 0
}

#输出帮助信息
function printHelp()
{
    echo "Usage:./bmc_adduser_id5_bmc_v2_170825.sh -i ipFile
      ipFile is bmc machine info file include ip username and password

      all info output file dump.csv"
}


#给id5增加用户
function changeuser()
{
    CHANNEL1=1
    CHANNEL8=8
    BMCID=5
    
    #设置id5用户名
    ipmitool -I lanplus -H $IP_ADDR -U $USER_NAME -P $PASSWD user set name $BMCID $USER_NAME2
    if [ $? -ne 0 ]
    then
        echo "ip:$IP_ADDR $USER_NAME $PASSWD user set name not available"
        return 1
    fi
    
    #设置id5密码
    ipmitool -I lanplus -H $IP_ADDR -U $USER_NAME -P $PASSWD user set password $BMCID $PASSWD2
    if [ $? -ne 0 ]
    then
        echo "ip:$IP_ADDR $USER_NAME $PASSWD user set password not available"
        return 1
    fi
    
    #设置id5 channel1权限为administrator
    ipmitool -I lanplus -H $IP_ADDR -U $USER_NAME -P $PASSWD user priv $BMCID 4 $CHANNEL1
    if [ $? -ne 0 ]
    then
        echo "ip:$IP_ADDR $USER_NAME $PASSWD user priv $CHANNEL1 not available"
        return 1
    fi
    
    #设置id5 channel8权限为administrator
    ipmitool -I lanplus -H $IP_ADDR -U $USER_NAME -P $PASSWD user priv $BMCID 4 $CHANNEL8
    if [ $? -ne 0 ]
    then
        echo "ip:$IP_ADDR $USER_NAME $PASSWD user priv $CHANNEL8 not available"
        return 1
    fi
    
    #设置id5 channel1打开callin=on ipmi=true link=on privilege=4权限
    ipmitool -I lanplus -H $IP_ADDR -U $USER_NAME -P $PASSWD channel setaccess $CHANNEL1 $BMCID callin=on ipmi=true link=on privilege=4
    if [ $? -ne 0 ]
    then
        echo "ip:$IP_ADDR $USER_NAME $PASSWD channel setaccess $CHANNEL1 not available"
        return 1
    fi
    
    #设置id5 channel8打开callin=on ipmi=true link=on privilege=4权限
    ipmitool -I lanplus -H $IP_ADDR -U $USER_NAME -P $PASSWD channel setaccess $CHANNEL8 $BMCID callin=on ipmi=true link=on privilege=4
    if [ $? -ne 0 ]
    then
        echo "ip:$IP_ADDR $USER_NAME $PASSWD channel setaccess $CHANNEL8 not available"
        return 1
    fi
    
    #设置channel1的sol
    ipmitool -I lanplus -H $IP_ADDR -U $USER_NAME -P $PASSWD sol payload enable $CHANNEL1 $BMCID
    if [ $? -ne 0 ]
    then
        echo "ip:$IP_ADDR $USER_NAME $PASSWD sol payload enable $CHANNEL1 not available"
        return 1
    fi
    
    #user2使能
    ipmitool -I lanplus -H $IP_ADDR -U $USER_NAME -P $PASSWD user enable $BMCID
    if [ $? -ne 0 ]
    then
        echo "ip:$IP_ADDR $USER_NAME $PASSWD user enable not available"
        return 1
    fi
    
    return 0
}

case $1 in
            -h|--help)
            printHelp
            exit 0
                ;;
    esac

#获取shell脚本参数
while getopts ":i:" opt
do
    case $opt in
        i)
            IP_FILE=$OPTARG
            echo "ip file is "$IP_FILE
            ;;
        *) 
            echo "argument error"
            exit 1;;
    esac
done

#判断参数是否合法
if [ ${#IP_FILE} -eq 0 ]
then
    echo "please assign ip file. detail info check -h"
    exit 0
fi

echo "IP,check_original_user,original_userID,change_user,check_new_user">dump.csv

declare -i i=0

#逐行读取文件
for LINE in `cat $IP_FILE`;
do
{

    let i++
    
    if [ $i -eq 1 ]
    then
        continue
    fi

    #判断文件行的大小，若长度小于10则认为非法
    if [ ${#LINE} -lt 10 ]
    then
        continue;
    fi
    
    #声明变量并赋值
    IP_ADDR=`echo $LINE | awk -F, '{print $1}'`
    USER_NAME=`echo $LINE | awk -F, '{print $2}'`
    PASSWD=`echo $LINE  | awk -F, '{print $3}'`
    
    USER_NAME2=`echo $LINE | awk -F, '{print $4}'`
    PASSWD2=`echo $LINE  | awk -F, '{print $5}' | sed 's/\r//g'`
    
    #判断bmc是否是活的
    judgeActive
    if [ $? -eq 1 ]
    then
        check_original_user="fail"
        echo "$IP_ADDR,$check_original_user,$original_userID,$change_user,$check_new_user">${IP_ADDR}.insdat
        continue
    else
        check_original_user="success"
    fi
    
    #判断userid
    judgeUserID
    if [ $? -eq 1 ]
    then
        original_userID="get error"
        echo "$IP_ADDR,$check_original_user,$original_userID,$change_user,$check_new_user">${IP_ADDR}.insdat
        continue
    fi
    
    original_userID="is $USER_ID"
    
    #添加用户
    changeuser
    if [ $? -eq 1 ]
    then
        change_user="fail"
        echo "$IP_ADDR,$check_original_user,$original_userID,$change_user,$check_new_user">${IP_ADDR}.insdat
        continue
    else
        change_user="success"
    fi
    
    #检查新添加的用户
    checkNewUser
    if [ $? -eq 1 ]
    then
        check_new_user="fail"
        echo "$IP_ADDR,$check_original_user,$original_userID,$change_user,$check_new_user">${IP_ADDR}.insdat
        continue
    else
        check_new_user="sucess"
    fi
    
    #输出日志到日志文件
    echo "$IP_ADDR,$check_original_user,$original_userID,$change_user,$check_new_user">${IP_ADDR}.insdat

    echo "$IP_ADDR dump info over"
}
done

wait

#汇集日志信息
allfile=`ls *.insdat`
for file in $allfile
do
    cat $file >> dump.csv
done

#删除单个的日志文件
rm -r *.insdat

echo "all dump info over"