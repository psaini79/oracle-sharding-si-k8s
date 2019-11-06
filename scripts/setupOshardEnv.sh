#!/bin/bash

export LOGFILE="/tmp/oshard.log"
export LOGDIR="/tmp"
export STD_OUT_FILE="/proc/1/fd/1"
export STD_ERR_FILE="/proc/1/fd/2"
export PASSWD_FILE="/etc/oraclepwd/password"
export SHARD_ADMIN_USER="mysdbadmin"
export PDB_ADMIN_USER="pdbadmin"
export ORACLE_PWD=$(cat ${PASSWD_FILE} )
export PDB_SQL_SCRIPT="/tmp/pdb.sql"
export TOP_PID=$$
export GSM_HOST=$(hostname)
rm -f /tmp/sqllog.output
rm -f $PDB_SQL_SCRIPT
rm -f $LOGFILE

#################################### Print and Exit Functions Begin Here #######################
error_exit() {
local NOW=$(date +"%m-%d-%Y %T %Z")
        # Display error message and exit
#       echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
        echo "${NOW} : ${PROGNAME}: ${1:-"Unknown Error"}" | tee -a $LOGFILE > $STD_OUT_FILE
        kill -s TERM $TOP_PID
}

print_message ()
{
        local NOW=$(date +"%m-%d-%Y %T %Z")
        # Display  message and return
        echo "${NOW} : ${PROGNAME} : ${1:-"Unknown Message"}" | tee -a $LOGFILE > $STD_OUT_FILE
        return $?
}
#################################### Print and Exit Functions End Here #######################


####################################### Functions Related to checks ####################
dbChecks()
{
if [ -z "$ORACLE_HOME" ]
then
  error_exit "Set the ORACLE_HOME variable"
else
  print_message "ORACLE_HOME set to $ORACLE_HOME"
fi

# If ORACLE_HOME doesn't exist #
if [ ! -d "$ORACLE_HOME" ]
then
         error_exit  "The ORACLE_HOME $ORACLE_HOME does not exist"
else
         print_message "ORACLE_HOME Directory Exist"
fi

# Validate the value of ORACLE_SID #
if [ -z "$ORACLE_SID" ]
then
        error_exit "Set the ORACLE_SID variable"
else
        print_message "ORACLE_SID is set to $ORACLE_SID"
fi

if [ -z "$DB_HOST" ]
then
       print_message "DB_HOST variable is not set"
       export DB_HOST=$(hostname)
       print_message "DB_HOST is set to $DB_HOST"
else
       print_message "DB_HOST is set to $DB_HOST"
fi

if [ -z "$DB_PORT" ]
then
        print_message  "Set the DB_PORT variable"
        export DB_PORT=1521
else
        print_message "DB Port is set to $DB_PORT"
fi

if [ -z "${DB_RECOVERY_FILE_DEST}" ]; then
        print_message  "Set the DB_RECOVERY_FILE_DEST is not set"
        export DB_RECOVERY_FILE_DEST="${ORACLE_BASE}/oradata/fast_recovery_area/${ORACLE_SID}"
fi

if [ -z "${DATA_PUMP_DIR}" ]; then
        print_message  "DATA_PUMP_DIR is not set, it will se to ${ORACLE_BASE}/oradata/data_pump_dir"
        export DATA_PUMP_DIR="${ORACLE_BASE}/oradata/data_pump_dir"
fi

if [ ! -d "${DATA_PUMP_DIR}" ]; then
        print_message  "DATA_PUMP_DIR ${DATA_PUMP_DIR} directory does not exist"
        mkdir -p "${DB_PUMP_DIR}"
fi

if [ ! -d "${DB_RECOVERY_FILE_DEST}" ]; then
        print_message  "DB_RECOVERY_FILE_DEST ${DB_RECOVERY_FILE_DEST} directory does not exist"
        mkdir -p "${DB_RECOVERY_FILE_DEST}"
fi

if [ -z "${DB_RECOVERY_FILE_DEST_SIZE}" ]; then
        print_message  "DB_RECOVERY_FILE_DEST_SIZE is  not set"
        export DB_RECOVERY_FILE_DEST_SIZE="40G"
else
     print_message  "DB_RECOVERY_FILE_DEST_SIZE is set to ${DB_RECOVERY_FILE_DEST_SIZE}"
fi

}

gsmChecks()
{
    print_message "Performing GSM related checks"
}
###################################### Function Related to Check end here ###################

################################### Reset Password ###########################################
resetPassword()
{
if [ -f "${HOME}/setPassword.sh" ]; then
if [ ! -z "${ORACLE_PWD}" ]; then
"${HOME}"/setPassword.sh "$ORACLE_PWD"
fi
fi
}

