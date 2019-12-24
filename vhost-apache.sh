#!/bin/bash

## Variables section
action=$1
domain=$2

email="webmaster@localhost"
sitesAvailable="/etc/apache2/sites-available/"
sitesEnabled="/etc/apache2/sites-enabled/"
logPath="/var/log/apache2/"
hosts_file="/etc/hosts"
apacheStatus=$(systemctl is-active apache2);

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

# Checking if apache2 is running
if [[ ! "$apacheStatus" == 'active'  ]]; then
    echo -e "\e[1;31m\nApache is not running, start Apache first using 'systemctl start apache2'.\n\e[0m"
    exit 0;
fi

# Getting user domain
while [[ "$domain" == "" ]]
do
	echo -e "Please enter your domain: "
	read domain
done

## Functions Section

enableSiteAndRestartApache() {

    # enable this site
    a2ensite "${1}.conf" > /dev/null 2>&1

    # allow rewrite module
    a2enmod rewrite > /dev/null 2>&1

    # reloading apache2
    service apache2 reload > /dev/null 2>&1

    # restarting apache2
    service apache2 restart > /dev/null 2>&1

}

create() {

    # check if domain already exists
    if [[ -f ${sitesAvailable}${domain}.conf ]]; then
        echo -e "\e[1;31m\nDomain Already Exists.\e[0m"
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
<VirtualHost *:80>
    ServerAdmin $email
    ServerName $domain
    ServerAlias www.$domain
    DocumentRoot $hosting_directory
    <Directory />
        AllowOverride All
    </Directory>
    <Directory $hosting_directory>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride all
        Require all granted
    </Directory>
    ErrorLog /var/log/apache2/$domain-error.log
    LogLevel error
    CustomLog /var/log/apache2/$domain-access.log combined
</VirtualHost>" | tee -a "${sitesAvailable}${domain}.conf" > /dev/null
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

    enableSiteAndRestartApache ${domain}

    echo -e "\e[1;32m\nVirtual Host ${domain} Successfully Created.\n\e[0m"

}

delete() {

    # first disable site
    sudo a2dissite ${domain} > /dev/null

    # remove domain if exists in sites-available
    if [[ -f ${sitesAvailable}${domain}.conf ]]; then
        rm "${sitesAvailable}${domain}.conf" > /dev/null 2>&1
    fi

    # remove domain if exists in sites-enabled
    if [[ -f ${sitesEnabled}${domain}.conf ]]; then
        rm "${sitesEnabled}${domain}.conf" > /dev/null 2>&1
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

    echo -e "\e[1;32m\nVirtual Host ${domain} Successfully Deleted.\n\e[0m"

}

rename() {

    # Getting user domain rename to
    while [[ "$new_domain_name" == "" ]]
    do
        echo -e "\nRename your domain to : "
        read new_domain_name
    done

    # rename domain name if it exists in sites-available
    if [[ ! -f ${sitesAvailable}${domain}.conf ]]; then
        echo -e "\e[1;31m\nVirtual Host {${domain}} Does not Exist.\n\e[0m"
        exit
    else
        mv "${sitesAvailable}${domain}.conf" "${sitesAvailable}${new_domain_name}.conf" > /dev/null 2>&1
    fi

    # remove domain if it exists in sites-enabled
    if [[ -e ${sitesEnabled}${domain}.conf ]]; then
        rm "${sitesEnabled}${domain}.conf" > /dev/null 2>&1
    fi

    declare -A CHANGES
    CHANGES[ServerName]="${new_domain_name}"
    CHANGES[ServerAlias]="www.${new_domain_name}"
    CHANGES[ErrorLog]="${logPath}${new_domain_name}-error.log"
    CHANGES[CustomLog]="${logPath}${new_domain_name}-access.log combined"

    for key in "${!CHANGES[@]}";
    do
        lineNo=$(grep -n ${key} "${sitesAvailable}${new_domain_name}.conf" | cut -d: -f1)
        sed -i "${lineNo}s:.*: \t ${key} ${CHANGES[$key]}:" "${sitesAvailable}${new_domain_name}.conf"
    done

    # remove log files
    rm "${logPath}${domain}-error.log" > /dev/null 2>&1
    rm "${logPath}${domain}-access.log" > /dev/null 2>&1

    # change domain in /etc/hosts file
    sed -i -e "s/${domain}/${new_domain_name}/g" ${hosts_file}

    enableSiteAndRestartApache ${new_domain_name}

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

    # change document root and directory
    declare -A CHANGES

    CHANGES[DocumentRoot]="${new_root_directory}"
    CHANGES[<Directory]="${new_root_directory}>"

    for key in "${!CHANGES[@]}";
    do
        lineNo=$(grep -n "${key}[[:space:]]*/[[:alpha:]]" "${sitesAvailable}${domain}.conf" | cut -d: -f1)
        sed -i "${lineNo}s:.*: \t ${key} ${CHANGES[$key]}:" "${sitesAvailable}${domain}.conf"
    done

    systemctl reload apache2

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