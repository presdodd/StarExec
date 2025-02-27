#!/bin/bash

# /////////////////////////////////////////////
# NAME:
# StarExec Function Script
#
# AUTHOR:
# Tyler Jensen
#
# DESCRIPTION:
# This is a script containing common functions used by the jobscript
#
# /////////////////////////////////////////////

# Include the predefined status codes and functions
. $SCRIPT_DIR/status_codes.bash

#################################################################################
# base64 decode some names which could otherwise have nasty characters in them
#################################################################################

# will do a base 64 decode on all solver_names, all solver_paths, and the bench path
function decodePathArrays {
	log "decoding all base 64 encoded strings"

	#decode every solver name, solver path, and benchmark suffix in the arrays
	for (( i = 0; i < NUM_STAGES; ++i )); do
		SOLVER_NAMES[i]=$(     base64 -d <<< "${SOLVER_NAMES[i]}")
		SOLVER_PATHS[i]=$(     base64 -d <<< "${SOLVER_PATHS[i]}")
		BENCH_SUFFIXES[i]=$(   base64 -d <<< "${BENCH_SUFFIXES[i]}")
		BENCH_INPUT_PATHS[i]=$(base64 -d <<< "${BENCH_INPUT_PATHS[i]}")

		log "decoded the benchmark input ${BENCH_INPUT_PATHS[i]}"
	done
}

function decodeBenchmarkName {
	BENCH_PATH=$(base64 -d <<< "$BENCH_PATH")
	PAIR_OUTPUT_DIRECTORY=$(base64 -d <<< "$PAIR_OUTPUT_DIRECTORY")
}

#need to make sure benchmark name is decoded in every file
decodeBenchmarkName

#################################################################################

#lock files that indicate a particular sandbox is in use
SANDBOX_LOCK_DIR=$WORKING_DIR_BASE'/sandboxlock.lock'
SANDBOX2_LOCK_DIR=$WORKING_DIR_BASE'/sandbox2lock.lock'

#files that indicate that lock files are currently being modified
SANDBOX_LOCK_USED=$WORKING_DIR_BASE'/sandboxlock.active'
SANDBOX2_LOCK_USED=$WORKING_DIR_BASE'/sandbox2lock.active'

# Path to local workspace for each node in cluster.

# Path to the job input directory
JOB_IN_DIR="$SHARED_DIR/jobin"

# Path to the job output directory
JOB_OUT_DIR="$SHARED_DIR/joboutput"

######################################################################

# setup the memory limit for this stage
function limitMem {
	#Gets the memory of the node in kilobytes
	local NODE_MEM=$(vmstat -s | head -1 | sed 's/K total memory//')

	#then, convert kb to mb
	((NODE_MEM = NODE_MEM / 1024))
	log "node memory in megabytes = $NODE_MEM"

	#then, set to half the memory
	((NODE_MEM = NODE_MEM / NUM_SLOTS))
	log "node memory after accounting for pairs allowed to run on node = $NODE_MEM"

	if ((MAX_MEM > NODE_MEM)); then
		log "truncating max memory from requested $MAX_MEM to $NODE_MEM"
		export MAX_MEM=$NODE_MEM
	fi
}

# initializes all workspace variables based on the value of the SANDBOX variable,
# which should already be set either by calling initSandbox
function initWorkspaceVariables {
	LOCAL_TMP_DIR="$WORKING_DIR/tmp"

	# Path to where the solver will be copied
	LOCAL_SOLVER_DIR="$WORKING_DIR/solver"

	# Path to where the benchmark will be copied
	LOCAL_BENCH_DIR="$WORKING_DIR/benchmark"

	BENCH_INPUT_DIR="$WORKING_DIR/benchinputs"

	# The benchmark's name
	BENCH_NAME="${BENCH_PATH##*/}"

	BENCH_FILE_EXTENSION="${BENCH_NAME##*.}"

	if [ "$BENCH_FILE_EXTENSION" == "$BENCH_NAME" ]; then
		# this means that there is no file extension in $BENCH_NAME
		LOCAL_BENCH_NAME="theBenchmark"
	else
		LOCAL_BENCH_NAME="theBenchmark.$BENCH_FILE_EXTENSION"
	fi

	# The path to the benchmark on the execution host
	LOCAL_BENCH_PATH="$LOCAL_BENCH_DIR/$LOCAL_BENCH_NAME"

	# Path to where the solver will be copied
	LOCAL_SOLVER_DIR="$WORKING_DIR/solver"

	# Path to where the pre-processor will be copied
	LOCAL_PREPROCESSOR_DIR="$WORKING_DIR/preprocessor"

	# The path to the bin directory of the solver on the execution host
	if [ $BUILD_JOB == "true" ]; then
		LOCAL_RUNSOLVER_PATH="$LOCAL_SOLVER_DIR/runsolver"
	else
		LOCAL_RUNSOLVER_PATH="$LOCAL_SOLVER_DIR/bin/runsolver"
	fi

	OUT_DIR="$WORKING_DIR/output"
	WATCHFILE="$OUT_DIR/watcher.out"
	VARFILE="$OUT_DIR/var.out"
	STDOUT_FILE="$OUT_DIR/stdout.txt"

	# The path to the benchmark on the execution host
	PROCESSED_BENCH_PATH="$OUT_DIR/procBenchmark"

	SAVED_OUTPUT_DIR="$WORKING_DIR/savedoutput"

	limitMem
}

function createLocalTmpDirectory {
	mkdir -p "$LOCAL_TMP_DIR"

	# Check the directory actually does exist
	if [ ! -d "$LOCAL_TMP_DIR" ]; then
		mkdir "$LOCAL_TMP_DIR"
		log "job error: cannot create sandbox tmp directory '$LOCAL_TMP_DIR'"
	fi
}

#checks to see whether the first argument is a valid integer
function isInteger {
	local re='^[0-9]+$'
	if ! [[ $1 =~ $re ]] ; then
		return 1
	fi
	return 0
}

