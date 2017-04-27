#!/bin/bash
#
#SBATCH --job-name=resnetX2_6_cifar100
#SBATCH --output=resnetX2_6_cifar100-%j.txt
#SBATCH --time=2-00:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --gres gpu:2

ml torch/20160805-4bfc2da protobuf/2.6.1
ml CUDA/7.5.18 cuDNN/5.0-CUDA-7.5.18

th main.lua -depth 20 -batchSize 128 -dataset cifar100 -nEpochs 120 -netType 'resnetX2_7' -save 'checkpoints_resnetX2_7' 2>&1 | tee log_resnetX2_7_no_dropout.txt