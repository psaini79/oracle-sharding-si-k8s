#!/bin/bash

export LOGFILE="/tmp/oshard.log"
export LOGDIR="/tmp"
export STD_OUT_FILE="/proc/1/fd/1"
export STD_ERR_FILE="/proc/1/fd/2"
export PASSWD_FILE="/etc/oraclepwd/password"
export SHARD_ADMIN_USER="mysdbadmin"
export PDB_ADMIN_USER="pdbadmin"
export ORACLE_PWD=$(cat ${PASSWD_FILE} )
export TOP_PID=$$

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

if [ -z "${DB_FILE_DEST}" ]; then
        print_message  "Set the DB_FILE_DEST is not set"
        export DB_FILE_DEST="${ORACLE_BASE}/oradata/fast_recovery_area/${ORACLE_SID}"
fi

if [ -z "${DATA_PUMP_DIR}" ]; then
        print_message  "DB_FILE_DEST ${DB_FILE_DEST} directory does not exist"
        export DATA_PUMP_DIR="${ORACLE_BASE}/oradata/data_pump_dir"
fi

if [ ! -d "${DATA_PUMP_DIR}" ]; then
        print_message  "DATA_PUMP_DIR ${DATA_PUMP_DIR} directory does not exist"
        mkdir -p "${DB_FILE_DEST}"
fi

if [ ! -d "${DB_FILE_DEST}" ]; then
        print_message  "DB_FILE_DEST ${DB_FILE_DEST} directory does not exist"
        mkdir -p "${DB_FILE_DEST}"
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
print_message "Setting up Paramteres in Spfile"
cmd1="alter system set db_create_file_dest='${DB_FILE_DEST}' scope=both;"
cmd=$( eval echo "$cmd1" )
print_message "Sending query to sqlplus to execute $cmd"
executeSQL "$cmd" "$localconnectStr"


cmd1="alter system set open_links=16 scope=spfile;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="alter system set open_links_per_instance=16 scope=spfile;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="spool /tmp/setup_grants_privs.lst; @$ORACLE_HOME/rdbms/admin/setCatalogDBPrivs.sql"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"
print_message "cat /tmp/setup_grants_privs.lst"

cmd1="alter user gsmcatuser account unlock;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="alter user gsmcatuser identified by $ORACLE_PWD;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="alter system set remote_listener=\"\(ADDRESS=\(HOST=$DB_HOST\)\(PORT=$DB_PORT\)\(PROTOCOL=tcp\)\)\";"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="alter system set db_recovery_file_dest_size=${DB_RECOVERY_FILE_DEST_SIZE} scope=both;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="shutdown immediate;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="startup mount;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="alter database archivelog;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="alter database open;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="alter database flashback on;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="alter database force logging;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL "$cmd", "$localconnectStr"

cmd1="ALTER PLUGGABLE DATABASE ALL OPEN;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL "$cmd"  "$localconnectStr"

if [ ! -z "${ORACLE_PDB}" ]; then
setupCatalogPDB
fi


cmd1="create table shardsetup (status varchar2(10));"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL "$cmd" "$localconnectStr"

cmd1="insert into shardsetup values('completed');commit;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL "$cmd" "$localconnectStr"

}

setupCatalogPDB()
{
pdbConnStr="${PDB_ADMIN_USER}/${ORACLE_PWD}@//${DB_HOST}:1521/${ORACLE_PDB}"

cmd1="create user ${SHARD_ADMIN_USER} identified by ${ORACLE_PWD};"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL "$cmd"  "$pdbConnStr"


cmd1="grant connect, create session, gsmadmin_role to ${SHARD_ADMIN_USER} ;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL "$cmd"  "$pdbConnStr"


cmd1="grant inherit privileges on user SYS to GSMADMIN_INTERNAL;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL "$cmd"  "$pdbConnStr"



cmd1="execute dbms_xdb.sethttpport(8080);"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL "$cmd"  "$pdbConnStr"


cmd1="@$ORACLE_HOME/rdbms/admin/prvtrsch.plb;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL "$cmd"  "$pdbConnStr"


cmd1="exec DBMS_SCHEDULER.SET_AGENT_REGISTRATION_PASS('${ORACLE_PASSWORD}');"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL "$cmd"  "$pdbConnStr"


}

######################################################################## Catalog Setup task ends here #################################

######################################################################## Primary Shard Setup task ends here #################################

setupShardPDB()
{

pdbConnStr="${PDB_ADMIN_USER}/${ORACLE_PWD}@//${DB_HOST}:1521/${ORACLE_PDB}"

cmd1="grant read,write on directory DATA_PUMP_DIR to GSMADMIN_INTERNAL;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL "$cmd"  "$pdbConnStr"


cmd1="grant sysdg to GSMUSER;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL "$cmd"  "$pdbConnStr"


cmd1="grant sysbackup to GSMUSER;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL "$cmd"  "$pdbConnStr"


cmd1="set serveroutput on; execute DBMS_GSM_FIX.validateShard"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL "$cmd"  "$pdbConnStr"


}

