#!/bin/bash

#SBATCH --account=PAS0471
#SBATCH --time=12:00:00
#SBATCH --output=slurm-snakemake-%j.out
#SBATCH --job-name=smake-head

## Load software
conda activate /users/PAS0471/jelmer/.conda/envs/snakemake-minimal-env

## Bash strict settings
set -euo pipefail

## Report
echo -e "\n## Starting Snakemake run..."
date
echo

## Get command-line options
config_file=$1

## Constants
#LOGDIR=results/logs                         # Note: this dir is also specified in the SLURM config yaml, and can't just be changed here
SLURM_PROF_DIR=workflow/slurm_profile
DAG_FILE=workflow/workflow_dag.png
SLURM_CONFIG="$SLURM_PROF_DIR"/config.yaml

## Checks
[[ ! -f "$config_file" ]] && echo -e "\nERROR: Workflow config file $config_file does not exist\n\n" >&2 && exit 1
[[ ! -f "$SLURM_CONFIG" ]] && echo -e "\nERROR: SLURM profile config file $SLURM_CONFIG does not exist\n\n" >&2 && exit 1

## Report
echo "## Workflow config file:     $config_file"
echo "## SLURM config file:        $SLURM_CONFIG"
#echo "## SLURM logfile dir:        $LOGDIR"
echo

## Print contents of config file
echo "## Contents of config file ${config_file}:"
cat "$config_file"
echo

## Download MCIC scripts
if [ ! -d "mcic-scripts" ]; then
    echo "## Downloading MCIC-scripts..."
    git clone https://github.com/mcic-osu/mcic-scripts.git
fi

## Make dir for logfiles
#mkdir -p "$LOGDIR"

## Get a DAG of the workflow
[[ ! -f "$DAG_FILE" ]] && snakemake --dag | dot -T png > "$DAG_FILE"

## Run Snakemake
echo "## Starting Snakemake run..."
snakemake -p --profile "$SLURM_PROF_DIR" --configfile "$config_file"

## Report
echo -e "\n## Done with Snakemake run"
date
echo