# checks to see whether the pair with the given PID is actually running
function isPairRunning {
	log "isPairRunning called on pair pid = $1"

	if ! (isInteger $1); then
		log "$1 is not a valid integer, so no pair is running"
		return 1
	fi
	output=$(cat "$LOCK_DIR/$1")
	if [ -z "${output// }" ]; then
		log "no process output was saved in the lock file, so assuming pair was deleted"
		# the job is not still running
		return 1
	fi

	log "$output"
	currentOutput=$(ps -p $1 -o pid,cmd | awk 'NR>1')
	log "$currentOutput"
	#check to make sure the output of ps from when the lock was written is equivalent to what we see now
	if [[ $currentOutput == *$output* ]]; then
		log "process is still running, so the sandbox is still in use"
		return 0
	fi
	#otherwise, the job is not still running
	return 1
}

# Makes a lock file in for a single sandbox
# $1 The sandbox to use
function makeLockFile {
	log "able to get sandbox $1!"
	# make a file that is named with the current PID so we know which pair should be running here
	touch "$LOCK_DIR/$$"
	processString=$(ps -p $$ -o pid,cmd | awk 'NR>1')
	log "Found data for this process $processString"
	echo $processString > "$LOCK_DIR/$$"
	log "putting this job into sandbox $1 $$"
}

#first argument is the sandbox (1 or 2) and second argument is the pair ID
function trySandbox {

	if (($1 == 1)); then
		LOCK_DIR="$SANDBOX_LOCK_DIR"
		LOCK_USED="$SANDBOX_LOCK_USED"
	else
		LOCK_DIR="$SANDBOX2_LOCK_DIR"
		LOCK_USED="$SANDBOX2_LOCK_USED"
	fi
	#force script to wait until it can get the outer lock file to do the block in parens
	#timeout is 4 seconds-- we give up if we aren't able to get the lock in that amount of time
	if (
	flock -x -w 4 200 || return 1
		#we have exclusive rights to work on the lock for this sandbox within this block

		log "got the right to use the lock for sandbox $1"
		#check to see if we can make the lock directory-- if so, we can run in sandbox
		if mkdir "$LOCK_DIR" ; then
			makeLockFile $1
			return 0
		fi
		#if we couldnt get the sandbox directory, there are 2 possibilites. Either it is occupied,
		#or a previous job did not clean up the lock correctly. To check, we see if the pair given
		#in the directory is still running

		pairPID=$(ls "$LOCK_DIR")
		log "found the pairID = $pairPID"


		if ! isPairRunning $pairPID ; then
			#this means the sandbox is NOT actually in use, and that the old pair just did not clean up
			log "found that the pair is not running in sandbox $1"
			safeRmLock "$LOCK_DIR"

			#try again to get the sandbox1 directory-- we still may fail if another pair is doing this at the same time
			if mkdir "$LOCK_DIR" ; then
				makeLockFile $1
				return 0
			fi
		else
			log "found that pair $pairPID is running in sandbox $1"
		fi
		#could not get the sandbox
		return 1


	#End of Flock command. We return from trySandbox whatever flock returns
	)200>"$LOCK_USED" ; then
		return 0
	else
		return 1
	fi

}

# figures out which sandbox the given job pair should run in.
# If no sandbox can be secured, terminate this jobpair
function initSandbox {
	#try to get sandbox1 first
	if (trySandbox 1); then
		SANDBOX=1
		SANDBOX_PARAM=$SANDBOX_USER_ONE
		CORES="0-3"
		WORKING_DIR=$WORKING_DIR_BASE'/sandbox'
	elif (trySandbox 2); then
		SANDBOX=2
		SANDBOX_PARAM=$SANDBOX_USER_TWO
		CORES="4-7"
		WORKING_DIR=$WORKING_DIR_BASE'/sandbox2'
	else #failed to get either sandbox
		log "unable to secure any sandbox for this job!"
		sendNode "$HOSTNAME" "0"
		sendStatus "$ERROR_RUNSCRIPT"
		sendStatusToLaterStages "$ERROR_RUNSCRIPT" 0
		exit 0
	fi
	sendNode "$HOSTNAME" "$SANDBOX"
}

function log {
	echo "$(date +'%D %r %Z'): $1"
}

function safeRmLock {
	if [ "$1" == "" ] ; then
		log "Unsafe rm all detected for lock"
	else
		log "doing rm all on  $1"
		rm -rf "$1"
	fi
}