###############################################################################################
setupCatalog()
{

localconnectStr="/ as sysdba"
systemStr="system/${ORACLE_PWD}"
print_message "Setting up Paramteres in Spfile"

cmd1="drop table shardsetup;"
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$systemStr"

cmd1="alter system set db_recovery_file_dest_size=${DB_RECOVERY_FILE_DEST_SIZE} scope=both;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"

cmd1="alter system set db_recovery_file_dest=\"${DB_RECOVERY_FILE_DEST}\" scope=both;"
#cmd=$( eval echo "$cmd1" )
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL "$cmd1" "$localconnectStr"


cmd1="alter system set open_links=16 scope=spfile;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="alter system set open_links_per_instance=16 scope=spfile;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="@$ORACLE_HOME/rdbms/admin/setCatalogDBPrivs.sql;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"
print_message "cat /tmp/setup_grants_privs.lst"

cmd1="alter user gsmcatuser account unlock;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="alter user gsmcatuser identified by $ORACLE_PWD;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


#cmd1="alter system set remote_listener=\"\(ADDRESS=\(HOST=$DB_HOST\)\(PORT=$DB_PORT\)\(PROTOCOL=tcp\)\)\";"
cmd1="alter system set remote_listener=\"(ADDRESS=(HOST=$DB_HOST)(PORT=$DB_PORT)(PROTOCOL=tcp))\" scope=both;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"



cmd1="shutdown immediate;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="startup mount;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="alter database archivelog;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="alter database open;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="alter database flashback on;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="alter database force logging;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL "$cmd1", "$localconnectStr"

cmd1="ALTER PLUGGABLE DATABASE ALL OPEN;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL "$cmd1"  "$localconnectStr"

if [ ! -z "${ORACLE_PDB}" ]; then
setupCatalogPDB
fi


cmd1="create table shardsetup (status varchar2(10));"
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL "$cmd1" "$systemStr"

cmd1="insert into shardsetup values('completed');"
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL "$cmd1" "$systemStr"

}

setupCatalogPDB()
{
#pdbConnStr="${PDB_ADMIN_USER}/${ORACLE_PWD}@//${DB_HOST}:1521/${ORACLE_PDB}"
pdbConnStr=" /as sysdba"

sqlScript="${PDB_SQL_SCRIPT}"

print_message "Settup Sql Script to setup Catalog PDB"
echo  "alter session set container=${ORACLE_PDB};" > "${sqlScript}"
echo  "create user ${SHARD_ADMIN_USER} identified by ${ORACLE_PWD};" >> "${sqlScript}"
echo  "grant connect, create session, gsmadmin_role to ${SHARD_ADMIN_USER} ;" >> "${sqlScript}"
echo  "grant inherit privileges on user SYS to GSMADMIN_INTERNAL;" >> "${sqlScript}"
echo  "execute dbms_xdb.sethttpport(8080);" >> ${sqlScript}
echo  "exec DBMS_SCHEDULER.SET_AGENT_REGISTRATION_PASS('${ORACLE_PWD}');" >> "${sqlScript}"
print_message "cat ${sqlScript}"
executeSQL "$cmd1"  "$pdbConnStr" "sqlScript"

}

######################################################################## Catalog Setup task ends here #################################

######################################################################## Primary Shard Setup task ends here #################################

setupShardPDB()
{

#pdbConnStr="${PDB_ADMIN_USER}/${ORACLE_PWD}@//${DB_HOST}:1521/${ORACLE_PDB}"
pdbConnStr=" /as sysdba"

sqlScript="${PDB_SQL_SCRIPT}"
print_message "Settup Sql Script to setup Catalog PDB"
echo  "alter session set container=${ORACLE_PDB};" > "${sqlScript}"
echo  "grant read,write on directory DATA_PUMP_DIR to GSMADMIN_INTERNAL;" >> "${sqlScript}"
echo  "grant sysdg to GSMUSER;" >> "${sqlScript}"
echo  "grant sysbackup to GSMUSER;" >> "${sqlScript}"
echo  "execute DBMS_GSM_FIX.validateShard;" >> ${sqlScript}
print_message "cat ${sqlScript}"
executeSQL "$cmd1"  "$pdbConnStr" "sqlScript"

}

