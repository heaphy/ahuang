#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# SET FTP server you want back up to
FTP_HOST="ahuang.org"
FTP_USER=""
FTP_PASS=""

# Databases information
DB_USER="root"
DB_PASS="root"
DB_PORT=3306

# Auto clear the backup tar file
AUTO_CLEAN="no"

# Set Server-Configure file to back up
CONF_NGINX=/usr/local/nginx/conf
CONF_APACHE=/usr/local/apache/conf

# Set WWWROOT to back up
WWWROOT=/home/wwwroot

# Set Other File to back up
FILE=


########## No Change ############
# Begin
TMP_FILE="dbs_tmp"
RE_FILE="easyup-0.2.sh"
function alert(){
    echo -e "\e[0;32m$1\e[0m"
}
function warn(){
    echo -e "\e[0;33mWarn:  $1\e[0m"
}
function copyright(){
    echo -e "\e[0;32mEasy back Success. Visit\e[0m \e[0;33mhttp://ahuang.org/easyback\e[0m \e[0;32mfor more information.\e[0m"
}
function cmdExist()
{
    IFS=":"
    for directory in $PATH
    do
        if [ -x $directory/$1 ]
        then
            return 0
        fi
    done
    return 1
}

# Processing
clear
alert "Processing ..."
BAK_NAME=backup_`date +%Y.%m.%d_%H%M`
mkdir $BAK_NAME
cd $BAK_NAME

##
if [ -n "$CONF_NGINX" ]; then
    if [ -d "$CONF_NGINX" ]; then
        alert "Copy nginx-conf files ..."
        mkdir -p conf/nginx
        cp -rf $CONF_NGINX/* conf/nginx
    else
        warn "$CONF_NGINX not exist. Skip it."
    fi
fi
if [ -n "$CONF_APACHE" ]; then
    if [ -d "$CONF_APACHE" ]; then
        alert "Copy apache-conf files ..."
        mkdir -p conf/apache
        cp -rf $CONF_APACHE/* conf/apache
    else
        warn "$CONF_APACHE not exist. Skip it."
    fi
fi

##
if [ -n "$WWWROOT" ]; then
    if [ -d "$WWWROOT" ]; then
        alert "Copy wwwroot ..."
        mkdir wwwroot
        cp -rf $WWWROOT/* wwwroot
    else
        warn "$WWWROOT not exist. Skip it."
    fi
fi
if [ -n "$FILE" ]; then
    if [ -d "$FILE" ]; then
        alert "Copy other files ..."
        mkdir file
        cp -rf $FILE/* file
    else
        war "$FILE not exist. Skip it."
    fi
fi

##
alert "Buid $RE_FILE ..."
cat >$RE_FILE<<EOF
#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# database information
DB_USER="$DB_USER"
DB_PASS="$DB_PASS"
DB_PORT=$DB_PORT


#####
clear
echo "Copy the conf-files..."
if [ -d "conf/nginx" ]; then
    mkdir -p $CONF_NGINX
    cp -rf conf/nginx/* $CONF_NGINX
fi
if [ -d "conf/apache" ]; then
    mkdir -p $CONF_APACHE
    cp -rf conf/apache/* $CONF_APACHE
fi

##
if [ -d "dbs" ] && [ -n "\$DB_USER" ] && [ -n "\$DB_PASS" ] && [ -n "\$DB_PORT" ]; then
    if ! which mysql; then
        echo "Error: You have never install mysql!"
        exit
    else
        echo "Import the databases..."
        DB_FILES=\`ls dbs/*.sql\`
        for DB_FILE in \$DB_FILES
        do
            mysql -u\$DB_USER -p\$DB_PASS -P\$DB_PORT < \$DB_FILE
        done
    fi
fi

##
if [ -d "wwwroot" ]; then
    echo "Copy the wwwroot..."
    cp -rf wwwroot/* $WWWROOT
    chown -R www:www $WWWROOT
fi
if [ -d "file" ]; then
    echo "Copy the other files..."
    cp -rf file/* $FILE
fi
echo " "
echo -e "Easy up Success, Visit \e[0;32mhttp://ahuang.org/easyback\e[0m for more information."
echo " "
echo " "
EOF
chmod +x $RE_FILE

##
if [ -n "$DB_USER" ] && [ -n "$DB_PASS" ] && [ -n "$DB_PORT" ]; then
    alert " "
    cmdExist mysql
    if [ $? -ne 0 ]; then
        warn "No mysql installed. Skip it."
    else
        alert "Export databases ..."
        mkdir dbs
        mysql -u$DB_USER -p$DB_PASS -P$DB_PORT -BN -e 'show databases;' | grep -v mysql | grep -v information_schema > $TMP_FILE
        while read DB
        do
            mysqldump -u$DB_USER -p$DB_PASS -P$DB_PORT \
                    --quick --add-drop-table --order-by-primary \
                    --complete-insert --extended-insert=false --skip-comments \
                    --default-character-set=utf8 --add-locks \
                    --databases $DB > dbs/$DB.sql
            if [ -f "dbs/$DB.sql" ]; then
                alert "  name: $DB \tfile: dbs/$DB.sql \tsize: `du -sh dbs/$DB.sql| awk '{print $1}'`"
            fi
        done < $TMP_FILE
        rm $TMP_FILE
    fi
fi

##
cd ..
alert " "
alert "Compress backup files ..."
tar czf $BAK_NAME.tar $BAK_NAME
rm -rf $BAK_NAME
if [ -f "$BAK_NAME.tar" ]; then
    alert "  file: $BAK_NAME.tar"
    alert "  size: `du -sh $BAK_NAME.tar | awk '{print $1}' `"
fi

##
if [ -n "$FTP_HOST" ] && [ -n "$FTP_USER" ] && [ -n "$FTP_PASS" ]; then
	alert " "
    cmdExist ftp
    if [ $? -ne 0 ]; then
        warn "No Ftp client install! Skip it."
    else
        alert "Ftp file to server, waiting for a while ......"
# start ftp
ftp -n $FTP_HOST > ftp.log 2>&1 <<EOF
user $FTP_USER $FTP_PASS
binary
put $BAK_NAME.tar
bye
EOF
# end ftp
        if [ "$AUTO_CLEAN" = "yes" ]; then
            alert "auto clean files ..."
            rm -rf $BAK_NAME.tar
        fi
        cat ftp.log
    rm -f ftp.log
    fi
fi

alert " "
copyright
alert " "
