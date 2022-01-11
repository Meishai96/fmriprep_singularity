#!/bin/sh

#SBATCH --job-name=jobMA_fmriprep
#SBATCH --partition=short
#SBATCH --time=23:59:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem-per-cpu=16GB
# Outputs --------------------------
#SBATCH --output=%x.%A-%a.out
#SBATCH --error=%x.%A-%a.err
#SBATCH --array=1-160%50
#SBATCH --mail-user=ai.me@northeastern.edu
#SBATCH --mail-type=ALL
# ----------------------------------

module load singularity/3.5.3
export HOME=/home/ai.me
export FREESURFER_HOME=$HOME/software/freesurfer
source $FREESURFER_HOME/SetUpFreeSurfer.sh

## job task ID: $SLURM_ARRAY_TASK_ID = {1..160}

subject_name=`sed "${SLURM_ARRAY_TASK_ID}q;d" sublist.txt`
# session_name=`sed "${SLURM_ARRAY_TASK_ID}q;d" sessionlist.txt`

#export STUDY=/work/cbhlab/Meishan/PAD_pred_dataset
BIDS_DIR="$STUDY/bids"
DERIVS_DIR="$STUDY/derivatives"
LOCAL_FREESURFER_DIR="$STUDY/derivatives/freesurfer"
WF_FILES="$STUDY/wf_files"

#prepare derivatives folder 
mkdir -p ${DERIVS_DIR}
mkdir -p ${LOCAL_FREESURFER_DIR}
mkdir -p ${WF_FILES}

#the liscense
export SINGULARITYENV_FS_LICENSE=$HOME/license.txt

#writeable bind-mount points
TEMPLATEFLOW_HOST_HOME=$WF_FILES/.cache/templateflow
FMRIPREP_HOST_CACHE=$WF_FILES/.cache/fmriprep
mkdir -p ${TEMPLATEFLOW_HOST_HOME}
mkdir -p ${FMRIPREP_HOST_CACHE}

#derivatives folder
#mkdir -p ${BIDS_DIR}/${DERIVS_DIR}

# Designate a templateflow bind-mount point
export SINGULARITYENV_TEMPLATEFLOW_HOME="/templateflow"
SINGULARITY_CMD="singularity run --cleanenv -B $BIDS_DIR:/data -B ${DERIVS_DIR}:/outdirfMRIprep -B ${TEMPLATEFLOW_HOST_HOME}:${SINGULARITYENV_TEMPLATEFLOW_HOME} -B ${WF_FILES}:/work -B ${LOCAL_FREESURFER_DIR}:/fsdir ${HOME}/my_images/fmriprep-20.2.4.simg"

# Remove IsRunning files from FreeSurfer (copied)
find ${LOCAL_FREESURFER_DIR}/sub-$subject_name/ -name "*IsRunning*" -type f -delete

# Compose the command line
cmd="${SINGULARITY_CMD} /data /outdirfMRIprep  participant --participant-label $subject_name  -w /work/ -vv --omp-nthreads 8 --nthreads 12
 --mem_mb 30000 --output-spaces MNI152NLin2009cAsym:res-2 anat fsnative fsaverage5 --fs-subjects-dir /fsdir --skip_bids_validation"

# Setup done, run the command
echo Running task ${SLURM_ARRAY_TASK_ID}
echo Commandline: $cmd
eval $cmd
exitcode=$?

# Output results to a table
echo "sub-$subject   ${SLURM_ARRAY_TASK_ID}    $exitcode" \
      >> ${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
echo $subject_name
echo Finished tasks ${SLURM_ARRAY_TASK_ID} with exit code $exitcode
exit $exitcode

#  
