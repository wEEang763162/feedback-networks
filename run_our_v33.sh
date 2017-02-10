#!/bin/bash
#
#SBATCH --job-name=our_v33_cifar100
#SBATCH --output=our_v33_cifar100-%j.txt
#SBATCH --time=2-00:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --gres gpu:1

ml torch/20160805-4bfc2da protobuf/2.6.1
ml CUDA/7.5.18 cuDNN/5.0-CUDA-7.5.18

th main.lua -nGPU 1 -depth 20 -batchSize 96 -dataset cifar100 -nEpochs 110 -netType 'our_v33' -save 'checkpoints_our_v33_cond4' -resume 'checkpoints_our_v33_cond3' -LR 0.001 2>&1 | tee log_our_v33_cond4.txt
