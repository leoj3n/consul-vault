#!/usr/bin/env bash

PROGNAME=$(basename $0)

function usage {
    echo "usage: $PROGNAME [-n NAMESPACE] [-m MAX-PODS] -s SERVICE -- COMMAND"
    echo "  -s SERVICE   K8s service, i.e. a pod selector (required)"
    echo "     COMMAND   Command to execute on the pods"
    echo "  -n NAMESPACE K8s namespace (optional)"
    echo "  -m MAX-PODS  Max number of pods to run on (optional; default=all)"
    echo "  -q           Quiet mode"
    echo "  -d           Dry run (don't actually exec)"
}

function header {
    if [ -z $QUIET ]; then
        >&2 echo "###"
        >&2 echo "### $PROGNAME $*"
        >&2 echo "###"
    fi
}

while getopts :n:s:m:qdc opt; do
    case $opt in
        d)
            DRYRUN=true
            ;;
        q)
            QUIET=true
            ;;
        m)
            MAX_PODS=$OPTARG
            ;;
        c)
            FILECOPY=true
            ;;
        n)
            NAMESPACE="-n $OPTARG"
            NAME_SPACE=$OPTARG
            ;;
        s)
            SERVICE=$OPTARG
            ;;
        \?)
            usage
            exit 0
            ;;
    esac
done

if [ -z $SERVICE ]; then
    usage
    exit 1
fi

shift $(expr $OPTIND - 1)

while test "$#" -gt 0; do
    if [ "$REST" == "" ]; then
        REST="$1"
    else
        REST="$REST $1"
    fi

    shift
done

if [ "$REST" == "" ]; then
    usage
    exit 1
fi

PODS=()

for pod in $(kubectl $NAMESPACE get pods --output=jsonpath={.items..metadata.name}); do
    echo $pod | grep -qe "^$SERVICE" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        PODS+=($pod)
    fi
done

if [ ${#PODS[@]} -eq 0 ]; then
    echo "service not found in ${NAMESPACE:-default}: $SERVICE"
    exit 1
fi

if [ ! -z $MAX_PODS ]; then
    PODS=("${PODS[@]:1:$MAX_PODS}")
fi

COPY=''

if [ ! -z $FILECOPY ]; then
  REST=($REST)
  header "{pods: ${#PODS[@]}, command: \"kubectl $NAMESPACE cp ${REST[0]} ${NAME_SPACE}/<name>:${REST[1]}\"}"
else
  header "{pods: ${#PODS[@]}, command: \"${REST}\"}"
fi


for i in "${!PODS[@]}"; do
    pod=${PODS[$i]}
    header "{pod: \"$(($i + 1))/${#PODS[@]}\", name: \"$pod\"}"

    if [ "$DRYRUN" != "true" ]; then
      if [ "$FILECOPY" == "true" ]; then
        kubectl $NAMESPACE cp ${REST[0]} ${NAME_SPACE}/${pod}:${REST[1]}
      else
        kubectl $NAMESPACE exec $pod -- $REST
      fi
    fi
done