setupShardCDB()
{
localconnectStr="/as sysdba"
systemStr="system/${ORACLE_PWD}"
print_message "Setting up Paramteres in Spfile"

cmd1="drop table shardsetup;"
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$systemStr"

cmd1="alter system set db_recovery_file_dest_size=${DB_RECOVERY_FILE_DEST_SIZE} scope=both;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"

cmd1="alter system set db_recovery_file_dest=\"${DB_RECOVERY_FILE_DEST}\" scope=both;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="alter system set open_links=16 scope=spfile;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="alter system set open_links_per_instance=16 scope=spfile;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="alter user gsmrootuser account unlock;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="alter user gsmrootuser identified by ${ORACLE_PWD}  container=all;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="grant sysdg to gsmrootuser;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="grant sysbackup to gsmrootuser;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="alter user GSMUSER account unlock;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="alter user GSMUSER identified by ${ORACLE_PWD} container=all;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="grant sysdg to GSMUSER;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="grant sysbackup to GSMUSER;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="alter system set dg_broker_start=true scope=both;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="create or replace directory DATA_PUMP_DIR as '${DATA_PUMP_DIR}';"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="grant read,write on directory DATA_PUMP_DIR to GSMADMIN_INTERNAL;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


#cmd1="alter system set remote_listener=\"\(ADDRESS=\(HOST=$DB_HOST\)\(PORT=$DB_PORT\)\(PROTOCOL=tcp\)\)\";"
cmd1="alter system set remote_listener=\"(ADDRESS=(HOST=$DB_HOST)(PORT=$DB_PORT)(PROTOCOL=tcp))\" scope=both;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="shutdown immediate;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="startup mount;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="alter database archivelog;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="alter database open;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="alter database flashback on;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="alter database force logging;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


cmd1="ALTER PLUGGABLE DATABASE ALL OPEN;"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$localconnectStr"


if [ ! -z "${ORACLE_PDB}" ]; then

setupShardPDB

fi

cmd1="create table shardsetup (status varchar2(10));"
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$systemStr"


cmd1="insert into shardsetup values('completed')"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd1"
executeSQL  "$cmd1"   "$systemStr"


}

######################################################################## Primary Shard Setup ends here #################################

######################################################################## GSM Setup Task Begin here #####################################
setupGSM()
{
local cstatus='false'
local sstatus='false'

setupGSMCatalog
setupGSMShard

}

checkStatus()
{
host=$1
port=1521
cpdb=$3
ccdb=$2
uname="system"
cpasswd=${ORACLE_PWD}

output=$( "$ORACLE_HOME"/bin/sqlplus -s "$uname/$cpasswd@//$host:$port/$ccdb" <<EOF
       set heading off feedback off verify off
       select status from shardsetup;
       exit
EOF
)

echo $output
}

setupGSMCatalog()
{
IFS='; ' read -r -a sarray   <<< "$SHARD_PARAMS"
for element in "${sarray[@]}"
do
  print_message "1st String in Shard params $element"
  type=$( echo $element | awk -F: '{print $NF }')
  if [ "${type}" == "catalog" ]; then
    host=$( echo $element | awk -F: '{print $1 }')
    db=$( echo $element | awk -F: '{print $2 }')
    pdb=$( echo $element | awk -F: '{print $3 }')
fi
done

count=0
if [ ! -z "${host}" ] && [ ! -z "${db}" ] && [ ! -z "${pdb}" ]
then
while [ ${count} -lt 30  ]; do
    coutput=$( checkStatus $host $db $pdb )
    if [ "${coutput}" == 'completed' ] ;then
        configureGSMCatalog $host $db $pdb
        break
    fi
  sleep 60
done
fi

if [ "${coutput}" != 'completed' ] ;then
 error_exit "Shard Catalog is not setup, Unable to proceed futher"
fi

}

configureGSMCatalog()
{
chost=$1
cport=1521
cpdb=$3
ccdb=$2
cadmin=${SHARD_ADMIN_USER}
cpasswd=${ORACLE_PWD}
num=$( awk 'BEGIN {srand(); print srand()}' )
gsm_name="director$num"
cmd1="create shardcatalog -database \"(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=${chost})(PORT=${cport}))(CONNECT_DATA=(SERVICE_NAME=${cpdb})))\" -user ${cadmin}/${cpasswd} -sdb shardcatalog -region region1,region2 -agent_port 8080 -agent_password ${cpasswd}"
print_message "Sending query to gsm to execute $cmd1"
executeGSM "$cmd1"

cmd1="add gsm -gsm ${gsm_name}  -listener 1521 -pwd ${cpasswd} -catalog ${chost}:${cport}/${cpdb}  -region region1"
# cmd=$(eval echo "$cmd1")
print_message "Sending query to gsm to execute $cmd1"
executeGSM "$cmd1"
}

