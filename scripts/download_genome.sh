#!/bin/bash

#SBATCH --account=PAS0471
#SBATCH --output=slurm_download-genome_%j.out

## Bash strict settings
set -euo pipefail

## Command line-args
outdir=$1

## Process args
outdir=${outdir%/}   # Remove any trailing slashes
outdir_oneup=$(dirname "$outdir")
mkdir -p "$outdir_oneup"

## Report
echo "## Starting script download_genome.sh"
date
echo
echo "## Output dir:        $outdir"
echo

## Download
echo "## Downloading genome files..."
curl --cookie jgi_session=/api/sessions/4d4da552eaacccff8428e52b260a7acb \
    --output "$outdir".zip \
    -d "{\"ids\":{\"Phytozome-508\":[\"5bfc64e746d1e61e989e5766\",\"5bfc65da46d1e61e989e5770\",\"5bfc65da46d1e61e989e5771\",\"5bfc64e946d1e61e989e576a\",\"5bfc65db46d1e61e989e5774\",\"5bfc64e546d1e61e989e5762\",\"5bfc64e846d1e61e989e5768\",\"5bfc64e846d1e61e989e5769\",\"5bfc65db46d1e61e989e5773\",\"5bfc64e646d1e61e989e5764\",\"5bfc64eb46d1e61e989e576e\",\"5bfc64e546d1e61e989e5763\",\"5bfc64e646d1e61e989e5765\",\"5bfc64eb46d1e61e989e576f\",\"5bfc65db46d1e61e989e5772\",\"5bfc65dc46d1e61e989e5775\",\"5c01c6dc46d1e61e989ea5ad\",\"5f6bb3607a4cf8208a33e0a1\",\"5bfc64ea46d1e61e989e576c\",\"5bfc64e746d1e61e989e5767\",\"5bfc64e946d1e61e989e576b\",\"5bfc64ea46d1e61e989e576d\"]}}" \
    -H "Content-Type: application/json" \
    https://files.jgi.doe.gov/filedownload/

## Unzip
echo -e "\nUnzipping genome files..."
unzip -d "$outdir" "$outdir".zip 

## Report
echo -e "\n## Showing files in downloaded dir:"
tree "$outdir"
echo -e "\n## Done with script download_genome.sh"
date
echo
