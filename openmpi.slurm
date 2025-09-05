#!/bin/bash
#SBATCH --nodes=6
#SBATCH --partition=cei
#SBATCH --time=12:00:00
#SBATCH --job-name="openmpi"
#SBATCH --output=./%j.out
#SBATCH --error=./%j.err

# fail on error
# https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
set -euxo pipefail

KEY=${SLURM_JOB_NAME}

# GUIX (https://guix.gnu.org/cookbook/en/html_node/Setting-Up-Compute-Nodes.html)
GUIX_DAEMON_SOCKET="guix://192.168.30.23"
export GUIX_DAEMON_SOCKET
GUIX_LOCPATH=/var/guix/profiles/per-user/root/guix-profile/lib/locale
export GUIX_LOCPATH
for GUIX_PROFILE in "$HOME/.config/guix/current" "$HOME/.guix-profile"
do
  if [ -f "$GUIX_PROFILE/etc/profile" ]; then
    . "$GUIX_PROFILE/etc/profile"
  fi
done
# GUIX end

#hostname

# Install requirements (usually done before)
GUIX_MANIFEST=${KEY}_chameleon.scm
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
#guix package -p $HOME/.guix-profile/ -m ${GUIX_MANIFEST}
set +u
eval "$(guix shell -m ${SLURM_JOB_NAME}_chameleon.scm --search-paths)"
set -u

# Destroy all env var starting with STARPU
unset "${!STARPU@}"

# Define env vars
export STARPU_SCHED_BETA=10
export STARPU_MPI_COOP_SENDS=0
export STARPU_USE_NUMA=1
export STARPU_NCUDA=0
export STARPU_NCPU=24
export STARPU_MAIN_THREAD_CPUID="0"
export STARPU_WORKERS_CPUID="2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23"
export STARPU_MPI_THREAD_CPUID="1"
export STARPU_CALIBRATE=1
export STARPU_LIMIT_MAX_SUBMITTED_TASKS=1000000

# Create the hostfile
HOSTFILE="${KEY}.nodes"
srun -l hostname | sort -n | awk '{print $2}' | sed 's/$/ slots=1/' > $HOSTFILE

#    --bind-to nonenone \
#   -mca btl_base_verbose 30 \
#    -mca pml_base_verbose 30 \
#    -mca oob_base_verbose 30 \

# Run
CSV_FILE="${SLURM_JOB_NAME}_experimental_project.csv"

mkdir -p ./output
# Skip header and read the rest

echo '
#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
    MPI_Init(&argc, &argv);

    int rank;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);

    printf("Rank %d: STARPU_SCHED=%s\n", rank, getenv("STARPU_SCHED"));

    MPI_Finalize();
    return 0;
}
' > x.c
$(which mpicc) x.c
./a.out

export OMPI_MCA_plm=isolated

$(which mpirun) --version
$(which mpirun) --help
tail -n +2 "$CSV_FILE" | while IFS=',' read -r size block_size scheduler pq Blocks exp Order; do
   echo
   echo $scheduler
   echo
   export STARPU_SCHED=$scheduler
   $(which mpirun) \
    --mca btl_base_verbose 30 \
    --mca pml_base_verbose 30 \
    --mca oob_base_verbose 30 \
    --mca oob_tcp_if_include eno2 \
    --mca btl_tcp_if_include eno2 \
   --np ${SLURM_JOB_NUM_NODES} \
   --hostfile $HOSTFILE \
   -x STARPU_SCHED \
   ./a.out < /dev/null
done

#    --mca btl_base_verbose 30 \
#    --mca pml_base_verbose 30 \
#    --mca oob_base_verbose 30 \
tail -n +2 "$CSV_FILE" | while IFS=',' read -r size block_size scheduler pq Blocks exp Order; do
    p=$(echo "$pq" | cut -d'x' -f1)

    export STARPU_SCHED=$scheduler
    "$(which mpirun)" \
    --mca oob_tcp_if_include eno2 \
    --mca btl_tcp_if_include eno2 \
    --np ${SLURM_JOB_NUM_NODES} \
    --hostfile $HOSTFILE \
    -x STARPU_SCHED \
    "$(which chameleon_dtesting)" \
    -o getrf_nopiv \
    -m $size \
    -n $size \
    -b $block_size \
    -w \
    -P $p > ./output/"$Order".out < /dev/null
done

echo "terminou"

