# fmriprep_singularity

Nearly everything you can actually find in this link: https://fmriprep.org/en/1.5.1/singularity.html This is specifically for me to keep note of using fmriprep on the NEU computing cluster using singularity.

## Step 1 Build fmriprep image 

Check your singularity version (for Discovery is 3.5.3 by default) if it’s over 2.5. If it is, run the following:

```

$ singularity build /home/USERNAME/my_images/fmriprep-20.2.4.simg docker://nipreps/fmriprep:20.2.4

```

For selecting which version of fmriprep you want to use, please visit: https://fmriprep.org/en/stable/changes.html


## Step 2 Check your bids files

You can upload your data to this website: http://bids-standard.github.io/bids-validator/

But if the data is not BIDS validated, and you don't want to spend time on changing it, you can skip **bids validation** in the fmriprep flag.

## Step 3 Get freesurfer (skip it if you already has freesurfer)

### 1. get the software
Type this to check your centOS version:

```
 cat /etc/centos-release
 
```

For Discovery is CentOS7. Then you will need to download the *freesurfer-linux-centos7_x86_64-7.2.0.tar.gz* 

Log in to discovery and cd to your home folder or any folder you want to place the freesurfer file. Use this command to download the freesurfer zip file to your folder:

```
wget https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/7.2.0/freesurfer-linux-centos7_x86_64-7.2.0.tar.gz
```
When the file is in your discovery folder, use this link to install freesurfer: https://surfer.nmr.mgh.harvard.edu/fswiki//FS7_linux

### 2. get the license

Go to https://surfer.nmr.mgh.harvard.edu/registration.html and fill out the registration form. Then you will receive a license.txt through your email. Please upload this license to your discovery path:

```

$ scp PATH/license.txt username@xfer-00.discovery.neu.edu:/home/username/WHERER_YOU_WANT_TO_PLACE_THIS_FILE

```

## Step 4 Prepare your subject number list

You will need a text file with all the ID numbers of participants you want to preprocess.

## Step 5 Build your SLURM script

Below is one example for me to run a sample of 100 participants. The whole script is modified based on the template from the tutorial (https://fmriprep.org/en/1.5.1/singularity.html)

**Some clarification for the request settings:**

- I recommend requesting short partition, even though you may have to run a couple of times. Requesting long partitions has a very long waiting time and you need to submit application.
- Max time limit for a short partition is 24 hours.
- For the cpu and memory settings, this worked out great for me to run fmriprep. If the resource is not enough, your job won't be finished in 24 hours and you will be notified. In that case you can allocate more cpus or larger memory, which also will take longer time for waiting.
- Array should be range of jobs(usually will be the number of participants) you want to process. The third number indicates how many jobs you run in this partition. The max number of jobs in one partition is 50.
- If you set up your email, you will be receiving emails about the status of job.


```
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
export HOME=/home/username
export FREESURFER_HOME=$HOME/software/freesurfer #this is the path for your installed freesurfer folder
source $FREESURFER_HOME/SetUpFreeSurfer.sh

subject_name=`sed "${SLURM_ARRAY_TASK_ID}q;d" sublist.txt` #this text file should store the ID numbers of the data you want to process

BIDS_DIR="$STUDY/bids" #the STUDY path will be defined later
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

# Compose the command line (I didn't use ICA aroma which takes too long to process, but you can add --use-aroma to run it)
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
 
```

## Step 5 Run fmriprep

Use the following to submit the slurm job:
```
export STUDY=/your/intended/bids/data/folder
sbatch YOUR_SLURM_SCRIPT.sh
```
