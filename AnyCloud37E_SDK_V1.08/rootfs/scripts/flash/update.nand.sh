#!/bin/sh
# File:                update.sh
# Provides:
# Description:      update uImage&rootfs under /tmp|/mnt|...
# Author:            xc

CM_NORMAL=0
CM_BOLD=1
CM_UNDERLINED=4
CM_BLINK=5
CM_NEGATIVE=7

CB_BLACK=40
CB_RED=41
CB_GREEN=42
CB_YELLOW=43
CB_BLUE=44
CB_PURPLE=45
CB_CYAN=46
CB_WHITE=47

CF_BLACK=30
CF_RED=31
CF_GREEN=32
CF_YELLOW=33
CF_BLUE=34
CF_PURPLE=35
CF_CYAN=36
CF_WHITE=37

DIR_TMP="/tmp"
DIR_MNT="/mnt"
DIR_RESERVE="/tmp/reserve"
DIR_ROOT_TMP="/tmp/reserve/rootfstmp"
FILE_TAR_GZ="update.tar.gz"                                                     #压缩包文件名

PATH_SCRIPT=$(dirname $(readlink -f "$0"))                                      #脚本所在的路径
NAME_SCRIPT=$(basename $0)                                                      #脚本文件名

if [ "$PATH_SCRIPT" != "$DIR_TMP" ];then                                        #判断脚本所在位置不在/tmp下
    cp $PATH_SCRIPT/$NAME_SCRIPT $DIR_TMP                                       #将脚本拷贝到/tmp下
    echo "$DIR_TMP/$NAME_SCRIPT $*"
    $DIR_TMP/$NAME_SCRIPT $*                                                    #执行位于/tmp目录的
    exit 0 ;
fi

CMD_CAT=$DIR_ROOT_TMP/bin/cat
CMD_STAT=$DIR_ROOT_TMP/bin/stat
CMD_ECHO=$DIR_ROOT_TMP/bin/echo
CMD_GREP=$DIR_ROOT_TMP/bin/grep
CMD_DD=$DIR_ROOT_TMP/bin/dd
CMD_PS=$DIR_ROOT_TMP/bin/ps
CMD_SYNC=$DIR_ROOT_TMP/bin/sync
CMD_KILL=$DIR_ROOT_TMP/bin/kill
CMD_UMONT=$DIR_ROOT_TMP/bin/umount
CMD_REBOOT="$DIR_ROOT_TMP/sbin/reboot -f"

CMD_AWK=$DIR_TMP/awk
CMD_BC=$DIR_TMP/bc
CMD_EXPR=$DIR_TMP/expr

if [ -e /bin/mtd_debug ]; then
    CMD_MTD_DEBUG=$DIR_ROOT_TMP/bin/mtd_debug
elif [ -e /mnt/mtd_debug ]; then
    cp /mnt/mtd_debug $DIR_TMP
    CMD_MTD_DEBUG=$DIR_TMP/mtd_debug
elif [ -e /tmp/mtd_debug ]; then
    CMD_MTD_DEBUG=$DIR_TMP/mtd_debug
else
    echo "############ Can't find 'mtd_debug'. No update ############"
    return 0
fi

if [ -e /bin/nand_update ]; then
    CMD_NAND_UPDATE=$DIR_ROOT_TMP/bin/nand_update
elif [ -e /mnt/nand_update ]; then
    cp /mnt/nand_update $DIR_TMP
    CMD_NAND_UPDATE=$DIR_TMP/nand_update
elif [ -e /tmp/nand_update ]; then
    CMD_NAND_UPDATE=$DIR_TMP/nand_update
else
    echo "############ Can't find 'nand_update'. No update ############"
    return 0
fi

FILE_ENV="env.img"
FILE_DTB="cloudOS.dtb"
FILE_KERNEL="uImage"
FILE_ROOT="rootfs.yaffs2"
FILE_ETC="config.yaffs2"
FILE_USR="usr.yaffs2"

PARTITION_ENV="ENV"
PARTITION_BKENV="ENVBK"
PARTITION_DTB="DTB"
PARTITION_KERNEL="KERNEL"
PARTITION_ROOT="ROOTFS"
PARTITION_ETC="CONFIG"
PARTITION_USR="APP"

