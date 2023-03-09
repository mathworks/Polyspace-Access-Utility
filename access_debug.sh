#!/bin/bash

# (c) MathWorks Inc. 2023

echo ""
echo "The script should be launched in sudo (admin) mode on the server where Polyspace Access is running and in the installation folder of the Polyspace Access Cluster Admin agent."
echo "It is compatible with the versions of Polyspace Access from R2020b to R2022b."
echo "It is recommended to activate the debug mode of Polyspace Access before launching this script."
echo "See https://www.mathworks.com/matlabcentral/answers/852070-how-can-i-get-debug-information-for-polyspace-access for more information."
echo ""



if ! command -v docker &> /dev/null
then
	echo "Error: Docker not found, the script cannot be executed"
	exit 
	fi

#if [[ $EUID -ne 0]]; then 	echo "Error: This script must be run as root"
#	exit 
#fi

docker version &> /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Error: Docker commands cannot be launched, please launch this command in sudo (admin) mode: sudo ./access_debug.sh"
	exit 
fi

# check arguments

if [ $# -eq 1 ]; then
	access_folder=$1
else
	access_folder="."
fi
version_file="$access_folder/VERSION"
settings_file="$access_folder/settings.json"
if [ ! -f "$settings_file" ]; then
	echo "Error: file $settings_file cannot be found"
	exit 1;
fi
if [ ! -f "$version_file" ]; then
	echo "Error: file $version_file cannot be found"
	exit 1;
fi

version=$(awk '{print $1}' $version_file)

if [[ $version < "R2022a" ]]; then
	sql='docker exec -i polyspace-access-db-main psql -a -b -U postgres prs_data'
else
	sql='docker exec -i polyspace-access-db-0-main psql -a -b -U postgres prs_data'
fi

info() {
	echo "Number of runs:"
	$sql -t -c "SELECT COUNT(\"RunID\") FROM \"Result\".\"Run\""

	echo "Number of projects:"
	$sql -t -c "SELECT COUNT(\"DefinitionID\") FROM \"Project\".\"Definition\""

	echo "Size of the database:"
	$sql -t -c "SELECT pg_size_pretty(pg_database_size('prs_data'))"

	echo "Information about the memory:"
	free -h

	echo "Information on the disk space:"
	df -h /

	echo "Information on the OS:"
	uname -a
}

output_files=(info.txt tables.csv indexes.csv automations.csv containers_list.txt)

echo "Getting information on the database..."

info > "${output_files[0]}"
$sql < get_tables.sql > "${output_files[1]}"
$sql < get_indexes.sql > "${output_files[2]}"
$sql < get_automations.sql > "${output_files[3]}"

echo "Getting information on the Docker containers"

docker container ls > "${output_files[4]}"

rm -f all_info.zip
zip -m all_info.zip "${output_files[@]}" 

if [[ $version < "R2022a" ]]; then

	containers_until_21b=(
	polyspace-access-web-server-main
	polyspace-access-etl-main
	polyspace-access-db-main
	issuetracker-server-main
	issuetracker-ui-main
	usermanager-server-main
	usermanager-db-main
	usermanager-ui-main
	gateway
	admin
	usermanager
	polyspace-access
	issuetracker
	)

	for container in "${containers_until_21b[@]}"
	do
		docker logs "$container" > "$container".logs.txt 2>&1
		docker inspect "$container" > "${container}_inspect.logs.txt" 2>&1
	done

else

	containers_from_22a=(
	polyspace-access-web-server-0-main
	polyspace-access-etl-0-main
	polyspace-access-db-0-main
	polyspace-access-download-0-main
	issuetracker-server-0-main
	issuetracker-ui-0-main
	usermanager-server-0-main
	usermanager-db-0-main
	usermanager-ui-0-main
	gateway
	admin
	usermanager
	polyspace-access
	issuetracker
	)

	for container in "${containers_from_22a[@]}"
	do
		docker logs "$container" > "$container".logs.txt 2>&1
		docker inspect "$container" > "${container}_inspect.logs.txt" 2>&1
	done

fi

zip -rm all_info.zip *.logs.txt

echo "Getting information files"
# Adding two other files useful to know the configuration of Polyspace Access

# copy the settings.json file and remove the passwords
cp $settings_file settings_.json

sed -i 's/"dbPassword":[[:space:]]*"[^"]*"/"dbPassword":"xxx"/g' settings_.json
sed -i 's/"password":[[:space:]]*"[^"]*"/"password":"xxxxxxx"/g' settings_.json
sed -i 's/"adminInitialPassword":[[:space:]]*"[^"]*"/"adminInitialPassword":"xxx"/g' settings_.json
sed -i 's/"ldapPassword":[[:space:]]*"[^"]*"/"ldapPassword":"xxx"/g' settings_.json
zip -m all_info.zip settings_.json

zip -j all_info.zip $version_file

echo "Ouput file all_info.zip generated. Please send this file to MathWorks."
echo ""
