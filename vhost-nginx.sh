#!/bin/bash

## Variables section
action=$1
domain=$2

sitesAvailable="/etc/nginx/sites-available/"
sitesEnabled="/etc/nginx/sites-enabled/"
logPath="/var/log/nginx/"
hosts_file="/etc/hosts"
nginxStatus=$(systemctl is-active nginx);
php_version=$(php -v | tac | tail -n 1 | cut -d " " -f 2 | cut -c 1-3)

# Checking current user
if [[ "$(whoami)" != 'root' ]]; then
	echo $"You are not allowed to run $0 as non-root user. Use sudo first"
    exit 1;
fi

# Checking allowed actions
if [[ "$action" != 'create' ]] && [[ "$action" != 'delete' ]] && [[ "$action" != 'rename' ]] && [[ "$action" != 'change' ]]
	then
		echo "You need to prompt an action (create, delete, rename or change) - lower case only"
		exit 1;
fi

# Checking if Nginx is running
if [[ ! "$nginxStatus" == 'active'  ]]; then
    echo -e "\e[1;31m\nNginx is not running, start Nginx first using 'systemctl start nginx'.\n\e[0m"
    exit 0;
fi

# Getting user domain
while [[ "$domain" == "" ]]
do
	echo -e "Please enter your domain: "
	read domain
done

## Functions Section
create() {

    # check if domain already exists
    if [[ -f ${sitesAvailable}${domain}.conf ]]; then
        echo -e "\e[1;31m\nDomain ${domain} Already Exists.\n\e[0m"
        exit 0;
    fi

    # Getting project root directory
    while [[ "$hosting_directory" == "" ]]
    do
        read -p "Please enter your domain root directory: " hosting_directory
    done

    # create folder if it does not exist
    if [[ ! -d "$hosting_directory" ]]; then

        mkdir ${hosting_directory}

        chmod 777 ${hosting_directory}

        echo "Hello From {${domain}} Located at {${hosting_directory}}" > ${hosting_directory}/index.php

    fi

    # create configuration file's content
    if ! echo "
server {
    listen 80;
    server_name $domain www.$domain;
    root $hosting_directory;

    add_header X-Frame-Options \"SAMEORIGIN\";
    add_header X-XSS-Protection \"1; mode=block\";
    add_header X-Content-Type-Options \"nosniff\";

    index index.html index.htm index.php;

    charset utf-8;

    location @rewrite {
        rewrite ^/(.*)$ /index.php?_url=/\$1;
    }

    location / {
        try_files \$uri \$uri/ @rewrite;
    }

    access_log /var/log/nginx/$domain-access.log;
    error_log /var/log/nginx/$domain-error.log;

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php$php_version-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}" | tee -a "${sitesAvailable}${domain}.conf" > /dev/null
    then
        echo -e "There is an ERROR creating $domain file"
        exit;
    fi

    # adding this domain to the hosts file
    status=$(grep "\s\+$domain" "/etc/hosts")
    if  [[ ${status} == "" ]]; then
        ip="127.0.0.1 $domain"
        echo ${ip} | tee --append "/etc/hosts" > /dev/null 2>&1
    fi

    # Enable Domain
    ln -s ${sitesAvailable}${domain}".conf" ${sitesEnabled}${domain}".conf"

    # Restart Nginx
    systemctl reload nginx

    echo -e "\e[1;32m\nVirtual Host ${domain} Successfully Created.\n\e[0m"

}

