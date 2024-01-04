#!/bin/bash

set -x

interrupt_handler() {
  exit 1
}
trap interrupt_handler SIGINT

function cloud_cpu_id() {
	num_threads=$1
	num_iters=$2
	start_index=$(($num_threads*2*$num_iters))
	iterations=$(($start_index+$num_threads*2))

	cpu_index="$start_index"

	for ((i=start_index+2; i<iterations; i+=2)); do
		cpu_index+=",$i"
	done
	echo $cpu_index
}

############# PATH configuration #############
current_dir=$(pwd)
workspace_dir=$(echo $current_dir | sed 's|\(.*\/xFasterTransformer\).*|\1|')
build_dir=$(echo $workspace_dir/build)

# change the workspace status
if [ ! -d $build_dir ]; then
    echo "[Error] please build project in $build_dir"
    exit 1
fi

logs_dir=$(echo $current_dir/logs_erdma/`date "+%Y-%m-%d-%H-%M-%S"`)
mkdir -p $logs_dir

############# HW configuration #############
IFACE=eth1
IP_A=172.31.0.104
IP_B=172.31.0.106
IP_C=172.31.0.100
IP_D=172.31.0.102

# enable it if testing at a cloud environment
export is_ali_cloud=1

# sync manual
# scp -r $workspace_dir/* $IP_B:$workspace_dir/

# set OpenMP lib.
export LD_PRELOAD=$workspace_dir/3rdparty/mklml/lib/libiomp5.so

# todo(marvin): enable HBM flat
enable_hbm=0

# enable log https://www.intel.com/content/www/us/en/docs/mpi-library/developer-reference-linux/2021-11/other-environment-variables.html#GUID-8357A7B3-5494-48AF-AA32-CAA4A778D195
# I_MPI_DEBUG=1
# FI_LOG_LEVEL=debug

# enable TCP
# export FI_TCP_IFACE=eth0
# export I_MPI_OFI_PROVIDER="tcp;ofi_rxm"

# enable eRDMA
export FI_VERBS_IFACE=eth1
export FI_PROVIDER="verbs;ofi_rxm"
export FI_OFI_RXM_USE_SRX=0
export FI_VERBS_RX_IOV_LIMIT=1

# export FI_OFI_RXM_BUFFER_SIZE=32768

############# OneCCL configuration #############
# export CCL_ALLREDUCE=recursive_doubling
export CCL_ALLREDUCE="recursive_doubling:0-16384;2d:16385-524288;nreduce:524289-max"

export CCL_PROCESS_LAUNCHER=none

export CCL_WORKER_COUNT=1

#for 48 core * 2
#set CCL_WORKER_AFFINITY if necessary
export CCL_WORKER_AFFINITY=95

############# XFT configuration #############
BENCHMARK=$build_dir/example
export XFT_ONECCL=1
#export XFT_ONECCL_BF16=1
export XFT_COMM_TIME=0
export XFT_FAKE_MODEL=0
export XFT_TIMELINE=0

# open for MPI debug information
# MPI_DEBUG="-prot -verbose -print-rank-map -print-all-exitcodes -outfile-pattern=run_output_std.log -errfile-pattern=run_output_err.log"

############# BENCHMARK configuration #############
export OMP_NUM_THREADS=48
export LD_LIBRARY_PATH=`pwd`/../../build:$LD_LIBRARY_PATH

mpirun -iface=${IFACE} $MPI_DEBUG \
    -n 1 -hosts ${IP_A} numactl -C `cloud_cpu_id 48 0` -m 0 python Qwen.py --token_path=/mnt/data/Qwen-72B-Chat --model_path=/mnt/data/Qwen-72B-Chat-xft --dtype=bf16_fp16 : \
    -n 1 -hosts ${IP_B} numactl -C `cloud_cpu_id 48 0` -m 0 python Qwen.py --token_path=/mnt/data/Qwen-72B-Chat --model_path=/mnt/data/Qwen-72B-Chat-xft --dtype=bf16_fp16 : \
    -n 1 -hosts ${IP_C} numactl -C `cloud_cpu_id 48 0` -m 0 python Qwen.py --token_path=/mnt/data/Qwen-72B-Chat --model_path=/mnt/data/Qwen-72B-Chat-xft --dtype=bf16_fp16 : \
    -n 1 -hosts ${IP_D} numactl -C `cloud_cpu_id 48 0` -m 0 python Qwen.py --token_path=/mnt/data/Qwen-72B-Chat --model_path=/mnt/data/Qwen-72B-Chat-xft --dtype=bf16_fp16

# numactl -C `cloud_cpu_id 48 0` -m 0 python Qwen.py --token_path=/mnt/data/Qwen-72B-Chat --model_path=/mnt/data/Qwen-72B-Chat-xft --dtype=bf16_fp16