BUSYBOX_TAR="busybox.tar"

ENV_SIZE_FILE=4096                                                              #env文件的最大字节限制
ENV_SIZE_PARTITION=4                                                            #env分区的最大限制
USE_RESERVE_MEM=1                                                               #默认使用内存保留分区升级方式

DEV_RESERVED="/dev/reserved_ram0"                                               #保留内存设备

update_voice_tip()
{
    echo "play update voice tips"
    ccli misc --tips "/usr/share/anyka_update_device.mp3"
    sleep 3
}

check_files()
{
    echo "check update image"
    for target in ${FILE_ENV} ${FILE_DTB} ${FILE_KERNEL} ${FILE_ROOT} ${FILE_ETC} ${FILE_USR}
    do
        if [ -e ${DIR_UPDATE}/${target} ]; then
            echo "############ find a target ${target}, update in ${DIR_UPDATE} ############"
            return 1
        fi
    done
    return 0
}

check_busybox_tar()
{
    echo "check busybox tar"
    if [ -e ${DIR_UPDATE}/${BUSYBOX_TAR} ]; then
        echo "############ find ${BUSYBOX_TAR} for root ############"
        return 1
    fi
    return 0
}

check_reserve_dir( )
{
    DIR_RESERVE=`df | grep "$DEV_RESERVED" | grep -o -E "[^ ]+$"`
    if [ "$DIR_RESERVE" = "" ];then                                             #保留分区没有mount
        return 0
    else
        return 1                                                                #保留分区已经mount
    fi

}

check_file_md5( )                                                               #检查文件的md5是否正确,参数:文件名 md5文件
{
    if [ -e $2 ]; then
        FILE_MD5=`$CMD_MD5SUM $1 | $CMD_GREP -Eo "^[0-9a-f]+"`
        FILE_SIGN=`$CMD_CAT $2 | $CMD_GREP -Eo "^[0-9a-f]+"`
        if [ $FILE_MD5 == $FILE_SIGN ]; then
            $CMD_ECHO -e "\e["$CM_NORMAL";"$CF_GREEN";"$CB_BLACK"m""$1 $2 $FILE_MD5 MD5 CORRECT.""\e[0m"
            return 1
        else
            $CMD_ECHO -e "\e["$CM_NORMAL";"$CF_RED";"$CB_BLACK"m""$1 $FILE_MD5 $FILE_SIGN MD5 ERROR.""\e[0m"
            return 0
        fi
    else
        return 1
    fi
}

move_tmp_dir_files()                                                            #将tmp目录的升级文件移动到reserve目录
{
    for target in ${FILE_ENV} ${FILE_DTB} ${FILE_KERNEL} ${FILE_ROOT} ${FILE_ETC} ${FILE_USR} ${FILE_TAR_GZ}
    do
        if [ -e ${DIR_TMP}/${target} ]; then
            echo "MOVE ${target} => ${DIR_RESERVE}"
            mv ${DIR_TMP}/${target} ${DIR_RESERVE}/
            DIR_UPDATE=${DIR_RESERVE}                                           #重新设置升级目录
        fi
    done
    return 0
}

check_uncompress_update_file()                                                  #检查是否存在压缩文件
{
    echo "check ${FILE_TAR_GZ}"

    for dir in ${DIR_UPDATE}                                                    #${DIR_TMP} ${DIR_MNT} ${DIR_OPTION}
    do
        if [ -e ${dir}/${FILE_TAR_GZ} ]; then
            echo "tar -zvxf ${dir}/${FILE_TAR_GZ} -C ${DIR_RESERVE}"
            tar -zvxf ${dir}/${FILE_TAR_GZ} -C ${DIR_RESERVE}
            rm -f ${DIR_RESERVE}/${FILE_TAR_GZ}                                 #删除DIR_RESERVE目录的升级文件压缩包,如果存在的话
            DIR_UPDATE=${DIR_RESERVE}                                           #重新设置升级目录
            return 1                                                            #确定了升级目录
        fi
    done
    return 0
}

