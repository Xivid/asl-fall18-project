#!/usr/bin/env bash
# test the limit of one server using 3 load generating (memtier) machines
# usage: ./exp2.1write.sh [test time] [repetitions] [nopop]

if [ -z "${VM_NAME}" ]; then
    echo "Variable VM_NAME not set!"
    exit
fi

logfile="exp2.1write_${VM_NAME}.log"

echo "Logging running info to ${logfile}"
[ -e ${logfile} ] && rm ${logfile}

echolog() {
    echo `date +%Y-%m-%d\ %H:%M:%S` $@ | tee -a ${logfile}
}


if [[ ${VM_NAME} == server* ]]; then
    echolog "This is a memcached machine. This script is not for it."
    exit
fi

if [[ ${VM_NAME} == mw* ]]; then
    type="middleware"
else
    type="memtier"
fi
echolog "Running on ${VM_NAME}. This is a ${type} machine."
echolog


if [ -z $1 ]; then
    time="80"
else
    time=$1
fi

if [ -z $2 ]; then
    repetitions="3"
else
    repetitions=$2
fi

cmdpart="memtier_benchmark --port=11211 --protocol=memcache_text --expiry-range=99999-100000 --key-maximum=10000 --data-size=4096"
fnamepart="../logs/2.1"
clients=(1 4 8 12 16 20 24 28 32 36 40 44 48)

# pre-populate the memcached servers
echolog "# ASL section 2.1 experiments"
echolog "Run each experiment with ${time} seconds and ${repetitions} repetitions"
if [[ $3 != "nopop" ]]; then
    echolog "Populating server: server1"
    ./prepopulate.sh 30 server1
    echolog
fi

# run ping once before experiments
cmd="ping server1 > ${fnamepart}/ping_${VM_NAME}_to_server1.log & "
echolog ${cmd}
eval ${cmd}
pidping=$!
sleep 30
echolog "killing ping"
kill -2 ${pidping}

# writeonly workloads
echolog "# Writeonly workloads"
for c in "${clients[@]}"; do
    for r in `seq 1 ${repetitions}`; do
        echolog "================================================================="
        echolog "Test with CT = 2, VC = $c, repetition $r begin"
        echolog "-----------------------------------------------------------------"
        dir="${fnamepart}/writeonly/vc${c}/r${r}"
        mkdir -p ${dir}
        # run dstat
        cmd="dstat -tcnm --output ${dir}/dstat_${VM_NAME}.csv > ${dir}/dstat_${VM_NAME}.log & "
        echolog ${cmd}
        eval ${cmd}
        piddstat=$!
        # run memtier
        cmd="${cmdpart} --ratio=1:0 --server=server1 --test-time=${time} --clients=${c} --threads=2 > ${dir}/${VM_NAME}0.log 2>&1 &"
        echolog ${cmd}
        eval ${cmd}
        pidmemtier=$!
        echolog "Waiting for $((time+10)) secs for test to fully stop..."
        sleep $((time+10))
        echolog "Kill memtier and dstat (if exist)"
        kill ${pidmemtier}  # if memtier didn't stop, force kill it
        kill ${piddstat}
        echolog "-----------------------------------------------------------------"
        echolog "Test with CT = 2, VC = $c, repetition $r end"
        echolog "================================================================="
        echolog
        echolog
    done
done
