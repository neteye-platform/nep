#! /bin/bash

# Browse NEP Package content and extract a full list of all the existing objects
# This script must run in the folder of the NEP Package to list
# Objects retrieved:
# - DataList
# - Command
# - ExternalCommand (Not yet tested)
# - HostTemplate
# - ServiceTemplate
# - ServiceSet
# - ITOA Dashboard

# Name of the NEP: this is the root of all nep directories
nep_name=$1
nep_base_path=${nep_name}
pushd $nep_base_path

output_file="/root/objects_list.csv"

declare -A director_baskets_repos
director_baskets_repos[baskets/import]='No'
director_baskets_repos[baskets/import_once]='Yes'


function search_cat_jq_sed_save() {
	infilename=$1
	search_string=$2
	jq_string=$3
	sed_string=$4
	outfilename=$5

	output=$(grep "${search_string}" ${infilename})
	if [ $? == 0 ]
	then
		cat ${infilename} | jq ${jq_string} | sed ${sed_string} >> ${outfilename}
	fi
}


function get_director_objects_list() {
	basket=$1
	outfile=$2
	updatable=$3

        cat ${basket} | jq '.DataList[]        | [ "Director Data List",        .list_name,    "'${updatable}'", "'${basket}'" ] | @csv' | sed 's/\\"/"/g' | sed 's/""/"/g' >> ${outfile}
        cat ${basket} | jq '.Command[]         | [ "Director Command",          .object_name,  "'${updatable}'", "'${basket}'" ] | @csv' | sed 's/\\"/"/g' | sed 's/""/"/g' >> ${outfile}
        cat ${basket} | jq '.ExternalCommand[] | [ "Director External Command", .object_name,  "'${updatable}'", "'${basket}'" ] | @csv' | sed 's/\\"/"/g' | sed 's/""/"/g' >> ${outfile}
        cat ${basket} | jq '.HostTemplate[]    | [ "Director Host Template",    .object_name,  "'${updatable}'", "'${basket}'" ] | @csv' | sed 's/\\"/"/g' | sed 's/""/"/g' >> ${outfile}
        cat ${basket} | jq '.ServiceTemplate[] | [ "Director Service Template", .object_name,  "'${updatable}'", "'${basket}'" ] | @csv' | sed 's/\\"/"/g' | sed 's/""/"/g' >> ${outfile}
        cat ${basket} | jq '.ServiceSet[]      | [ "Director Service Set",      .object_name,  "'${updatable}'", "'${basket}'" ] | @csv' | sed 's/\\"/"/g' | sed 's/""/"/g' >> ${outfile}
		cat ${basket} | jq '.ImportSource[]    | [ "Director Import Source",    .source_name,  "'${updatable}'", "'${basket}'" ] | @csv' | sed 's/\\"/"/g' | sed 's/""/"/g' >> ${outfile}
		cat ${basket} | jq '.SyncRule[]        | [ "Director Sync Rule",        .rule_name,    "'${updatable}'", "'${basket}'" ] | @csv' | sed 's/\\"/"/g' | sed 's/""/"/g' >> ${outfile}
}

function get_dependencies_from_files() {
	files_path=$1
	outfile=$2

	for file in $(find $files_path/ -type f)
	do
		cat $file | gawk 'match($0, /^\s*apply Dependency "(.*)"/, group) { print "\"Icinga2 Dependency\",\"" group[1] "\",\"No\",\"'$file'\"" }' >> ${outfile}
	done
}

function get_dashboards_list() {
	dashboard=$1
	outfile=$2
	updatable=$3

	cat ${dashboard} | jq '[ "ITOA Dashboard", .title, "'${updatable}'", "'${dashboard}'" ] | @csv' | sed 's/\\"/"/g' | sed 's/""/"/g' >> ${outfile}
}


tmpfile=$(mktemp)

for key in ${!director_baskets_repos[@]}
do
	baskets_dir=$key
	if [ -d ${baskets_dir} ]
	then
		echo "Loading objects from ${baskets_dir}"

		is_updatable=${director_baskets_repos[${key}]}

		for basket in $(ls -1 $baskets_dir)
		do
			echo " - Basket: ${basket}"
			get_director_objects_list "${baskets_dir}/${basket}" "${tmpfile}" "${is_updatable}"
		done
	fi
done

itoa_dir=itoa
if [ -d ${itoa} ]
then
	for dashboards_dir in $(ls -1 ${itoa_dir})
	do
		dashboard_path=${itoa_dir}/${dashboards_dir}
		for dashboard in $(ls -1 ${dashboard_path}/*.json)
		do
			get_dashboards_list $dashboard $tmpfile 'No'
		done
	done
fi

custom_files_dir=custom_files
if [ -d ${custom_files_dir} ]
then
	get_dependencies_from_files "#{custom_files_dir}" $tmpfile
fi

echo '"Object Type", "Object Name", "Do not edit", "Containing File"' > ${output_file}
cat ${tmpfile} | sort -k1 -t , >> ${output_file}
rm -f ${tmpfile}

popd