#!/bin/bash
set -x

# usage
##########################################################################################
#./runQueryOnGCPLogs.sh -t filter-interval.gcp-ql -f filter-simple.gcp-ql -d 1675b11d
print_usage() {
  echo " Help for $0 : (aka trying to be fancy)"
  echo ""
  echo " This script retrieves the GCP logs , it needs or accepts "
  echo "   - dbid "
  echo "   - a TIME filter file (needs editing)"
  echo "   - a LIBRARY filter (aka pre-built / half baked). These live within ./lib and are meant to be generic templates"
  echo "   - a custom inline filter (aka you know what you're doing) - [Experimental] - Not tested "
  echo ""
  echo "USAGE:"
  echo " $0 [-d dbid] [-t filter-time-filename] [-f main filter-from-library] [-c \"custom GCP query logs to be appended\" [-p GCP-project-name]"
  echo ""
  echo "           NOTE: -d is optional but HIGHLY recommended. It could also be set in a filter file. Not enforced in any way"
  echo "           NOTE: -t is optional. if not specified you would want the values to be in either the custom query or the library filter. Not enforced"
  echo "           NOTE: -f is optional . Not specifying one would mean you could just get a sample of logs"
  echo ""
  echo "EXAMPLE:"
  echo "          $0 -t filter-interval.gcp-ql -f filter-simple.gcp-ql -d 1675b11d"
  echo ""
  echo " Will retrieve all logs for database dbid=1675b11d between time interval defined in the filter-interval.gcp-ql AND the pre-defined library filter filter-simple.gcp-ql"
  echo ""
}
##########################################################################################
LOGFILE="./log/$0_$(date  +%Y%m%d).log"
TIMESTAMP=`date +%Y%m%d-%H%M%S`


# Parse arguments
PARAMS=""
while (( "$#" )); do
  case "$1" in
    -h|--help|-help)
      HARG="HELP"
      break
      ;;
    -f|--filter)
      FARG=$2
      shift 2
      ;;
    -t|--time)
      TARG=$2
      shift 2
      ;;
    -d|--dbid)
      DARG=$2
      shift 2
      ;;
    -c|--custom)
      CARG=$2
      shift 2
      ;;
    -p|--project)
      PARG=$2
      shift 2
      ;;
    --) # end argument parsing
      shift
      break
      ;;
    -*|--*=) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      exit 1
      ;;
    *) # preserve positional arguments
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done

if [ "$HARG" == "HELP" ] ; then
    print_usage
fi
##########################################################################################
# Notes
# check files exists and error properly
# output to file
# set/change the time filter file to that temp file
#tfile=$(mktemp /tmp/gcp-filter.XXXXXXXXX)
#echo "The temp file : $tfile"

# DBID filter - Most if not all Queries are about a database 
# this is not made mandatory because we also want to retrieve logs that are more related to platform or infrastructure
#DBID_FILTER="jsonPayload.dbid = \"b2f680\""
DBID="all-dbid"    # Initialised here just becasue we use this to dump the full GCP query 
if [ -z "$DARG" ] ; then
    DBID_FILTER=""
    echo "WARNING: No dbid specified...this could lead to a very large result." >> $LOGFILE
    read -p "WARNING: No dbid specified...this could lead to a very large result. Continue? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
    echo "We tried to stop you making a bad choice..." >> $LOGFILE
else
    DBID="${DARG}"
    #DBID_FILTER="jsonPayload.dbid = \"${DARG}\""
    DBID_FILTER="( jsonPayload.dbid=\"${DARG}\" OR labels.\"k8s-pod/dbid\"=\"${DARG}\" )"    
fi

# Time interval  for the query.
# Given it is always changing and the format is a real P.I.T.A it's easier in an input file than straight in command line
# Ideally we should be able to use a few magic words : 
# Example: now, yesterday or provide a timesatmp + magic word and duration (before, around, after) and duration in minutes/seconds 
#TIME_INTERVAL_FILTER="filter-interval.gcp-ql"
if [ -z "$TARG" ] ; then
    TIME_INTERVAL_FILTER=""
    echo "WARNING: No time range specified...this could lead to a very large result." >> $LOGFILE
    read -p "WARNING: No time range specified...this could lead to a very large result. Continue? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
    echo "We tried to stop you making a bad choice..." >> $LOGFILE
else
    TIME_INTERVAL_FILTER=${TARG}
    if [ -f "$TIME_INTERVAL_FILTER" ]; then
        TIME_INTERVAL_FILTER=${TARG}
    else
        echo "Could not find filter file $TIME_INTERVAL_FILTER. Exiting now" >> $LOGFILE
        return 1
    fi
fi

# The aim is to be consistent with the base query filter
# the filters are located under ./lib but specifying ./lib is not required (in fact you mustn't)
#MAIN_FILTER_FILE="./lib/filter-BloomQueries.gcp-ql"
if [ -z "$FARG" ] ; then
    MAIN_FILTER_FILE=""
else
    MAIN_FILTER_FILE="./lib/${FARG}"    
    if [ -f "$TIME_INTERVAL_FILTER" ]; then
        MAIN_FILTER_FILE="./lib/${FARG}"
    else
        echo "Could not find filter file $MAIN_FILTER_FILE. Exiting now" >> $LOGFILE
        return 1
    fi
fi

PROJECT_DEF="neo4j-cloud"    # Initialised here just because we use this to dump the full GCP query 
if [ -z "$PARG" ] ; then
    PROJECT=$PROJECT_DEF
    echo "Using default for PROJECT: $PROJECT" >> "$LOGFILE"
else
    PROJECT="${PARG}"
    # echo "Setting custom PROJECT: $PROJECT" >> "$LOGFILE"
fi

echo "Project is set to: $PROJECT"

# after all the filtering criteria have bee specified : time interval, dbid, library filter : merge it all 
# MERGE The filters to 1 line to pass to the command
GCP_FILTER_QUERY=`cat ${TIME_INTERVAL_FILTER} ${MAIN_FILTER_FILE} | sed -e "s/GCP_LOG_PROJECT/${PROJECT}/g" | sed '/^[[:space:]]*$/d' | tr '\n' ' ' `

# Now Checking for custom filter.
# Custom filter is just a way to have a specific filters to be added, just for future proofing 
if [ -z "$CARG" ] ; then
    CUSTOM_FILTER=""
    echo "No custom filter" >> $LOGFILE
else
    CUSTOM_FILTER="${CARG}"
    echo "Adding custom filter: $CUSTOM_FILTER" >> $LOGFILE
    GCP_FILTER_QUERY="${GCP_FILTER_QUERY} ${CUSTOM_FILTER}"
fi

# Run query: ideally we should log (for debug) and traceability 
BASE_FILENAME="${DBID}-${TIMESTAMP}"
DESTDIR="./data/${DBID}/${TIMESTAMP}"

echo "Running query: $DBID_FILTER $GCP_FILTER_QUERY " >> "$LOGFILE"
echo "${DBID_FILTER} ${GCP_FILTER_QUERY}" > "${BASE_FILENAME}.gcp-ql"


################gcloud --project "neo4j-cloud/logs/neo4j-query" logging read --format=json "${DBID_FILTER} ${GCP_FILTER_QUERY}" > "${BASE_FILENAME}.json"
gcloud --project "${PROJECT}" logging read --format="csv[separator=', '](timestamp,jsonPayload.message)" "${DBID_FILTER} ${GCP_FILTER_QUERY}" > "${BASE_FILENAME}.json"
# manage output
mkdir -p $DESTDIR
mv *.json ${DESTDIR}/
echo "Logs captured by filter stored in $DESTDIR"