get_update_dir()
{
    for dir in ${DIR_RESERVE} ${DIR_MNT} ${DIR_OPTION}
    do
        for target in ${FILE_ENV} ${FILE_DTB} ${FILE_KERNEL} ${FILE_ROOT} ${FILE_ETC} ${FILE_USR} ${FILE_TAR_GZ}
        do
            #echo "check ${dir}/${target}"
            if [ -e ${dir}/${target} ]; then
                DIR_UPDATE="${dir}"
                return 1
            fi
        done
    done
    return 0
}

nand_update()
{
    if [ -e ${DIR_UPDATE}/${1} ]; then
        NUM_MTD=`$CMD_$CMD_CAT /proc/mtd | $CMD_GREP -E "\"${2}\"$" | $CMD_GREP -Eo "^mtd[0-9]+" | $CMD_GREP -Eo "[0-9]+"`
        if [ -z $NUM_MTD ]; then                                                #判断分区mtd id是否存在
            echo "CANT FIND MTD PARTITION ${2}"
            return 0
        else                                                                    #mtd id 存在

            check_file_md5 ${DIR_UPDATE}/$1 ${DIR_UPDATE}/$1.md5
            if [ "$?" = 0 ];then                                                #md5校验出错
                exit 0
            fi

            DEC_SIZE_FILE=`$CMD_STAT ${DIR_UPDATE}/$1 | $CMD_GREP -Eo "Size:\s+[0-9]+" | $CMD_GREP -Eo "[0-9]+"`
            HEX_SIZE_PARTITION=`$CMD_CAT /proc/mtd | $CMD_GREP -E "\"${2}\"$" | $CMD_GREP -Eo "^mtd[0-9]+:\s+[0-9a-fA-F]+" | $CMD_GREP -Eo "[0-9a-fA-F]+$" | $CMD_AWK '{print toupper($0)}'`
            DEC_SIZE_PARTITION=`$CMD_ECHO "obase=10;ibase=16;$HEX_SIZE_PARTITION"|$CMD_BC`          #获取分区大小

            HEX_SIZE_ERASE=`$CMD_CAT /proc/mtd | $CMD_GREP -E "\"${2}\"$" | $CMD_GREP -Eo "^mtd[0-9]+:\s+[0-9a-fA-F]+\s+[0-9a-fA-F]+" | $CMD_GREP -Eo "[0-9a-fA-F]+$" | $CMD_AWK '{print toupper($0)}'`
            DEC_SIZE_ERASE=`$CMD_ECHO "obase=10;ibase=16;$HEX_SIZE_ERASE"|$CMD_BC`        #获取擦除块大小
            NUM_BLOCK_PARTITION=`$CMD_EXPR $DEC_SIZE_PARTITION / $DEC_SIZE_ERASE`         #获取分区块数

            MOD_BLOCK_FILE=`$CMD_EXPR $DEC_SIZE_FILE % $DEC_SIZE_ERASE`                   #获取文件所需块数
            if [ $MOD_BLOCK_FILE -gt 0 ]; then
                NUM_BLOCK_FILE=`$CMD_EXPR $DEC_SIZE_FILE / $DEC_SIZE_ERASE + 1`           #不能整除+1
            else
                NUM_BLOCK_FILE=`$CMD_EXPR $DEC_SIZE_FILE / $DEC_SIZE_ERASE`
            fi
            NUM_BLOCK_ZERO=`$CMD_EXPR $NUM_BLOCK_PARTITION - $NUM_BLOCK_FILE`

            echo "DEC_SIZE_FILE=$DEC_SIZE_FILE"
            echo "HEX_SIZE_PARTITION=$HEX_SIZE_PARTITION"
            echo "DEC_SIZE_PARTITION=$DEC_SIZE_PARTITION"
            echo "HEX_SIZE_ERASE=$HEX_SIZE_ERASE"
            echo "DEC_SIZE_ERASE=$DEC_SIZE_ERASE"
            echo "NUM_BLOCK_PARTITION=$NUM_BLOCK_PARTITION"
            echo "MOD_BLOCK_FILE=$MOD_BLOCK_FILE"
            echo "NUM_BLOCK_FILE=$NUM_BLOCK_FILE"
            echo "NUM_BLOCK_ZERO=$NUM_BLOCK_ZERO"

            if [ $DEC_SIZE_FILE -gt $DEC_SIZE_PARTITION ]; then                 #文件大于分区
                $CMD_ECHO -e "\e["$CM_NORMAL";"$CF_RED";"$CB_BLACK"m"" $1 - $DEC_SIZE_FILE > $2 - $DEC_SIZE_PARTITION""\e[0m"
            else
                CMD_MTD_ERASE="$CMD_MTD_DEBUG erase /dev/mtd$NUM_MTD 0x0 0x$HEX_SIZE_PARTITION"
                $CMD_ECHO -e "\e["$CM_NORMAL";"$CF_BLUE";"$CB_BLACK"m""$CMD_MTD_ERASE""\e[0m"
                $CMD_MTD_ERASE
                $CMD_ECHO -e "\e["$CM_NORMAL";"$CF_BLUE";"$CB_BLACK"m""$CMD_SYNC""\e[0m"
                $CMD_SYNC

                CMD_NAND_UPDATE_EXEC="$CMD_NAND_UPDATE --file ${DIR_UPDATE}/$1 --mtd /dev/mtd$NUM_MTD $3"
                $CMD_ECHO -e "\e["$CM_NORMAL";"$CF_BLUE";"$CB_BLACK"m""$CMD_NAND_UPDATE_EXEC""\e[0m"
                $CMD_NAND_UPDATE_EXEC
                if [ "$?" = 0 ];then                                            #升级成功
                    $CMD_ECHO -e "\e["$CM_NORMAL";"$CF_GREEN";"$CB_BLACK"m""UPDATE ${1} ${2} SUCCESS.""\e[0m"
                else                                                            #失败
                    $CMD_ECHO -e "\e["$CM_NORMAL";"$CF_RED";"$CB_BLACK"m""UPDATE ${1} ${2} FAILURE.""\e[0m"
                    exit -1 ;
                fi

                $CMD_ECHO -e "\e["$CM_NORMAL";"$CF_BLUE";"$CB_BLACK"m""$CMD_SYNC""\e[0m"
                $CMD_SYNC
                let MTD_UPDATE=1
            fi
        fi
    fi
}

