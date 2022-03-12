## Download ref genome from JGI
sbatch scripts/download_genome.sh data/ref_test/jgi

## Concatenate FASTQ files from different lanes
scr_cat=mcic-scripts/qc/fqconcat.sh
dir_fq_org=data/fastq/210922_Cisneros_CarterFiorella_GSL-FCC-2352
dir_fq=data/fastq/concat
sbatch "$scr_cat" -i "$dir_fq_org" -o "$dir_fq" -r "NN_Pool_"

## Run Snakemake workflow
sbatch workflow/snakemake.sh workflow/config.yaml

## Test with 1lane data
onelanedir=data/fastq/L001_only && mkdir -p "$onelanedir"

for smp_dir in "$dir_fq_org"/NN_Pool*; do
    R1=$(find "$smp_dir" -name "*L001_R1*")
    R1_basename=$(basename "$R1")
    R1_newname="$onelanedir"/"${R1_basename/NN_Pool_/}"
    cp -v "$R1" "$R1_newname"

    R2=$(find "$smp_dir" -name "*L001_R2*")
    R2_basename=$(basename "$R2")
    R2_newname="$onelanedir"/"${R2_basename/NN_Pool_/}"
    cp -v "$R2" "$R2_newname"
    echo -e "--------------\n"
done

sbatch workflow/snakemake.sh workflow/config_1lane.yaml