#call "safeCp description source destination" to do cp -r source destination,
#unless source is empty, in which case an error message is printed
function safeCpAll {
	if [ "$2" == "" ]; then
		log "$1: Unsafe cp -r $2/* $3"
	else
		log "$1: Doing safeCpAll on $2 to $3"
		cp -r "$2"/* "$3"
	fi
}

# call "safeRm description dirname" to do an "rm -r dirname/*" except if
# dirname is the empty string, in which case an error message is printed.
function safeRm {
	if [ "$2" == "" ] ; then
		log "Unsafe rm all detected for $1"
	else
		log "Doing rm all on $2 ($1)"
		rm -rf "$2"
		mkdir "$2"
		chmod gu+rwx "$2"
	fi
}

#cleans up files to prepare for the next stage of the job
function cleanForNextStage {
	cd $WORKING_DIR
	sudo chown -R $(whoami) $WORKING_DIR
	chmod -R gu+rxw $WORKING_DIR

	# Clear the output directory
	safeRm output-directory "$OUT_DIR"

	# Clear the local solver directory
	safeRm local-solver-directory "$LOCAL_SOLVER_DIR"

	# Clear the local benchmark, as it will be replaced by the output of this stage
	rm "$LOCAL_BENCH_PATH"
}

# Kills all of a sandboxes processes if their job pair becomes deadlocked
# and time out.
# Input:
#    $1 - The timeout of the jobpair, currently the wallclock
#    $2 - The extra time we give to the jobpair after the wallclock timeout
#    $3 - The user to kill all processes for, should be sandbox or sandbox2
# author: Albert Giegerch
function killDeadlockedJobPair {
	TIMEOUT=$1
	EXTRA=$2
	CURRENT_USER=$3

	log "Wallclock timeout for current jobpair = $TIMEOUT"
	log "Extra time given to jobpair on top of wallclock timeout before we kill it = $EXTRA"
	log "User whose job will be killed if it exceeds it's runtime = $CURRENT_USER"

	sleep $(( TIMEOUT + EXTRA ))

	log "killDeadlockedJobPair: About to kill jobpair run by $CURRENT_USER because it has exceeded it's total allotted runtime."
	cd $WORKING_DIR
	sudo -u $CURRENT_USER killall -SIGKILL --user $CURRENT_USER

	if [ $BUILD_JOB == "true" ]; then
		cleanUpAfterKilledBuildJob
	fi
}

# Calls copyOutput at an increment specified. Should be killed
# when the incremental copy is no longer needed.
# $1 Increment, in seconds, at which to copy back output
# $2 Maximum amount of time to run, in seconds. Should be the timeout for the pair
# $3 Current stage number
# $4 the stdout copy option (1 means don't save, otherwise save)
# $5 the other output copy option (same as above)
function copyOutputIncrementally {
	PERIOD=$1
	TIMEOUT=$2
	while ((TIMEOUT > 0)); do
		sleep $PERIOD
		copyOutputNoStats $3 $4 $5

		if ((DISK_QUOTA_EXCEEDED == 1)); then
			break
		fi
		((TIMEOUT = TIMEOUT - PERIOD))
	done
	log "done copying incremental output: the pair's timeout has been reached"
}

# $1 0 if we are done with the job and 1 otherwise. Used to decide whether to clean up scripts and locks
# $2 The name of the user that executed this job. Used to clear out the /tmp directory. Only used if we are done with the job
function cleanWorkspace {
	log "cleaning execution host workspace..."

	cd $WORKING_DIR
	# change ownership and permissions to make sure we can clean everything up
	sudo chown -R $(whoami) $WORKING_DIR

	mkdir -p $WORKING_DIR

	chmod 770 $WORKING_DIR
	chmod g+s $WORKING_DIR
	log "WORKING_DIR is $WORKING_DIR"

	chmod -R gu+rxw $WORKING_DIR

	# Clear the output directory
	safeRm output-directory "$OUT_DIR"

	# Clear the local solver directory
	safeRm local-solver-directory "$LOCAL_SOLVER_DIR"

	safeRm local-tmp-directory "$LOCAL_TMP_DIR"

	safeRm bench-inputs "$BENCH_INPUT_DIR"

	# Clear the local benchmark directory
	safeRm local-benchmark-directory "$LOCAL_BENCH_DIR"

	safeRm saved-output-dir "$SAVED_OUTPUT_DIR"

	#only delete the job script / lock files if we are done with the job
	log "about to check whether to delete lock files given $1"
	if (($1 == 0)); then
		log "cleaning up scripts and lock files"
		rm -f "$SCRIPT_PATH"
		rm -f "$JOB_IN_DIR/depend_$PAIR_ID.txt"
		# remove all /tmp files owned by the user that executed this job
		cd /tmp
		sudo -u $2 find /tmp/* -user $2 -exec rm -fr {} \; 2>/dev/null
		cd $WORKING_DIR

		if ((SANDBOX == 1)); then
			safeRmLock "$SANDBOX_LOCK_DIR"
		elif ((SANDBOX == 2)); then
			safeRmLock "$SANDBOX2_LOCK_DIR"
		fi
	fi
	log "execution host $HOSTNAME cleaned"
}

function dbExec {
	local ATTEMPT=2
	while
		((ATTEMPT != 0)) &&
		! (mysql -u"$DB_USER" -p"$DB_PASS" -h "$REPORT_HOST" "$DB_NAME" -e "$1")
	do
		log "Unable to connect to database."
		sleep 20
		((--ATTEMPT))
		false # set $? to fail on last iteration
	done
}

# Will strip quotes from arguments passed
function dbEscape {
	echo ${@//[\'\"]/}
}

function sendStageStatus {
	local STAGE_NUMBER=$(($2))
	local STATUS=$(($1))
	log "sending status for stage number $STAGE_NUMBER"
	dbExec "CALL UpdatePairStageStatus($PAIR_ID, $STAGE_NUMBER, $STATUS)"
}

function sendStatusToLaterStages {
	local STAGE_NUMBER=$(($2))
	local STATUS=$(($1))
	log "sending status for stage numbers greater than $STAGE_NUMBER"
	dbExec "CALL UpdateLaterStageStatuses($PAIR_ID, $STAGE_NUMBER, $STATUS)"
}

function setRunStatsToZeroForLaterStages {
	local STAGE=$(($1))
	log "setting all stats to 0 for stages greater than $STAGE"
	dbExec "CALL SetRunStatsForLaterStagesToZero($PAIR_ID, $STAGE)"
}

function sendStatus {
	local STATUS=$(($1))
	log "sending job status $STATUS"
	dbExec "CALL UpdatePairStatus($PAIR_ID, $STATUS)"
}

function sendWallclockExceededStatus {
	log "epilog detects wall clock time exceeded"
	sendStatus $EXCEED_RUNTIME
	sendStageStatus $EXCEED_RUNTIME ${STAGE_NUMBERS[STAGE_INDEX]}
}

function sendCpuExceededStatus {
	log "epilog detects cpu time exceeded"
	sendStatus $EXCEED_CPU
	sendStageStatus $EXCEED_CPU ${STAGE_NUMBERS[STAGE_INDEX]}
}

function sendExceedMemStatus {
	log "epilog detects max virtual memory exceeded"
	sendStatus $EXCEED_MEM
	sendStageStatus $EXCEED_MEM ${STAGE_NUMBERS[STAGE_INDEX]}
}

function setStartTime {
	log "sending start time for pair id = $PAIR_ID"
	dbExec "CALL SetPairStartTime($PAIR_ID)"
}

function setEndTime {
	log "sending end time for pair id = $PAIR_ID"
	dbExec "
		CALL SetPairEndTime($PAIR_ID);
		CALL AddToEventOccurrencesNotRelatedToQueue('job pairs run', 1);
		CALL AddToEventOccurrencesForJobPairsQueue('job pairs run', 1, $PAIR_ID);
	"
}

function sendNode {
	local NODE=$(dbEscape $1)
	local SANDBOX=$(($2))
	log "sending Node Id $NODE to $REPORT_HOST in sandbox $SANDBOX"
	sendStatus $STATUS_RUNNING
	sendStageStatus $STATUS_RUNNING ${STAGE_NUMBERS[STAGE_INDEX]}
	dbExec "
		CALL UpdateNodeId($PAIR_ID, '$NODE', $SANDBOX);
	"
}

function limitExceeded {
	log "job error: $1 limit exceeded, job terminated"
	sendStatus $2
	exit 1
}

# processes the attributes for a pair. Takes a file produced by a post processor as the first argument
# and a stage number as the second argument
# Ben McCune
function processAttributes {
	local STAGE=$(($2))
	if [ -z $1 ]; then
		log "No argument passed to processAttributes"
		exit 1
	fi

	a=0
	local QUERY=""
	while read line; do
		if [[ -z $line ]]; then
			continue # line is empty, can be skipped
		fi
		((a++))
		key=${line%=*}   # everything before '='
		value=${line#*=} # everything after  '='
		# Only process if key and value are both non-null strings
		if [[ -n $key && -n $value ]]; then
			key=$(dbEscape $key)
			value=$(dbEscape $value)
			log "processing attribute $a (pair=$PAIR_ID, key='$key', value='$value' stage='$STAGE')"
			QUERY+="CALL AddJobAttr($PAIR_ID, '$key', '$value', $STAGE);"
		else
			log "bad post processing - cannot process attribute $a"
		fi
	done < $1

	if [[ -n $QUERY ]]; then
		log "saving attributes to database"
		dbExec "$QUERY"
	fi
}

# updates stats for the pair - parameters are var.out ($1) and watcher.out ($2) from runsolver
# Ben McCune
# $1 the varfile
# $2 the watchfile
# $3 The option on how to copy back stdout
# $4 The option on how to copy back the other output fiels
# $5 The benchmarking framework
function updateStats {
	if [ "$5" == "$BENCHEXEC" ]; then
		WALLCLOCK_TIME=$(sed -n 's/^{\?walltime=\([0-9\.]*\)s}\?$/\1/p' $1)
		CPU_TIME=$(sed -n 's/^{\?cputime=\([0-9\.]*\)s}\?$/\1/p' $1)
		CPU_USER_TIME=0
		SYSTEM_TIME=0
		MAX_VIRTUAL_MEMORY=$(sed -n 's/^{\?memory=\([0-9\.]*\)}\?$/\1/p' $1)

		MAX_RESIDENT_SET_SIZE=0
		PAGE_RECLAIMS=0
		PAGE_FAULTS=0
		BLOCK_INPUT=0
		BLOCK_OUTPUT=0
		VOL_CONTEXT_SWITCHES=0
		INVOL_CONTEXT_SWITCHES=0
	else
		WALLCLOCK_TIME=$(sed -n 's/^WCTIME=\([0-9\.]*\)$/\1/p' $1)
		CPU_TIME=$(sed -n 's/^CPUTIME=\([0-9\.]*\)$/\1/p' $1)
		CPU_USER_TIME=$(sed -n 's/^USERTIME=\([0-9\.]*\)$/\1/p' $1)
		SYSTEM_TIME=$(sed -n 's/^SYSTEMTIME=\([0-9\.]*\)$/\1/p' $1)
		MAX_VIRTUAL_MEMORY=$(sed -n 's/^MAXVM=\([0-9\.]*\)$/\1/p' $1)

		log "the max virtual memory was $MAX_VIRTUAL_MEMORY"
		log "the var file was"
		cat $1
		log "end varfile"

		SOLVER_STATUS_CODE=$(awk '/Child status/ { print $3 }' $2)

		log "the solver exit code was $SOLVER_STATUS_CODE"

		MAX_RESIDENT_SET_SIZE=$(awk '/maximum resident set size/ { print $5 }' $2)
		PAGE_RECLAIMS=$(awk '/page reclaims/ { print $3 }' $2)
		PAGE_FAULTS=$(awk '/page faults/ { print $3 }' $2)
		BLOCK_INPUT=$(awk '/block input/ { print $4 }' $2)
		BLOCK_OUTPUT=$(awk '/block output/ { print $4 }' $2)
		VOL_CONTEXT_SWITCHES=$(awk '/^voluntary context switches/ { print $4 }' $2)
		INVOL_CONTEXT_SWITCHES=$(awk '/involuntary context switches/ { print $4 }' $2)

		# just sanitize these latter to avoid db errors, since fishing things out of the watchfile is more error-prone apparently.
		if [[ ! ( "$MAX_RESIDENT_SET_SIZE" =~ ^[0-9\.]+$ ) ]] ; then MAX_RESIDENT_SET_SIZE=0 ; fi
		if [[ ! ( "$PAGE_RECLAIMS" =~ ^[0-9\.]+$ ) ]] ; then PAGE_RECLAIMS=0 ; fi
		if [[ ! ( "$PAGE_FAULTS" =~ ^[0-9\.]+$ ) ]] ; then PAGE_FAULTS=0 ; fi
		if [[ ! ( "$BLOCK_INPUT" =~ ^[0-9\.]+$ ) ]] ; then BLOCK_INPUT=0 ; fi
		if [[ ! ( "$BLOCK_OUTPUT" =~ ^[0-9\.]+$ ) ]] ; then BLOCK_OUTPUT=0 ; fi
		if [[ ! ( "$VOL_CONTEXT_SWITCHES" =~ ^[0-9\.]+$ ) ]] ; then VOL_CONTEXT_SWITCHES=0 ; fi
		if [[ ! ( "$INVOL_CONTEXT_SWITCHES" =~ ^[0-9\.]+$ ) ]] ; then INVOL_CONTEXT_SWITCHES=0 ; fi
	fi

	ROUNDED_WALLCLOCK_TIME=$( printf "%.0f" $WALLCLOCK_TIME )
	ROUNDED_CPU_TIME=$( printf "%.0f" $CPU_TIME )

	((STAREXEC_WALLCLOCK_LIMIT = STAREXEC_WALLCLOCK_LIMIT - ROUNDED_WALLCLOCK_TIME))
	((STAREXEC_CPU_LIMIT = STAREXEC_CPU_LIMIT - ROUNDED_CPU_TIME))

	EXEC_HOST=$(hostname)
	getTotalOutputSizeToCopy $3 $4
	log "sending Pair Stats"

	if ! (dbExec "CALL UpdatePairRunSolverStats($PAIR_ID, '$EXEC_HOST', $WALLCLOCK_TIME, $CPU_TIME, $CPU_USER_TIME, $SYSTEM_TIME, $MAX_VIRTUAL_MEMORY, $((MAX_RESIDENT_SET_SIZE)), $((CURRENT_STAGE_NUMBER)), $((DISK_SIZE)))") ; then
		log "Error copying stats from watchfile into database. Copying varfile to log {"
		cat $1
		log "} End varfile."
		log "Copying watchfile to log {"
		cat $2
		log "} End watchfile."
	fi

	log "sent job stats to $REPORT_HOST"

	log "cpu usage = $CPU_TIME"
	log "wallclock time = $WALLCLOCK_TIME"
}

function createDir {
	mkdir -p "$1"

	# Check the directory actually does exist
	if [ ! -d "$1" ]; then
		mkdir "$1"
		log "job error: cannot create directory '$1' this jobs output cannot be saved"
	fi
}

# copys output without doing post-processing or updating the database stats
# $1 The current stage number
# $2 the stdout copy option (1 means don't save, otherwise save)
# $3 the other output copy option (same as above)
function copyOutputNoStats {
	setDiskQuotaExceeded $2 $3
	if ((DISK_QUOTA_EXCEEDED == 1)); then
		log "not saving output: user disk quota exceeded"
		return
	fi
	createDir "$PAIR_OUTPUT_DIRECTORY"
	createDir "$SAVED_OUTPUT_DIR"
	OUTPUT_SUFFIX="_output"
	if ((NUM_STAGES == 1)); then
		PAIR_OUTPUT_PATH="$PAIR_OUTPUT_DIRECTORY/$PAIR_ID.txt"
		PAIR_OTHER_OUTPUT_PATH="$PAIR_OUTPUT_DIRECTORY/$PAIR_ID$OUTPUT_SUFFIX"
	else
		PAIR_OUTPUT_PATH="$PAIR_OUTPUT_DIRECTORY/$1.txt"
		PAIR_OTHER_OUTPUT_PATH="$PAIR_OUTPUT_DIRECTORY/$1$OUTPUT_SUFFIX"
	fi

	if (($2 != 1)); then
		cp "$STDOUT_FILE" "$PAIR_OUTPUT_PATH"
	fi

	if (($3 != 1)); then
		rsync --prune-empty-dirs -r -u "$OUT_DIR/output_files/" "$PAIR_OTHER_OUTPUT_PATH"
	fi
	SAVED_PAIR_OUTPUT_PATH="$SAVED_OUTPUT_DIR/$1"
	SAVED_PAIR_OTHER_OUTPUT_PATH=$SAVED_OUTPUT_DIR"/"$1"_output"

	cp "$STDOUT_FILE" "$SAVED_PAIR_OUTPUT_PATH"
	rsync -r -u "$OUT_DIR/output_files/" "$SAVED_PAIR_OTHER_OUTPUT_PATH"
}

# takes in a stage number as an argument so we know where to put the output
# $1 The current stage number
# $2 the stdout copy option (1 means don't save, otherwise save)
# $3 the other output copy option (same as above)
# $4 the benchmarking framework
function copyOutput {
	updateStats $VARFILE $WATCHFILE $2 $3 $4

	if [ "$POST_PROCESSOR_PATH" != "" ]; then
		log "getting postprocessor"
		mkdir $OUT_DIR/postProcessor
		safeCpAll "copying post processor" "$POST_PROCESSOR_PATH" "$OUT_DIR/postProcessor"
		chmod -R gu+rwx $OUT_DIR/postProcessor
		cd "$OUT_DIR"/postProcessor
		log "executing post processor"
		log "time limit: $POST_PROCESSOR_TIME_LIMIT minutes"
		timeout --signal=SIGKILL $((POST_PROCESSOR_TIME_LIMIT))m ./process "$STDOUT_FILE" $LOCAL_BENCH_PATH "$OUT_DIR/output_files" > "$OUT_DIR"/attributes.txt
		if (( $? != 0 )); then
			log "post processor timeout"
			sendStatus "$ERROR_POST_PROCESSOR"
			sendStatusToLaterStages "$ERROR_POST_PROCESSOR" 0
			setRunStatsToZeroForLaterStages 0
			setEndTime
			exit 1
		fi

		log "processing attributes"
		processAttributes $OUT_DIR/attributes.txt $1
	fi

	copyOutputNoStats $1 $2 $3
	log "copying job output complete"
}

#fills arrays from file
function fillDependArrays {
	#separator
	sep=',,,'

	INDEX=0

	log "has depends = $HAS_DEPENDS"

	if ((HAS_DEPENDS == 1)); then
		while read line; do
			BENCH_DEPENDS_ARRAY[INDEX]=${line//$sep*};
			LOCAL_DEPENDS_ARRAY[INDEX]=${line//*$sep};
			((++INDEX))
		done < "$JOB_IN_DIR/depend_$PAIR_ID.txt"
	fi
}

function enablePython34 {
	scl enable rh-python34 bash
}

function setupBenchexecCgroups {
	echo $$ > /sys/fs/cgroup/cpuset/system.slice/benchexec-cgroup.service/tasks
	echo $$ > /sys/fs/cgroup/cpuacct/system.slice/benchexec-cgroup.service/tasks
	echo $$ > /sys/fs/cgroup/memory/system.slice/benchexec-cgroup.service/tasks
	echo $$ > /sys/fs/cgroup/freezer/system.slice/benchexec-cgroup.service/tasks
}

function checkIfBenchmarkDependenciesExists {
	for (( i = 0 ; i < ${#BENCH_DEPENDS_ARRAY[@]} ; i++ )); do
		log "Checking if axiom at location exists: '${BENCH_DEPENDS_ARRAY[i]}'"
		if [ ! -f "${BENCH_DEPENDS_ARRAY[i]}" ]; then
			log "${BENCH_DEPENDS_ARRAY[i]} did not exists, returning 0."
			return 0
		fi
	done
	return 1
}

function copyBenchmarkDependencies {
	if [ "$PRIMARY_PREPROCESSOR_PATH" != "" ]; then
		mkdir $OUT_DIR/preProcessor
		safeCpAll "copying pre processor" "$PRIMARY_PREPROCESSOR_PATH" "$OUT_DIR/preProcessor"
		chmod -R gu+rwx $OUT_DIR/preProcessor
		cd "$OUT_DIR"/preProcessor
	fi

	log "copying benchmark dependencies to execution host..."
	for (( i = 0 ; i < ${#BENCH_DEPENDS_ARRAY[@]} ; i++ )); do
		log "Axiom location = '${BENCH_DEPENDS_ARRAY[i]}'"
		NEW_D=$(dirname "$LOCAL_BENCH_DIR/${LOCAL_DEPENDS_ARRAY[i]}")
		mkdir -p $NEW_D
		if [ "$PRIMARY_PREPROCESSOR_PATH" != "" ]; then
			log "copying benchmark ${BENCH_DEPENDS_ARRAY[i]} to $LOCAL_BENCH_DIR/${LOCAL_DEPENDS_ARRAY[i]} on execution host..."
			"./process" "${BENCH_DEPENDS_ARRAY[i]}" $RAND_SEED > "$LOCAL_BENCH_DIR/${LOCAL_DEPENDS_ARRAY[i]}"
		else
			log "copying benchmark ${BENCH_DEPENDS_ARRAY[i]} to $LOCAL_BENCH_DIR/${LOCAL_DEPENDS_ARRAY[i]} on execution host..."
			cp "${BENCH_DEPENDS_ARRAY[i]}" "$LOCAL_BENCH_DIR/${LOCAL_DEPENDS_ARRAY[i]}"
		fi
	done

	BENCH_INPUT_INDEX=0
	mkdir -p $BENCH_INPUT_DIR

	while ((BENCH_INPUT_INDEX < NUM_BENCH_INPUTS)); do
		CURRENT_BENCH_INPUT_PATH=${BENCH_INPUT_PATHS[BENCH_INPUT_INDEX]}
		cp "$CURRENT_BENCH_INPUT_PATH" "$BENCH_INPUT_DIR/$((BENCH_INPUT_INDEX+1))"
		((++BENCH_INPUT_INDEX))
	done

	log "benchmark dependencies copy complete"
}

function sandboxWorkspace {
	cd $WORKING_DIR

	# First, recursively change the owner of everything *inside* WORKING_DIR to
	# the sandbox user
	if [[ $WORKING_DIR == *sandbox2* ]]; then
		log "sandboxing workspace with second sandbox user"
		sudo chown -R $SANDBOX_USER_TWO $WORKING_DIR
	else
		log "sandboxing workspace with first sandbox user"
		sudo chown -R $SANDBOX_USER_ONE $WORKING_DIR
	fi

	# Then, change the owner of the WORKING_DIR *itself* back to tomcat
	# and change the owner of everything inside the benchmark dir to tomcat
	# but give everybody permission to read (but not write or delete) the benchmark
	sudo chown $(whoami) "$WORKING_DIR"
	chmod a=rx,u+w "$WORKING_DIR"

	sudo chown -R $(whoami) "$LOCAL_BENCH_DIR"
	chmod -R a=rX,u+w "$LOCAL_BENCH_DIR"
}

#will see if a solver is cached and change the SOLVER_PATH to the cache if so
function checkCache {
	if [ -d "$SOLVER_CACHE_PATH" ]; then
		if [ -d "$SOLVER_CACHE_PATH/finished.lock" ]; then
			log "solver exists in cache at $SOLVER_CACHE_PATH"
			SOLVER_PATH=$SOLVER_CACHE_PATH
			SOLVER_CACHED=1
		fi
	fi
}

#this is run after a solver is built on starexec
function copySolverBack {
	NEW_SOLVER_PATH="${SOLVER_PATH/%????/}"

	log "OLD solver path: $SOLVER_PATH"
	log "NEW solver path: $NEW_SOLVER_PATH"

	if [ -e $LOCAL_RUNSOLVER_PATH ]; then
		rm $LOCAL_RUNSOLVER_PATH
	fi

	if [ -e $LOCAL_CONFIG_PATH ]; then
		rm $LOCAL_CONFIG_PATH
	fi

	mkdir $SHARED_DIR/Solvers/buildoutput/$SOLVER_ID
	log "the output to be copied back $PAIR_OUTPUT_DIRECTORY/$PAIR_ID.txt"
	log "the directory copying to: $SHARED_DIR/Solvers/buildoutput/$SOLVER_ID"
	cp "$PAIR_OUTPUT_DIRECTORY/$PAIR_ID.txt" $SHARED_DIR/Solvers/buildoutput/$SOLVER_ID/starexec_build_log

	safeCpAll "copying solver back" "$LOCAL_SOLVER_DIR" "$NEW_SOLVER_PATH"
	log "solver copied back to head node"

	log "updating build status to built and changing path for solver to $NEW_SOLVER_PATH"
	log "set build status to built on starexec for $SOLVER_ID"
	log "deleting build configuration from db for solver: $SOLVER_ID"
	log "removing benchmark bench name: $BENCH_NAME id: $BENCH_ID from the db"
	dbExec "
		CALL SetSolverPath($((SOLVER_ID)), '$(dbEscape $NEW_SOLVER_PATH)');
		CALL SetSolverBuildStatus($((SOLVER_ID)), 2);
		CALL DeleteBuildConfig($((SOLVER_ID)));
		CALL RemoveBenchmarkFromDatabase($((BENCH_ID)));
	"

	rm $BENCH_PATH
}

# For build jobs this cleans up files used in the build script.
function cleanUpAfterKilledBuildJob {
	if [ $BUILD_JOB == "true" ]; then
		log "Build job has been failed, cleaning up:"
		log "deleting build configuration from db for solver: $SOLVER_ID"
		log "removing benchmark bench name: $BENCH_NAME id: $BENCH_ID from the db"
		dbExec "
			CALL SetSolverBuildStatus($((SOLVER_ID)), 3);
			CALL DeleteBuildConfig($((SOLVER_ID)));
			CALL RemoveBenchmarkFromDatabase($((BENCH_ID)));
		"

		BENCH_PATH_DIR=$(dirname $BENCH_PATH)
		log "Deleting benchmark directory: $BENCH_PATH_DIR"
		safeRm $BENCH_PATH_DIR
		rm $BENCH_PATH
	fi
}

function copyDependencies {
	safeCpAll "copying solver" "$SOLVER_PATH" "$LOCAL_SOLVER_DIR"
	log "solver copy complete"
	if ((SOLVER_CACHED == 0)) && [[ $BUILD_JOB != "true" ]]; then
		mkdir -p "$SOLVER_CACHE_PATH"
		if mkdir "$SOLVER_CACHE_PATH/lock.lock" ; then
			if [ ! -d "$SOLVER_CACHE_PATH/finished.lock" ]; then
				#store solver in a cache
				#if the copy was successful
				if safeCpAll "storing solver in cache" "$LOCAL_SOLVER_DIR" "$SOLVER_CACHE_PATH" ; then
					log "the solver was successfully copied into the cache"
					mkdir "$SOLVER_CACHE_PATH/finished.lock"
					rm -r "$SOLVER_CACHE_PATH/lock.lock"
				else
					#if we failed to copy the solver, remove the cache entry for the solver
					log "the solver could not be copied into the cache successfully"
					rm -r "$SOLVER_CACHE_PATH"
				fi
			fi
		fi
	fi

	log "chmod gu+rwx on the solver directory on the execution host ($LOCAL_SOLVER_DIR)"
	chmod -R gu+rwx $LOCAL_SOLVER_DIR

	log "copying runSolver to execution host..."
	cp "$RUNSOLVER_PATH" "$LOCAL_RUNSOLVER_PATH"

	log "runsolver copy complete"
	ls -l "$LOCAL_RUNSOLVER_PATH"

	log "copying benchmark $BENCH_PATH to $LOCAL_BENCH_PATH on execution host..."
	cp "$BENCH_PATH" "$LOCAL_BENCH_PATH"

	log "benchmark copy complete"

	#doing benchmark preprocessing here if the pre_processor actually exists
	if [ "$PRE_PROCESSOR_PATH" != "" ]; then
		mkdir -p $OUT_DIR/preProcessor
		safeCpAll "copying preProcessor" "$PRE_PROCESSOR_PATH" $OUT_DIR/preProcessor
		chmod -R gu+rwx $OUT_DIR/preProcessor
		cd "$OUT_DIR"/preProcessor
		log "executing pre processor"
		log "random seed = $RAND_SEED"
		log "time limit: $PRE_PROCESSOR_TIME_LIMIT"

		timeout --signal=SIGKILL $((PRE_PROCESSOR_TIME_LIMIT))m ./process "$LOCAL_BENCH_PATH" $RAND_SEED > "$PROCESSED_BENCH_PATH"
		if (( $? != 0 )); then
			log "pre processor timeout"
			sendStatus "$ERROR_PRE_PROCESSOR"
			sendStatusToLaterStages "$ERROR_PRE_PROCESSOR" 0
			setRunStatsToZeroForLaterStages 0
			setEndTime
			exit 1
		fi

		#use the processed benchmark in subsequent steps
		rm "$LOCAL_BENCH_PATH"
		mv "$PROCESSED_BENCH_PATH" "$LOCAL_BENCH_PATH"
	fi
}

# Saves a file as a benchmark on Starexec
# $1 The path to the file to save
# $2 1 or 2. Whether to use the pair's benchmark name for the new benchmark name. If 2,
# uses the name of the given file
function saveFileAsBenchmark {
	CURRENT_OUTPUT_FILE=$1
	BENCH_NAME_ADDON="stage-"
	FILE_NAME=$BENCH_NAME
	if (($2 == 2)); then
		FILE_NAME=$(basename $1)
	fi
	# if no suffix is given, we just use the suffix of the benchmark
	if [ "$CURRENT_BENCH_SUFFIX" == "" ] ; then
		if [[ "$FILE_NAME" = *.* ]] ; then
			CURRENT_BENCH_SUFFIX=".${FILE_NAME##*.}"
		fi
	fi

	CURRENT_BENCH_NAME=${FILE_NAME%%.*}$BENCH_NAME_ADDON$CURRENT_STAGE_NUMBER
	((MAX_BENCH_NAME_LENGTH = BENCH_NAME_LENGTH_LIMIT - ${#CURRENT_BENCH_SUFFIX}))
	CURRENT_BENCH_NAME=${CURRENT_BENCH_NAME:0:$MAX_BENCH_NAME_LENGTH}
	CURRENT_BENCH_NAME="$CURRENT_BENCH_NAME$CURRENT_BENCH_SUFFIX"
	CURRENT_BENCH_PATH=$BENCH_SAVE_DIR/$SPACE_PATH/$PAIR_ID/$CURRENT_STAGE_NUMBER
	log "saving benchmark to dir: $CURRENT_BENCH_PATH"

	FILE_SIZE_IN_BYTES=$(wc -c < $CURRENT_OUTPUT_FILE)

	createDir $CURRENT_BENCH_PATH

	CURRENT_BENCH_PATH=$CURRENT_BENCH_PATH/$CURRENT_BENCH_NAME

	QUERY="CALL AddAndAssociateBenchmark('$(dbEscape $CURRENT_BENCH_NAME)', '$(dbEscape $CURRENT_BENCH_PATH)', false, $((USER_ID)), 1, $((FILE_SIZE_IN_BYTES)), $((SPACE_ID)), @id)"
	log "Adding benchmark using query: $QUERY"
	if ! (dbExec "$QUERY") ; then
		log "error saving output as benchmark-- benchmark was not created"
	else
		cp $CURRENT_OUTPUT_FILE "$CURRENT_BENCH_PATH"
		log "benchmark $CURRENT_BENCH_NAME copied to $CURRENT_BENCH_PATH"
	fi
}

# sets the variable REMAINING_DISK_QUOTA with the number of bytes the user should be allowed
# to write. This includes a 1G buffer for going over their quota
function setRemainingDiskQuota {
	DISK_USAGE=$(mysql -u"$DB_USER" -p"$DB_PASS" -h $REPORT_HOST $DB_NAME -N -e "CALL GetUserDiskUsage($((USER_ID)))")
	log "user disk usage is $DISK_USAGE"
	((REMAINING_DISK_QUOTA = DISK_QUOTA - DISK_USAGE + 1073741824))
	log "remaining user disk quota: $REMAINING_DISK_QUOTA"
	if ((REMAINING_DISK_QUOTA < 0)); then
		REMAINING_DISK_QUOTA=0
	fi
}

# Sets the DISK_QUOTA_EXCEEDED variable to 1 if the user is over their quota.
# Option to copy back stdout
# Option to copy back other output files
function setDiskQuotaExceeded {
	if ((DISK_QUOTA_EXCEEDED == 1)); then
		return
	fi
	getTotalOutputSizeToCopy $1 $2
	setRemainingDiskQuota
	if ((DISK_SIZE > REMAINING_DISK_QUOTA)); then
		DISK_QUOTA_EXCEEDED=1
		# we may have already copied some data, so we want to delete that
		safeRm $PAIR_OUTPUT_DIRECTORY
	fi
}

# Gets the size, in bytes, of all the output we are copying back to the head node. If DISK_QUOTA_EXCEEDED
# is already set, this will simply set DISK_QUOTA to 0, as we won't be copying anything
# $1 The argument for whether we are copying back the stdout (1 = no copy, 2 = copy, 3 = copy + benchmark)
# $2 The argument for whether we are copying back the other output files
function getTotalOutputSizeToCopy {
	if ((DISK_QUOTA_EXCEEDED == 1)); then
		DISK_SIZE=0
		return
	fi
	STDOUT_SIZE=0
	OTHER_SIZE=0
	if (($1 != 1)); then
		STDOUT_SIZE=$(wc -c < "$STDOUT_FILE")
	fi

	if (($1 == 3)); then
		# user is requesting two copies
		((STDOUT_SIZE = STDOUT_SIZE * 2))
	fi
	log "found the following stdout size: $STDOUT_SIZE"

	if (($2 != 1)); then
		OTHER_SIZE=$(du -sb "$OUT_DIR/output_files" | awk '{print $1}')
	fi

	if (($2 == 3)); then
		# user is requesting two copies
		((OTHER_SIZE = OTHER_SIZE * 2))
	fi
	log "found the following other files size: $OTHER_SIZE"
	((DISK_SIZE = OTHER_SIZE + STDOUT_SIZE))
	log "returning the following disk size: $DISK_SIZE"
}

# Saves the current stdout as a new benchmark
function saveStdoutAsBenchmark {
	if ((DISK_QUOTA_EXCEEDED == 1)); then
		log "not saving new benchmark: user disk quota has been exceeded"
		return
	fi
	log "saving output as benchmark for stage $CURRENT_STAGE_NUMBER"
	saveFileAsBenchmark $SAVED_OUTPUT_DIR/$CURRENT_STAGE_NUMBER 1
}

# Saves the extra output directory as a new set of benchmarks
function saveExtraOutputAsBenchmarks {
	if ((DISK_QUOTA_EXCEEDED == 1)); then
		log "not saving new benchmarks: user disk quota has been exceeded"
		return
	fi
	OUTPUT_DIR=$SAVED_OUTPUT_DIR"/"$CURRENT_STAGE_NUMBER"_output/*"
	for f in $OUTPUT_DIR; do
		if [ -f $f ]
		then
			saveFileAsBenchmark $f 2
		fi
	done
}

#benchmark dependencies not currently verified.
function verifyWorkspace {
	# Make sure the configuration exists before we execute it
	if ! [ -x "$LOCAL_CONFIG_PATH" ]; then
		log "job error: could not locate the configuration script '$CONFIG_NAME' on the execution host"
		#get rid of the cache, as if we're here then something is probably wrong with it
		rm -r "$SOLVER_CACHE_PATH"
		sendStatus $ERROR_RUNSCRIPT
	else
		log "execution host solver configuration verified"
	fi

	# Make sure the benchmark exists before the job runs
	if ! [ -r "$LOCAL_BENCH_PATH" ]; then
		log "job error: could not locate the readable benchmark '$BENCH_NAME' on the execution host."
		sendStatus $ERROR_BENCHMARK
	else
		log "execution host benchmark verified"
	fi
}

# Marks this pair as having had a runscript error
# $1 The current stage number
function markRunscriptError {
	local STAGE=$(($1-1))
	dbExec "CALL RunscriptError('$HOSTNAME', $PAIR_ID, $STAGE)"
}

# this function checks to make sure that runsolver output was generated correctly.
# runsolver output should have a terminating line that contains 'EOF'. If this is not present,
# output was cut off for some reason and we should mark the pair as invalid
# returns 0 if valid and 1 if invalid
# $1 Output file to check
# $2 The current stage number
# $3 The SUPPRESS_TIMESTAMP param. If this is true, we cannot check for EOF, as it does not exist
# $4 The benchmarking framework
function isOutputValid {
	log "checking to see if runsolver output is valid for stage $2"
	if [ ! -f $1 ]; then
		log "Runsolver output could not be found"
		markRunscriptError $2
		return 1
	fi

	if [ "$4" = "$BENCHEXEC" ] ; then
		log "benchmarking framework was benchexec so there will be no EOF appended."
		return 0
	fi

	if [ "$3" = true ] ; then
		log "no EOF line was appended, so we cannot check for it"
		return 0
	fi

	if [[ $(tail -n 1 $1) == *"EOF"* ]]; then
		log "Runsolver output was valid"
		return 0
	else
		log "Runsolver output was NOT valid"
		return 1
	fi
}

function exitJobscript {
	echo "Jobscript ending."
}