kill_proc()
{
    ps
    PID=`ps  | grep -E $1 | grep -v "grep" | awk '{ print $1}'`
    for i in $PID
    do
        echo -e "\e["$CM_NORMAL";"$CF_BLUE";"$CB_BLACK"m""Kill -9 $i""\e[0m"
        kill -9 $i
    done
}
                                                                                #
                                                                                # 升级脚本入口
                                                                                #
while getopts ":d:" opt
do
    case $opt in
    d)
        DIR_OPTION=$OPTARG
        ;;
    ?)
        echo "$0"
        echo "Option: -d [directory] 'Specify the updrade directory.(指定升级目录.)'"
        echo "For example:"
        echo "$0"
        echo "$0 -d /mnt/nfs/update"
        exit 1;;
    esac
done
echo 3 >/proc/sys/vm/drop_caches                                                #清除cache
#echo 8 > /proc/sys/kernel/printk                                               #打开内核调试选项

mount_reserve_dir.sh                                                            #nand升级暂时默认启动保留分区
check_reserve_dir                                                               #检查是否存在保留分区
if [ "$?" = 1 ];then                                                            #存在保留分区
    move_tmp_dir_files                                                          #将tmp目录的文件移动到reserve目录,如果存在的话
else                                                                            #不存在保留分区
    USE_RESERVE_MEM=0                                                           #将使用保留分区标志升级置为0
    DIR_RESERVE=${DIR_TMP}                                                      #如果没有保留分区则将DIR_RESERVE置为DIR_TMP
fi

if [ "$DIR_UPDATE" = "" ];then
    get_update_dir                                                              #定位升级文件的目录位置
    if [ "$?" = 0 ];then                                                        #未有升级文件退出
        echo "############ NO UPDATE FILES #############"
        exit 0
    fi
fi

check_uncompress_update_file                                                    #判断是否有压缩文件类型升级包,如果是则解压文件
check_files
if [ "$?" = 0 ];then                                                            #没有找到升级文件
    echo -e "\e["$CM_NORMAL";"$CF_RED";"$CB_BLACK"m"" NO UPDATE FILES. ""\e[0m"
    exit 0
