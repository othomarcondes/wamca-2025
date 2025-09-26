#!/bin/bash
#SBATCH --nodes=1
#SBATCH --time=12:00:00
#SBATCH --output=./%x_%J/%J.out
#SBATCH --error=./%x_%J/%J.err

# Usage: sbatch --job-name=OP lu_factor.slurm RASTRO(1|0) MPI(nmad|openmpi)
# where OP is one of nmad_times, nmad_traces, openmpi_times, openmpi_traces

# RASTRO (0 | 1)
RASTRO=$1
# MPI (nmad | openmpi)
MPI=$2

# fail on error
# https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
set -euxo pipefail

KEY=${SLURM_JOB_NAME}_${SLURM_JOB_ID}

# GUIX (https://guix.gnu.org/cookbook/en/html_node/Setting-Up-Compute-Nodes.html)
GUIX_DAEMON_SOCKET="guix://192.168.30.23"
export GUIX_DAEMON_SOCKET
GUIX_LOCPATH=/var/guix/profiles/per-user/root/guix-profile/lib/locale
export GUIX_LOCPATH
for GUIX_PROFILE in "$HOME/.config/guix/current"
do
  if [ -f "$GUIX_PROFILE/etc/profile" ]; then
    . "$GUIX_PROFILE/etc/profile"
  fi
done
#GUIX end

#hostname

# Install requirements (usually done before)
GUIX_MANIFEST="${KEY}/${KEY}_chameleon.scm"

if [ "$MPI" = "nmad" ]; then
cat <<EOF > $GUIX_MANIFEST
	(use-modules (guix transformations)
		     (inria storm)
		     (ufrgs ufrgs)
		     (guix-hpc packages solverstack)
		     (gnu packages pretty-print)
		     (guix packages))

	(define transform1
	  (options->transformation
	    '((with-commit . "nmad=6e1a64d0")
	      (with-commit . "pioman=6e1a64d0")
	      (with-commit . "padicotm=6e1a64d0")
	      (with-commit . "puk=6e1a64d0")
	      (with-input . "starpu=starpu-fxt")
	      (with-input . "openmpi=nmad"))))

	(packages->manifest
	  (list (transform1 (specification->package "guix"))
		(transform1 (specification->package "nmad"))
		(transform1
		  (specification->package "gcc-toolchain"))
		(transform1 (specification->package "chameleon@1.3.0"))
		(transform1 (specification->package "starpu-fxt"))
		(transform1 (specification->package "pageng"))))

EOF
elif [ "$MPI" = "openmpi" ]; then
cat <<EOF > $GUIX_MANIFEST
	(use-modules (guix transformations)
		     (inria storm)
		     (ufrgs ufrgs)
		     (guix-hpc packages solverstack)
		     (gnu packages pretty-print)
		     (guix packages))

	(packages->manifest
	  (list (specification->package "chameleon@1.3.0")
		(specification->package "starpu-fxt")
		(specification->package "openmpi@4")
		(specification->package "gcc-toolchain@14")
		(specification->package "pageng")))
EOF
fi

set +u
eval "$(guix shell -m ${GUIX_MANIFEST} --search-paths)"
set -u

# Create the hostfile
HOSTFILE="${KEY}/${SLURM_JOB_ID}.nodes"
srun -n 1 -l hostname | sort -n | awk '{print $2}' > $HOSTFILE

unset "${!STARPU@}"

# Read experiments and execute
CSV_FILE="teste_experimental_project.csv"
OUTPUT_DIR=${KEY}/output_${KEY}
mkdir -p ${OUTPUT_DIR} 

rsync ${CSV_FILE} ./${KEY}/ 

# Set FxT (traces) variables based on MPI Implementation

OPENMPI_PARAMETERS=""
# This is necessary to avoid sbatch + mpirun problems
if [ "$MPI" = "openmpi" ]; then
    OPENMPI_PARAMETERS="--mca pml ob1 --mca btl ^ofi --mca plm rsh --mca oob_tcp_if_include eno2 --mca btl_tcp_if_include eno2 --bind-to none" 
    export OMPI_MCA_plm=isolated
    srun -l hostname | sort -n | awk '{print $2}' | sed 's/$/ slots=1/' > $HOSTFILE
fi

# Control experimental parameters
for machine in $(cat $HOSTFILE | cut -d" " -f1); do
    ssh $machine 'echo 0 | tee /sys/devices/system/cpu/cpufreq/boost'
    ssh $machine 'for i in $(seq 0 $(( $(nproc) - 1 ))); do maxf=$(cat /sys/devices/system/cpu/cpu$i/cpufreq/cpuinfo_max_freq); cpufreq-set -c $i -g performance -d $maxf -u $maxf; done'
    # TODO: disable HT cores