delete() {

    # remove symlink exists in sites-enabled
    if [[ -f ${sitesEnabled}${domain}.conf ]]; then
        unlink "${sitesEnabled}${domain}.conf" > /dev/null 2>&1
    fi

    # remove domain if exists in sites-available
    if [[ -f ${sitesAvailable}${domain}.conf ]]; then
        rm "${sitesAvailable}${domain}.conf" > /dev/null 2>&1
    fi

    # remove localhost ip and domain from hosts file
    sed -e s/^127.0.0.1[^:]*${domain}//g -i "/etc/hosts" > /dev/null 2>&1

    # remove log files
    rm "${logPath}${domain}-error.log" > /dev/null 2>&1
    rm "${logPath}${domain}-access.log" > /dev/null 2>&1

    # delete hosting directory if it's provided
    if [[ ${hosting_directory} != "" && -d ${hosting_directory} ]]; then
        rm -rf ${hosting_directory}
    fi

    systemctl reload nginx

    echo -e "\e[1;32m\nVirtual Host ${domain} Successfully Deleted.\n\e[0m"

}

rename() {

    # Getting user domain rename to
    while [[ "$new_domain_name" == "" ]]
    do
        echo -e "\nRename your domain to : "
        read new_domain_name
    done

    # remove symlink exists in sites-enabled
    if [[ -f ${sitesEnabled}${domain}.conf ]]; then
        unlink "${sitesEnabled}${domain}.conf" > /dev/null 2>&1
    fi

    # rename domain name if it exists in sites-available
    if [[ ! -f ${sitesAvailable}${domain}.conf ]]; then
        echo -e "\e[1;31m\nVirtual Host {${domain}} Does not Exist.\n\e[0m"
        exit
    else
        mv "${sitesAvailable}${domain}.conf" "${sitesAvailable}${new_domain_name}.conf" > /dev/null 2>&1
    fi

    # remove log files
    rm "${logPath}${domain}-error.log" > /dev/null 2>&1
    rm "${logPath}${domain}-access.log" > /dev/null 2>&1

    declare -A CHANGES
    CHANGES[server_name]="${new_domain_name} www.${new_domain_name};"
    CHANGES[error_log]="${logPath}${new_domain_name}-error.log;"
    CHANGES[access_log]="${logPath}${new_domain_name}-access.log;"

    for key in "${!CHANGES[@]}";
    do
        lineNo=$(grep -n ${key} "${sitesAvailable}${new_domain_name}.conf" | cut -d: -f1)
        sed -i "${lineNo}s:.*: \t ${key} ${CHANGES[$key]}:" "${sitesAvailable}${new_domain_name}.conf"
    done

    # change domain in /etc/hosts file
    sed -i -e "s/${domain}/${new_domain_name}/g" ${hosts_file}

    # Enable new domain
    ln -s ${sitesAvailable}${new_domain_name}".conf" ${sitesEnabled}${new_domain_name}".conf"

    systemctl reload nginx

    echo -e "\e[1;32m\nVirtual Host {${domain}} Successfully Renamed To {${new_domain_name}}.\n\e[0m"

}

change() {

    # check if domain does not exist in sites-available
    if [[ ! -f ${sitesAvailable}${domain}.conf ]]; then
        echo -e "\e[1;31m\nVirtual Host {${domain}} Does not Exist.\n\e[0m"
        exit
    fi

    # Getting new root directory
    while [[ "$new_root_directory" == "" ]]
    do
        echo -e "\nChange root directory to : "
        read new_root_directory
    done

    lineNo=$(grep -n "\s\+root\s\+" "${sitesAvailable}${domain}.conf" | cut -d: -f1)
    sed -i "${lineNo}s:.*: \t root ${new_root_directory}; :" "${sitesAvailable}${domain}.conf"

    systemctl reload nginx

    echo -e "\e[1;32m\nVirtual Host {${domain}} Root Directory Changed To {${new_root_directory}}.\n\e[0m"
}

if [[ "$action" == 'create' ]] # Creating new domain
then

    hosting_directory=$3

    create

elif [[ "$action" == 'delete' ]] # Deleting existing domain
then

    hosting_directory=$3

    delete

elif [[ "$action" == 'rename' ]] # Renaming existing domain
then

    new_domain_name=$3

    rename

elif [[ "$action" == 'change' ]] # Change root directory of existing domain
then

    new_root_directory=$3

    change

fi
