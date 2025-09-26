#!/bin/bash

partitions=("cei" "draco" "hype")

for partition in "${partitions[@]}"; do
    sbatch --partition=$partition --job-name="$partition" partitions.slurm 1 openmpi
done

