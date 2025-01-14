#!/usr/bin/env bash

set -e

avx2=0
n=
t=
x=
y=
z=
while getopts "h?2n:t:x:y:z:" opt; do
    case "$opt" in
        h|\?)
            echo "run_hpcg.sh parameters"
            echo ""
            echo "-2 use avx2"
            echo "-n [n]"
            echo "-t [time to run]"
            echo "-x [nx]"
            echo "-y [ny]"
            echo "-z [nz]"
            echo ""
            exit 1
            ;;
        2)
            avx2=1
            ;;
        n)
            n=$OPTARG
            ;;
        t)
            t=$OPTARG
            ;;
        x)
            x=$OPTARG
            ;;
        y)
            y=$OPTARG
            ;;
        z)
            z=$OPTARG
            ;;
    esac
done
shift $((OPTIND-1))
[ "$1" = "--" ] && shift

if [ ! -z $x ] && [ ! -z $y ] && [ ! -z $z ]; then
    n="--nx=$x --ny=$y --nz=$z"
else
    if [ -z $n ]; then
        echo "n must be specified if not all of x, y, z are supplied"
        exit 1
    fi
    n="--n=$n"
fi

if [ ! -z $t ]; then
    t="--t=$t"
fi

bin=
if [ $avx2 -eq 0 ]; then
    bin=xhpcg_avx
else
    bin=xhpcg_avx2
fi

echo n: $n
echo t: $t
echo bin: $bin

# get nodes and compute number of processors
IFS=',' read -ra HOSTS <<< "$AZ_BATCH_HOST_LIST"
ppn=$(nproc)
nodes=${#HOSTS[@]}
echo num nodes: $nodes
echo ppn: $ppn

# source intel mpi vars script
export MANPATH=$MATHPATH:/usr/local/man
source /opt/intel/compilers_and_libraries/linux/mpi/bin64/mpivars.sh

# export env vars
export I_MPI_ADJUST_ALLREDUCE=5
export OMP_NUM_THREADS=$ppn

# execute benchmark
echo executing benchmark. please see hpcg_log_*.txt for output and the accompanying yaml file.
hpcg_dir=/intel/mkl/benchmarks/hpcg/bin
cmd=$(eval echo "${SHIPYARD_SINGULARITY_COMMAND}")
echo "Singularity command: $cmd"
# need to re-source mpivars inside singularity env since the compilervars
# script mangles the mpi lib search
mpirun -hosts $AZ_BATCH_HOST_LIST -perhost 1 -np $nodes \
    $cmd /bin/bash -c "source /intel/bin/compilervars.sh intel64; \
        source /opt/intel/compilers_and_libraries/linux/mpi/bin64/mpivars.sh; \
        ${hpcg_dir}/${bin} $n $t"
