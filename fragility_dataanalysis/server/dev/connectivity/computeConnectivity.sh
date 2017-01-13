#!/bin/bash -l
# This script runs the computation/estimation of adjacency matrices
source /etc/profile.modules
module load matlab/matlab2013a

#### This script is called by the pbs file. ####

## 00: Load in input parameters
proc="$1"
patient="$2"
winSize="$3"
stepSize="$4" 
currWin="$5"

## 01: Set parameters for matlab to run, and check if matlab is on path
matlab_jvm="matlab -nojvm -nodesktop -nosplash -r"
[[ ! -z "`which matlab`" ]] || \
	{ 
		echo "MATLAB not found on the PATH; please add to path."; 
		exit 1;
	}

echo "Running connectivity computation."
matlab -logfile /home/ali/adamli/fragility_dataanalysis/server/_log/job$1.txt -nojvm -nodisplay -nosplash -r "currentpatient='$patient'; \
	disp('testing....')
	serverComputeConnectivity($patient, $currWin, $winSize, $stepSize);\
	exit;"