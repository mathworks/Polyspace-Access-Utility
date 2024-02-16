#!/bin/bash

# Copyright (c) 2024 The MathWorks, Inc.
# All Rights Reserved.

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

tool_version="1.3"
copyright="(c) MathWorks Inc. 2024"

##########
#  Init  #
##########

# check a few things #

if ! command -v docker &>/dev/null; then
	echo "Error: Docker not found, the script cannot be executed"
	exit
fi

docker version &>/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Error: Docker commands cannot be launched, please launch this command in sudo (admin) mode: sudo ./access_util.sh"
	exit 1
fi


if [ ! -w . ]; then
	echo "Error: current folder is not writable. Please set a write access to the current folder."
	exit 1
fi


if [ $# -eq 1 ]; then
	access_folder=$1
else
	access_folder=".."
fi

version_file="$access_folder/VERSION"
settings_file="$access_folder/settings.json"

if [ ! -f "$settings_file" ]; then
	echo "Error: settings.json cannot be found, this tool should be executed in a subfolder of the Polyspace Access installation folder"
	exit 1
fi

if [ ! -f "$version_file" ]; then
	echo "Error: file VERSION cannot be found, cannot continue"
	exit 1
fi

# check that whiptail is installed
if ! command -v whiptail &>/dev/null; then
	echo "whiptail is required to run the tool but is not installed."
	echo "Use"
	echo " sudo apt install whiptail"
	echo "to install it"
	exit 1
fi

logfile="log.txt"

version=$(awk '{print $1}' < $version_file)
if [[ $version < "R2022a" ]]; then
	db_main='polyspace-access-db-main'
	etl_main='polyspace-access-etl-main'
	web_server_main='polyspace-access-web-server-main'
else
	db_main='polyspace-access-db-0-main'
	etl_main='polyspace-access-etl-0-main'
	web_server_main='polyspace-access-web-server-0-main'
fi
sql="docker exec -i $db_main psql -a -b -U postgres prs_data"

# get some variables
storageDir=$(grep '"etlStorageDir"' $settings_file | awk -F ':' '{print $2}' | sed -e 's/"//g' -e 's/,//' -e 's/^[ \t]*//')
databaseDir=$(grep '"dbVolume"' $settings_file | awk -F ':' 'FNR==1 {print $2}' | sed -e 's/"//g' -e 's/,//' -e 's/^[ \t]*//')
mem_total_bytes=$(awk '/^Mem/ {printf $2}' <(free))
mem_total=$(awk '/^Mem/ {printf $2}' <(free -h))

################
#   Functions  #
################

function get_json_field_value {
	local json="$1"
	local field="$2"
	local value
	value=$(grep -m 1 -o "\"$field\": *\"[^\"]*\"" <<< "$json" | awk -F'"' '{print $4}')
	echo $value
}

function backup {

	global_status_code=0

	# give a warning because some services will be shutdown
	if whiptail --yesno --defaultno "Warning! Some services (upload...) will be shut down during backup!\nBackup on large database can be time consuming.\nAre you sure you want to continue?" 15 50; then

		backup_file=$(whiptail --title "Path of the backup file" --inputbox "Enter the path of the backup file (e.g.: ./backup.sql)" 10 50 3>&1 1>&2 2>&3)

		if whiptail --title "Confirm backup location" --yesno --defaultno "The database will be backed up in $backup_file.\nProceed ?" 8 78; then
			{
				log "Backup starting..."
				sleep 0.5
				log "Stopping the ETL and the web server"
				echo -e "XXX\n0\nStopping the ETL and the Web server... \nXXX"
				docker stop $etl_main $web_server_main 2>>$logfile 1>/dev/null
				status_code=$?
				log "status: $status_code"
				global_status_code=$((global_status_code + status_code))
				echo -e "XXX\n33\nStopping the ETL and the web server... Done.\nXXX"
				sleep 1

				log "Creating the backup file"
				echo -e "XXX\n33\nCreating the backup file... \nXXX"
				# docker exec $db_main pg_dumpall -U postgres | gzip > $backup_file
				docker exec $db_main pg_dumpall -U postgres >"$backup_file"
				status_code=$?
				log "status: $status_code"
				global_status_code=$((global_status_code + status_code))
				echo -e "XXX\n66\nCreating the backup file... Done.\nXXX"
				sleep 1

				log "Starting the ETL and web server"
				echo -e "XXX\n66\nStarting the ETL and the web server... \nXXX"
				docker start $etl_main $web_server_main 2>>$logfile 1>/dev/null
				status_code=$?
				log "status: $status_code"
				global_status_code=$((global_status_code + status_code))
				echo -e "XXX\n100\nStarting the ETL and the web server... Done.\nXXX"
				sleep 1

			} > >(whiptail --title "Creating backup file" --gauge "Please wait" 6 50 0)
		log "Backup complete"
		log "Final status: $global_status_code"
		if [ $global_status_code -eq 0 ]; then
			whiptail --msgbox "Backup complete" 10 30
		else
			whiptail --msgbox "Error occured during backup. See the file log.txt" 10 30
		fi

		fi
	fi

}

function restore_backup {

	global_status_code=0

	# give a warning because some services will be shutdown
	if whiptail --yesno --defaultno "Warning! Some services (upload...) will be shut down to restore\nthe backup and the database folder will be deleted!\nAre you sure you want to continue?" 10 70; then

		backup_file=$(whiptail --title "Path of the backup file" --inputbox "Enter the path of the backup file" 10 40 3>&1 1>&2 2>&3)

		if (whiptail --title "Confirm backup location" --yesno --defaultno "The database will be backed up from $backup_file. Proceed ?" 8 78); then

			if [ -e "$backup_file" ]; then
				{
					log "Restore backup"
					log "Backup file is $backup_file"
					log "database folder is $databaseDir"

					sleep 0.5
					log "stopping the etl and the web server"
					echo -e "xxx\n0\nstopping the etl and the web server... \nxxx"
					docker stop $etl_main $web_server_main 2>>$logfile 1>/dev/null
					status_code=$?
					log "status: $status_code"
					global_status_code=$((global_status_code + status_code))
					sleep 2
					echo -e "xxx\n33\nstopping the etl and the web server... done.\nxxx"
					sleep 1

					# check if the database is a folder or a volume
					if [[ "$databaseDir" = '/'* ]]; then

						#folder
						log "deleting the database folder and restarting the db service"
						echo -e "xxx\n33\ndeleting the database folder...\nxxx"
						rm -rf "$databaseDir"
						docker restart $db_main 2>>$logfile 1>/dev/null
						status_code=$?
						log "status: $status_code"
						global_status_code=$((global_status_code + status_code))
						sleep 2
						echo -e "xxx\n66\ndeleting the database folder... done\nxxx"
						sleep 1

					else
						# volume

						log "Deleting the database volume and restarting the db service"
						echo -e "XXX\n33\nDeleting the database volume...\nXXX"
						docker stop $db_main 2>>$logfile 1>/dev/null
						docker volume rm "$databaseDir" 2>>$logfile 1>/dev/null
						docker volume create "$databaseDir" 2>>$logfile 1>/dev/null
						docker restart $db_main 2>>$logfile 1>/dev/null
						status_code=$?
						log "status: $status_code"
						global_status_code=$((global_status_code + status_code))
						sleep 2
						echo -e "XXX\n66\nDeleting the database volume... Done\nXXX"
						sleep 1

					fi

					log "Restoring the database backup"
					echo -e "XXX\n66\nRestoring the database backup...\nXXX"
					docker exec -i $db_main psql -U postgres postgres <$backup_file 2>>$logfile 1>/dev/null
					# gzip -cd $backup_file | docker exec -i $db_main psql -U postgres postgres 2>> $logfile 1> /dev/null
					status_code=$?
					log "status: $status_code"
					global_status_code=$((global_status_code + status_code))
					sleep 3
					echo -e "XXX\n100\nRestoring the database backup... Done\nXXX"
					sleep 1
				} > >(whiptail --title "Restoring the backup file" --gauge "Please wait" 6 50 0)
			log "Restore operation complete"
			log "Final status: $global_status_code"
			if [ $global_status_code -eq 0 ]; then
				whiptail --msgbox "Backup restored. Restart the Cluster Admin and Restart the Apps" 10 30
			else
				whiptail --msgbox "Error occured during restore. See the file log.txt" 10 30
			fi
		else
			whiptail --title "Wrong backupfile" --msgbox "Backup file $backup_file does not exist. Cancelling backup"
			fi # if backup file exists
		fi  # if backup confirmed
	fi

}

function full_vacuum {

	global_status_code=0

	# give a warning because some services will be shutdown
	if whiptail --yesno --defaultno "Warning! Some services (upload...) will be shut down during backup!\nVacuum on large database can be time consuming.\nAre you sure you want to continue?" 15 50; then

		{
			log "Vacuum starting..."
			sleep 0.5
			log "Stopping the ETL and the web server"
			echo -e "XXX\n0\nStopping the ETL and the Web server... \nXXX"
			docker stop $etl_main $web_server_main 2>>$logfile 1>/dev/null
			status_code=$?
			log "status: $status_code"
			global_status_code=$((global_status_code + status_code))
			echo -e "XXX\n33\nStopping the ETL and the web server... Done.\nXXX"
			sleep 1

			log "Performing the vacuum"
			echo -e "XXX\n33\nVacuuming... \nXXX"
			docker exec $db_main vacuumdb -U postgres --full prs_data 2>>$logfile
			status_code=$?
			log "status: $status_code"
			global_status_code=$((global_status_code + status_code))
			echo -e "XXX\n66\nVacuuming... Done.\nXXX"
			sleep 1

			log "Starting the ETL and web server"
			echo -e "XXX\n66\nStarting the ETL and the web server... \nXXX"
			docker start $etl_main $web_server_main 2>>$logfile 1>/dev/null
			status_code=$?
			log "status: $status_code"
			global_status_code=$((global_status_code + status_code))
			echo -e "XXX\n100\nStarting the ETL and the web server... Done.\nXXX"
			sleep 1

		} > >(whiptail --title "Full vacuum" --gauge "Please wait" 6 50 0)
	log "Vacuum complete"
	log "Final status: $global_status_code"
	if [ $global_status_code -eq 0 ]; then
		whiptail --msgbox "Vacuum complete" 10 30
	else
		whiptail --msgbox "Error occured during vacuum. See the file log.txt" 10 30
	fi

	fi

}

function delete_trash {
	log "Delete projects in WaitingForDeletion"
	toDelete=$($sql <project_hierarchy.sql | awk -F'ProjectsWaitingForDeletion/' '{print $2}')
	log "projects: $toDelete"
	number_ToDelete=$(echo "$toDelete" | grep -Ev "^#|^$" | wc -l)
	if [ $number_ToDelete -eq 0 ]; then
		whiptail --msgbox "No project to delete" 10 30
	else
		if whiptail --scrolltext --yesno --defaultno "Confirm the deletion of $number_ToDelete projects" 20 50; then

			if [[ $version < "R2023b" ]]; then
				output=$($sql <project_hierarchy.sql | grep 'ProjectsWaitingForDeletion/' | sed '/^\s*#/d;/^\s*$/d')
				# create the output file
				>cleanup.pscauto
				IFS=$'\n'$'\r'
				for line in $output; do
					echo "delete_project \"$line\"" >>cleanup.pscauto
				done
				cat cleanup.pscauto >>"$logfile"
				log "Copying pscauto to $storageDir"
				cp cleanup.pscauto "$storageDir"
				whiptail --msgbox "The deletion has been launched.\nThe projects will be deleted soon." 10 40
				log "Deletion performed"
			else
				whiptail --msgbox "Since R2023b, please use the command\n polyspace-access -delete-project ProjectsWaitingForDeletion -host...\nto delete all the projects in ProjectsWaitingForDeletion" 10 80
				echo "   "
				echo "******************************"
				echo "Since R2023b, use the command"
				echo " polyspace-access -delete-project ProjectsWaitingForDeletion -host ..."
				echo "to delete all the projects in ProjectsWaitingForDeletion"
			fi
		fi
	fi
}

function show_info {
	number_runs=$($sql -t -c "SELECT COUNT(\"RunID\") FROM \"Result\".\"Run\"" | sed 's/ //g')
	number_projects=$($sql -t -c "SELECT COUNT(\"DefinitionID\") FROM \"Project\".\"Definition\"" | sed 's/ //g')
	db_size=$($sql -t -c "SELECT pg_size_pretty(pg_database_size('prs_data'))" | sed 's/ //g')
	mem_avail=$(awk '/^Mem/ {printf $7}' <(free -h))
	mem_free=$(awk '/^Mem/ {printf $4}' <(free -h))

	number_failed=$($sql -t -c "SELECT \"RefRun\", \"StartTime\", \"EndTime\", AGE(\"EndTime\", \"StartTime\") AS \"UploadDuration\" FROM \"Status\".\"Etl\" WHERE \"Status\" = 'Failed'" | sed '/^\s*#/d;/^\s*$/d' | wc -l)

	number_running=$($sql -t -c "SELECT \"RefRun\", \"StartTime\", \"EndTime\", AGE(\"EndTime\", \"StartTime\"),\"Status\" AS \"UploadDuration\" FROM \"Status\".\"Etl\" WHERE \"Status\" IS NULL OR \"Status\" = ''" | sed '/^\s*#/d;/^\s*$/d' | wc -l)

	fs_size=$(awk 'FNR==2 {printf $2}' <(df -h /))
	fs_use=$(awk 'FNR==2 {printf $5}' <(df -h /))

	json_content=$(<"$settings_file")
	dbVol=$(get_json_field_value "$json_content" "dbVolume")

	is_volume=""
	if [[ "$dbVol" == /* ]]; then
		# a folder
		db_volume=$dbVol
	else
		# a volume
		is_volume="(volume name: $dbVol)"
		volume_inspect=$(sudo docker volume inspect $dbVol)
		db_volume=$(get_json_field_value "$volume_inspect" "Mountpoint")
	fi

	db_size=$(awk 'FNR==2 {printf $2}' <(df -h $db_volume))

	text=(
		"Number of runs: $number_runs
		Number of projects: $number_projects
		Size of the database: $db_size\n
		Number of running uploads: $number_running
		Number of failed uploads: $number_failed\n
		Memory:
		Total: $mem_total
		Available: $mem_avail
		Free: $mem_free\n

		Database location: $db_volume
		$is_volume
		Disk space on the database volume: $db_size

		Disk space on / :
		Total: $fs_size
		Use: $fs_use"
	)

	whiptail --title "Status" --msgbox "$text" 28 55

}

function restart_containers {
	# give a warning because some services will be shutdown
	if whiptail --yesno --defaultno "Warning! The services (upload, connections...) will be shut down during restart!\nAre you sure you want to continue?" 15 50; then
		{

			log "Restarting containers"
			echo -e "XXX\n0\nStopping the containers... \nXXX"
			if [[ $version < "R2022a" ]]; then
				docker stop gateway \
					polyspace-access-web-server-main \
					polyspace-access-etl-main \
					polyspace-access-db-main \
					polyspace-access-download-main \
					issuetracker-server-main \
					issuetracker-ui-main \
					usermanager-server-main \
					usermanager-ui-main \
					usermanager-db-main \
					polyspace-access \
					issuetracker \
					usermanager >/dev/null 2>&1
								else
									docker stop gateway \
										polyspace-access-web-server-0-main \
										polyspace-access-etl-0-main \
										polyspace-access-db-0-main \
										polyspace-access-download-0-main \
										issuetracker-server-0-main \
										issuetracker-ui-0-main \
										usermanager-server-0-main \
										usermanager-ui-0-main \
										usermanager-db-0-main \
										polyspace-access \
										issuetracker \
										usermanager >/dev/null 2>&1
			fi

			echo -e "XXX\n50\nStopping the containers... Done.\nXXX"
			sleep 1

			echo -e "XXX\n50\nStarting the containers... \nXXX"
			if [[ $version < "R2022a" ]]; then
				docker start usermanager \
					issuetracker \
					polyspace-access \
					usermanager-db-main \
					usermanager-ui-main \
					usermanager-server-main \
					issuetracker-ui-main \
					issuetracker-server-main \
					polyspace-access-download-main \
					polyspace-access-db-main \
					polyspace-access-etl-main \
					polyspace-access-web-server-main \
					gateway >/dev/null 2>&1
								else
									docker start usermanager \
										issuetracker \
										polyspace-access \
										usermanager-db-0-main \
										usermanager-ui-0-main \
										usermanager-server-0-main \
										issuetracker-ui-0-main \
										issuetracker-server-0-main \
										polyspace-access-download-0-main polyspace-access-db-0-main \
										polyspace-access-etl-0-main \
										polyspace-access-web-server-0-main \
										gateway >/dev/null 2>&1
			fi

			echo -e "XXX\n100\nStarting the containers... Done.\nXXX"
			sleep 1
		} > >(whiptail --title "Restarting..." --gauge "Please wait" 6 50 0)

	whiptail --msgbox "Restart complete" 10 30

	log "Done"
	fi
}

function create_debug_info {

	log "Creating debug file"

	if [ ! -e access_debug.sh ]; then
		whiptail --msgbox "Script access_debug.sh not found: debug files cannot be generated." 10 30
	else
		{
			echo -e "XXX\n50\nGenerating debug files... \nXXX"
			./access_debug.sh $access_folder >$logfile 2>&1
			echo -e "XXX\n99\nGenerating debug files... Done\nXXX"
		} | whiptail --title "Generating debug files" --gauge "Please wait" 6 60 0
	whiptail --msgbox "File generated." 10 50
	fi

	log "Log files created"
}

function log {
	msg=$1
	echo $(date +"%d-%m-%Y %T") ">> $msg" >>$logfile 2>&1
}

#############
#   Start   #
#############

echo "-- New log entry --" >>$logfile
log "Version of the tool: $tool_version"
log "Version of Polyspace Access: $version"
log "Memory: $mem_total"

if [ "$mem_total_bytes" -lt 32505856 ]; then
	whiptail --title "Warning!" --msgbox "The server does not meet the RAM requirements (32Gb of RAM).\nProblems can occur during upload/downloads.\nClick Ok to continue." 10 50
fi

while [ 1 ]; do

	if [[ $version < "R2023b" ]]; then
		choice=$(
		whiptail --title "Polyspace Access Utility $tool_version $copyright" --nocancel --menu "Choose a command" 16 80 9 \
			"1" "Launch backup" \
			"2" "Restore backup" \
			"3" "Full vacuum" \
			"4" "Restart Docker containers" \
			"5" "Delete projects in WaitingForDeletion" \
			"6" "Server statistics" \
			"7" "Create debug log files" \
			"8" "Exit" 3>&2 2>&1 1>&3
		)

		case $choice in
			1)
				backup
				;;
			2)
				restore_backup
				;;
			3)
				full_vacuum
				;;
			4)
				restart_containers
				;;
			5)
				delete_trash
				;;
			6)
				show_info
				;;
			7)
				create_debug_info
				;;
			8)
				echo "-- End of entry --" >>$logfile
				exit
				;;
		esac
	else
		choice=$(
		whiptail --title "Polyspace Access Utility $tool_version $copyright" --nocancel --menu "Choose a command" 16 80 9 \
			"1" "Launch backup" \
			"2" "Restore backup" \
			"3" "Full vacuum" \
			"4" "Restart Docker containers" \
			"5" "Server statistics" \
			"6" "Create debug log files" \
			"7" "Exit" 3>&2 2>&1 1>&3
		)

		case $choice in
			1)
				backup
				;;
			2)
				restore_backup
				;;
			3)
				full_vacuum
				;;
			4)
				restart_containers
				;;
			5)
				show_info
				;;
			6)
				create_debug_info
				;;
			7)
				echo "-- End of entry --" >>$logfile
				exit
				;;
		esac
	fi
done

