#!/bin/bash
# Usage: ./merge.sh /path/to/folder output.csv

dir="$1"
outfile="$2"

awk -F';' '
BEGIN {OFS=";"}
FNR==1 && NR==1 {print $0,"scheduler"}   # header once
FNR>1 && $1 ~ /^[0-9]+$/ {
    split(FILENAME, parts, "_")
    scheduler=parts[3]
    print $0, scheduler
}' "$dir"/*.out > "$outfile"