fi

killall -9 syslogd
killall -9 klogd
killall -9 tcpsvd
killall -9 udhcpc
killall -9 ftpd
kill_proc "/usr"                                                                #关闭所有ps里面带 "/usr"关键字的进程kill掉

echo "mkdir -p $DIR_ROOT_TMP"
mkdir -p $DIR_ROOT_TMP
cp -Rd /bin /lib /sbin $DIR_ROOT_TMP
rm -rf $DIR_ROOT_TMP/lib/modules

check_busybox_tar
if [ "$?" = 0 ];then                                                            #没有busybox tar包,则使用root分区创建临时根目录分区
                                                                                #将usr分区的命令拷贝出来使用
    if [ -L /usr/bin/bc ]; then
        ln -svf $DIR_ROOT_TMP/bin/busybox $DIR_TMP/bc
    else
        cp /usr/bin/bc $DIR_TMP
    fi
    if [ -L /usr/bin/awk ]; then
        ln -svf $DIR_ROOT_TMP/bin/busybox $DIR_TMP/awk
    else
        cp /usr/bin/awk $DIR_TMP
    fi
    if [ -L /usr/bin/expr ]; then
        ln -svf $DIR_ROOT_TMP/bin/busybox $DIR_TMP/expr
    else
        cp /usr/bin/expr $DIR_TMP
    fi
    if [ -L /usr/bin/md5sum ]; then
        ln -svf $DIR_ROOT_TMP/bin/busybox $DIR_TMP/md5sum
    else
        cp /usr/bin/md5sum $DIR_TMP
    fi
    CMD_AWK=$DIR_TMP/awk
    CMD_BC=$DIR_TMP/bc
    CMD_EXPR=$DIR_TMP/expr
    CMD_MD5SUM=$DIR_TMP/md5sum
else
    tar -vxf ${DIR_UPDATE}/${BUSYBOX_TAR} -C $DIR_ROOT_TMP                      #解压busybox作为根目录
    CMD_AWK=$DIR_ROOT_TMP/usr/bin/awk
    CMD_BC=$DIR_ROOT_TMP/usr/bin/bc
    CMD_EXPR=$DIR_ROOT_TMP/usr/bin/expr
    CMD_MD5SUM=$DIR_ROOT_TMP/usr/bin/md5sum
fi

export LD_LIBRARY_PATH="$DIR_ROOT_TMP/lib"
export PATH="$DIR_ROOT_TMP/bin:$DIR_ROOT_TMP/sbin:$DIR_ROOT_TMP/usr/bin:$DIR_ROOT_TMP/usr/sbin:$DIR_TMP"
export
$CMD_ECHO "############ START UPDATE. #############"
$CMD_ECHO -e "\e["$CM_NORMAL";"$CF_BLUE";"$CB_BLACK"m""$CMD_UMONT /usr""\e[0m"
$CMD_UMONT /usr
$CMD_ECHO -e "\e["$CM_NORMAL";"$CF_BLUE";"$CB_BLACK"m""$CMD_UMONT /etc/config""\e[0m"
$CMD_UMONT /etc/config

MTD_UPDATE=0
nand_update $FILE_ENV    $PARTITION_ENV    --no-oob
nand_update $FILE_ENV    $PARTITION_BKENV  --no-oob
nand_update $FILE_DTB    $PARTITION_DTB    --no-oob
nand_update $FILE_KERNEL $PARTITION_KERNEL --no-oob
nand_update $FILE_ETC    $PARTITION_ETC
nand_update $FILE_USR    $PARTITION_USR
nand_update $FILE_ROOT   $PARTITION_ROOT

if [ "$MTD_UPDATE" = 1 ];then
    $CMD_ECHO "############ update success, reboot now #############"
    $DIR_ROOT_TMP/bin/sleep 1
    $CMD_ECHO -e "\e["$CM_NORMAL";"$CF_BLUE";"$CB_BLACK"m""$CMD_REBOOT""\e[0m"
    $CMD_REBOOT
fi