setupGSMCatalog()
{
IFS='; ' read -r -a sarray   <<< "$SHARD_PARAMS"
for element in "${sarray[@]}"
do
  print_message "1st String in Shard params $element"
  type=$( echo $element | awk -F: '{print $NF }')
  if [ "${type}" == "primaryshard" ]; then
    host=$( echo $element | awk -F: '{print $1 }')
    db=$( echo $element | awk -F: '{print $2 }')
    pdb=$( echo $element | awk -F: '{print $3 }')
fi
done

count=0
if [ ! -z "${host}" ] && [ ! -z "${db}" ] && [ ! -z "${pdb}" ]
then
while [ ${count} -lt 30  ]; do
    coutput=$( checkStatus $host $db $pdb )
    if [ "${coutput}" == 'completed' ] ;then
        configureGSMShard $host $db $pdb
        break
    fi
  sleep 60
done
fi

if [ "${coutput}" != 'completed' ] ;then
 error_exit "Shard is not readi, Unable to proceed futher"
fi

}

configureGSMShard()
{
chost=$1
cport=1521
cpdb=$3
ccdb=$2
cpasswd=${ORACLE_PWD}
region="region1"
shardGName=primary_shardgroup
deployment_type="primary"

cmd1="add shardgroup -shardgroup ${shardGName} -deploy_as ${deployment_type} -region ${region}"
print_message "Sending query to gsm to execute $cmd1"
executeGSM "$cmd1"

cmd1="add cdb -connect ${chost}:${cport}:${ccdb} -pwd ${cpasswd}"
print_message "Sending query to gsm to execute $cmd1"
executeGSM "$cmd1"

cmd1="add shard -cdb ${ccdb} -connect ${chost}:${cport}/${cpdb} -shardgroup ${shardGName} -pwd ${cpasswd}"
print_message "Sending query to gsm to execute $cmd1"
executeGSM "$cmd1"

}

####################################################################### GSM Setup Task Ends here #########################################


######################################################################### Execute GSM Statements #########################################
executeGSM()
{

gsmQuery=$1

if [ -z "${gsmQuery}" ]; then
  error_exit "Empty sqlQuery passed to sqlplus. Operation Failed"
fi

print_message "Executing GSM query $gsmQuery"

output=$( "$ORACLE_HOME"/bin/gdsctl << EOF
 $gsmQuery
 exit
EOF
)

}
######################################################################## Execute GSM Statements Ends here ################################

########################################################################## Execute SQL Function Begin here ##############################
executeSQL()
{
sqlQuery=$1
connectStr=$2
type=$3

if [ -z "${sqlQuery}" ]; then
  error_exit "Empty sqlQuery passed to sqlplus. Operation Failed"
fi

if [ -z "${connectStr}" ]; then
   error_exit "Empty connectStr  passed to sqlplus. Operation Failed"
fi

if [ -z "${type}" ]; then
   type='notSet'
fi

if  [ "${type}" == "sqlScript" ]; then
print_message "Executing sql script using connectString \"${connectStr}\""
sqlOutput=$( "$ORACLE_HOME"/bin/sqlplus -s "$connectStr" << EOF
@ ${PDB_SQL_SCRIPT}
EOF
)
else
print_message "Executing query $sqlQuery using connectString \"${connectStr}\""
sqlOutput=$( "$ORACLE_HOME"/bin/sqlplus -s "$connectStr" << EOF 
$sqlQuery
EOF
)
print_message "SqlOutput : $sqlOutput"
fi
}

############################################################################## Execute SQl Function ends here #################################

#######################################
################## MAIN ###############

if [ "${OP_TYPE}" == "primaryshard" ]; then
   print_message "Performing Checks before proceeding for setup"
   dbChecks
   print_message "OP_TYPE set to ${OP_TYPE}. Process to setup ${OP_TYPE} will begin now"
   resetPassword
   setupShardCDB
elif [ "${OP_TYPE}" == "standbyshard" ]; then
   print_message "Performing Checks before proceeding for setup"
   dbChecks
   print_message "OP_TYPE set to ${OP_TYPE}. Process to setup ${OP_TYPE} will begin now"
   setupShardStandby
elif [ "${OP_TYPE}" == "catalog" ]; then
  print_message "Performing Checks before proceeding for setup"
  dbChecks
  print_message "OP_TYPE set to ${OP_TYPE}. Process to setup ${OP_TYPE} will begin now"
  resetPassword
  setupCatalog
elif [ "${OP_TYPE}" == "gsm" ]; then
  print_message "Performing Checks before proceeding for setup"
  gsmChecks
  print_message "OP_TYPE set to ${OP_TYPE}. Process to setup ${OP_TYPE} will begin now"
  setupGSM
else
  print_message "OP_TYPE must be set to (gsm|catalog|primaryshard|standbyshard)"
fi