setupShardCDB()
{
localconnectStr="/as sysdba"

print_message "Setting up Paramteres in Spfile"
cmd1="alter system set db_create_file_dest='${DB_FILE_DEST}' scope=both;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="alter system set open_links=16 scope=spfile;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="alter system set open_links_per_instance=16 scope=spfile;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="alter user gsmrootuser account unlock;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="alter user gsmrootuser identified by ${ORACLE_PWD}  container=all;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="grant sysdg to gsmrootuser;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="grant sysbackup to gsmrootuser;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="alter user GSMUSER account unlock;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="alter user GSMUSER identified by ${ORACLE_PWD} container=all;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="grant sysdg to GSMUSER;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="grant sysbackup to GSMUSER;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="alter system set dg_broker_start=true scope=both;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="create or replace directory DATA_PUMP_DIR as ${DATA_PUMP_DIR};"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="grant read,write on directory ${DATA_PUMP_DIR} to GSMADMIN_INTERNAL;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="alter system set remote_listener=\"\(ADDRESS=\(HOST=$DB_HOST\)\(PORT=$DB_PORT\)\(PROTOCOL=tcp\)\)\";"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="alter system set db_recovery_file_dest_size=${DB_RECOVERY_FILE_DEST_SIZE} scope=both;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="shutdown immediate;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="startup mount;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="alter database archivelog;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="alter database open;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="alter database flashback on;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="alter database force logging;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="ALTER PLUGGABLE DATABASE ALL OPEN;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


if [ ! -z "${ORACLE_PDB}" ]; then

setupShardPDB

fi

cmd1="create table shardsetup (status varchar2(10));"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


cmd1="insert into shardsetup values('completed');commit;"
cmd=$(eval echo "$cmd1")
print_message "Sending query to sqlplus to execute $cmd"
executeSQL  "$cmd"   "$localconnectStr"


}

######################################################################## Primary Shard Setup ends here #################################

######################################################################## GSM Setup Task Begin here #####################################
setupGSMCatalog()
{

export ORACLE_HOME=$DB_HOME
export PATH=$ORACLE_HOME/bin:$PATH

cmd1="create shardcatalog -database "\(DESCRIPTION=\(ADDRESS=\(PROTOCOL=tcp\)\(HOST=${SHARD_CATALOG_HOST}\)\(PORT=${CATALOG_DB_PORT}\)\)\(CONNECT_DATA=\(SERVICE_NAME=${CATALOG_PDB}\)\)\)" -user ${SHARD_ADMIN_USER}/${ORACLE_PWD} -sdb shardcatalog -region region1,region2 -agent_port 8080 -agent_password ${ORACLE_PWD}"
cmd=$(eval echo "$cmd1")
print_message "Sending query to gsm to execute $cmd"
executeGSM "$cmd"

cmd1="add gsm -gsm sharddirector1 -listener 1521 -pwd ${ORACLE_PWD}  -catalog ${SHARD_CATALOG_HOST}:${CATALOG_DB_PORT}/${CATALOG_PDB}  -region region1"
cmd=$(eval echo "$cmd1")
print_message "Sending query to gsm to execute $cmd"
executeGSM "$cmd"

}

setupGSMShard()
{

export ORACLE_HOME=$DB_HOME
export PATH=$ORACLE_HOME/bin:$PATH

SHARD_HOSTNAME=$1
SHARD_CDB_PORT=1521
SHARD_CDB_SID=$2
SHARD_CDB_PDB=$3

cmd1="add shardgroup -shardgroup primary_shardgroup -deploy_as primary -region region1"
cmd=$(eval echo "$cmd1")
print_message "Sending query to gsm to execute $cmd"
executeGSM "$cmd"

cmd1="add cdb -connect ${SHARD_HOSTNAME}:${SHARD_CDB_PORT}:${SHARD_CDB_SID} -pwd ${ORACLE_PWD}"
cmd=$(eval echo "$cmd1")
print_message "Sending query to gsm to execute $cmd"
executeGSM "$cmd"

cmd1="add shard -cdb ${SHARD_CDB_SID} -connect   ${SHARD_HOSTNAME}:${SHARD_CDB_PORT}/${SHARD_CDB_PDB} -shardgroup primary_shardgroup -pwd ${ORACLE_PWD}"
cmd=$(eval echo "$cmd1")
print_message "Sending query to gsm to execute $cmd"
executeGSM "$cmd"

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

"$ORACLE_HOME"/bin/gdsctl << EOF
 $gsmQuery
 exit
EOF

}
######################################################################## Execute GSM Statements Ends here ################################

########################################################################## Execute SQL Function Begin here ##############################
executeSQL()
{
sqlQuery=$1
connectStr=$2

if [ -z "${sqlQuery}" ]; then
  error_exit "Empty sqlQuery passed to sqlplus. Operation Failed"
fi

if [ -z "${connectStr}" ]; then
   error_exit "Empty connectStr  passed to sqlplus. Operation Failed"
fi

print_message "Executing query $sqlQuery using connectString ${connectStr}"

sqlOutput=$(
echo "set feedback off verify off heading off pagesize 0
$sqlQuery
exit
" | "$ORACLE_HOME"/bin/sqlplus -s "$connectStr"
)

print_message "Output of SqlQuery ${sqlOutput}"

}

############################################################################## Execute SQl Function ends here #################################

#######################################
################## MAIN ###############

if [ "${OP_TYPE}" == "primaryShard" ]; then
   print_message "Performing Checks before proceeding for setup"
   dbChecks
   print_message "OP_TYPE set to ${OP_TYPE}. Process to setup ${OP_TYPE} will begin now"
   resetPassword
   setupShardCDB
elif [ "${OP_TYPE}" == "standbyShard" ]; then
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

