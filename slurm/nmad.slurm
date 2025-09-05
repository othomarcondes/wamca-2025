#!/bin/bash
#SBATCH --nodes=6
#SBATCH --partition=cei
#SBATCH --time=12:00:00
#SBATCH --job-name="nmad"
#SBATCH --output=./%J.out
#SBATCH --error=./%J.err

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
GUIX_MANIFEST=${SLURM_JOB_NAME}_chameleon.scm
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
set +u
eval "$(guix shell -m ${GUIX_MANIFEST} --search-paths)"
set -u

# Create the hostfile
HOSTFILE="${SLURM_JOB_ID}.nodes"
srun -l hostname | sort -n | awk '{print $2}' > $HOSTFILE
unset "${!STARPU@}"

export STARPU_SCHED_BETA=10
export STARPU_MPI_COOP_SENDS=0
#export STARPU_FXT_PREFIX="${SLURM_JOB_ID}/"

export STARPU_USE_NUMA=1

export STARPU_RESERVE_NCPU=2
export STARPU_NCUDA=0
export STARPU_NCPU=24
export STARPU_MAIN_THREAD_CPUID="1"
export STARPU_MPI_THREAD_CPUID="2"

# Read experiments and execute
CSV_FILE="${SLURM_JOB_NAME}_experimental_project.csv"
mkdir ./output

# Skip header and read the rest
tail -n +2 "$CSV_FILE" | while IFS=',' read -r size block_size scheduler pq foo exp order; do
    # Define env vars
    export STARPU_FXT_TRACE=0
    export STARPU_SCHED=$scheduler

    p=$(echo "$pq" | cut -d'x' -f1)

    $(which mpirun) \
    -n ${SLURM_JOB_NUM_NODES} \
    -DSTARPU_FXT_TRACE=0 \
    -DSTARPU_SCHED=$scheduler \
    -DSTARPU_SCHED_BETA=10 \
    -DSTARPU_MPI_COOP_SENDS=0 \
    -DSTARPU_USE_NUMA=1 \
    -DSTARPU_RESERVE_NCPU=2 \
    -DSTARPU_NCUDA=0 \
    -DSTARPU_NCPU=24 \
    -DSTARPU_MAIN_THREAD_CPUID="1" \
    -DSTARPU_MPI_THREAD_CPUID="2" \
    -machinefile $HOSTFILE \
    $(which chameleon_dtesting) \
    -o dgetrf_nopiv \
    -m $size \
    -n $size \
    -b $block_size \
    -w  \
    -P $p  > ./output/$order.out
    #--trace

    #Copy the prof_file_* files of each node to the experiment folder (SETTING STRAPU_FXT_PREFIX MAKES THIS USELESS)
    #for f in $(cat $HOSTFILE); do
    #   rsync -av "$f:/tmp/prof_file_*" "./${SLURM_JOB_ID}/"
    #done

    # Execute StarVZ
    #export LD_LIBRARY_PATH=$HOME/install/arrow/lib/
    #export STARVZ_TOOLS=$(Rscript -e 'cat(system.file("tools/", package = "starvz"), sep="\n")')
    #$STARVZ_TOOLS/starvz -a lu ./${SLURM_JOB_ID}/
done

echo "End of executions"