#    ssh $machine 'for i in $(seq 24 47); do echo 0 > /sys/devices/system/cpu/cpu${i}/online; done'
done

# Skip header and read the rest
tail -n +2 "$CSV_FILE" | while IFS=',' read -r size block_size scheduler pq exp order; do
    # Define env vars
    mkdir -p ./${OUTPUT_DIR}/$order
    p=$(echo "$pq" | cut -d'x' -f1)

    if [ "$RASTRO" = 1 ]; then
	export STARPU_FXT_TRACE=1
    fi
    
    if [[ $(hostname) == cei* ]]; then
	    export STARPU_NCPU=22
	    export STARPU_WORKERS_CPUID="2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23"
# POTIS TEM E-CORES e P-CORES
    elif  [[ $(hostname) == poti* ]]; then
	    export STARPU_NCPU=
	    export STARPU_WORKERS_CPUID=""
    elif  [[ $(hostname) == hype* ]]; then
	    export STARPU_NCPU=18
	    export STARPU_WORKERS_CPUID="2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19"
    elif  [[ $(hostname) == draco* ]]; then
	    export STARPU_NCPU=14
	    export STARPU_WORKERS_CPUID="2 3 4 5 6 7 8 9 10 11 12 13 14 15"
    elif  [[ $(hostname) == tupi2 ]]; then
	    export STARPU_NCPU=6
	    export STARPU_WORKERS_CPUID="2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23"
# TUPIS EXCETO A 2 TEM E-CORES E P-CORES
    elif  [[ $(hostname) == tupi* ]]; then
	    export STARPU_NCPU=
	    export STARPU_WORKERS_CPUID=""
    elif  [[ $(hostname) == turing* ]]; then
	    export STARPU_NCPU=30
	    export STARPU_WORKERS_CPUID="2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31"
    fi

    export STARPU_NCUDA=0
    export STARPU_MPI_THREAD_CPUID="0"
    export STARPU_MAIN_THREAD_CPUID="0"
    export STARPU_WORKERS_GETBIND=1
    export STARPU_FXT_PREFIX="./${OUTPUT_DIR}/$order"
    export STARPU_SCHED=$scheduler
    export STARPU_MPI_PRIORITIES=0
    export STARPU_MPI_COOP_SENDS=0
    export STARPU_SCHED_BETA=10
    export STARPU_MPI_NDETACHED_SEND=0
    export STARPU_USE_NUMA=1


    STARPU_ENV_VARS=""
    STARPU_ENV_VARS+=" -x STARPU_NCUDA"
    STARPU_ENV_VARS+=" -x STARPU_NCPU"
    STARPU_ENV_VARS+=" -x STARPU_MPI_THREAD_CPUID"
    STARPU_ENV_VARS+=" -x STARPU_MAIN_THREAD_CPUID"
    STARPU_ENV_VARS+=" -x STARPU_WORKERS_CPUID"
    STARPU_ENV_VARS+=" -x STARPU_WORKERS_GETBIND"
    STARPU_ENV_VARS+=" -x STARPU_FXT_PREFIX"
    STARPU_ENV_VARS+=" -x STARPU_SCHED"
    STARPU_ENV_VARS+=" -x STARPU_MPI_PRIORITIES"
    STARPU_ENV_VARS+=" -x STARPU_MPI_COOP_SENDS"
    STARPU_ENV_VARS+=" -x STARPU_SCHED_BETA"
    STARPU_ENV_VARS+=" -x STARPU_MPI_NDETACHED_SEND"
    STARPU_ENV_VARS+=" -x STARPU_USE_NUMA"
    
    $(which mpirun) \
    -n ${SLURM_JOB_NUM_NODES} \
    ${STARPU_ENV_VARS} \
    $OPENMPI_PARAMETERS \
    -machinefile $HOSTFILE \
    $(which chameleon_dtesting) \
    $([ "$RASTRO" = 1 ] && echo "--trace") \
    -o dgetrf_nopiv \
    -m $size \
    -n $size \
    -b $block_size \
    -w  \
    -P $p > ./${OUTPUT_DIR}/$order.out < /dev/null

    if [ "$RASTRO" = 1 ]; then
	    # Execute StarVZ
	    export R_LIBS_USER=$(pwd)/R/x86_64-pc-linux-gnu-library/4.2/
	    export LD_LIBRARY_PATH=$(pwd)/arrow/lib/
	    export STARVZ_TOOLS=$(Rscript -e 'cat(system.file("tools/", package = "starvz"), sep="\n")')
	    $STARVZ_TOOLS/starvz -a lu ./${OUTPUT_DIR}/$order/
    fi
done

echo "End of executions"
