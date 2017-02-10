#!/bin/bash
#
#SBATCH --job-name=our_v35_avg_seqOut_cifar100
#SBATCH --output=our_v35_avg_seqOut_cifar100-%j.txt
#SBATCH --time=0-04:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --gres gpu:2

ml torch/20160805-4bfc2da protobuf/2.6.1
ml CUDA/7.5.18 cuDNN/5.0-CUDA-7.5.18

#th main.lua -sequenceOut 'true' -seqLength 8 -nGPU 2 -depth 20 -batchSize 128 -dataset cifar100 -nEpochs 20 -netType 'our_v35_avg_seqOut' -save 'checkpoints_our_v35_avg_seqOut' 2>&1 | tee log_our_v35_avg_seqOut.txt
th main.lua -sequenceOut 'true' -seqLength 8  -nGPU 2 -depth 20 -batchSize 128 -dataset cifar100 -nEpochs 50 -netType 'our_v35_avg_seqOut' -save 'checkpoints_our_v35_avg_seqOut_cond' -resume 'checkpoints_our_v35_avg_seqOut' 2>&1 | tee log_our_v35_avg_seqOut_cond.txt
#th main.lua -sequenceOut 'true' -seqLength 8  -nGPU 2 -depth 20 -batchSize 128 -dataset cifar100 -nEpochs 65 -netType 'our_v35_avg_seqOut' -save 'checkpoints_our_v35_avg_seqOut_cond2' -resume 'checkpoints_our_v35_avg_seqOut_cond' 2>&1 | tee log_our_v35_avg_seqOut_cond2.txt
#th main.lua -sequenceOut 'true' -seqLength 8  -nGPU 2 -depth 20 -batchSize 128 -dataset cifar100 -nEpochs 80 -netType 'our_v35_avg_seqOut' -save 'checkpoints_our_v35_avg_seqOut_cond3' -resume 'checkpoints_our_v35_avg_seqOut_cond2' 2>&1 | tee log_our_v35_avg_seqOut_cond3.txt
#th main.lua -sequenceOut 'true' -seqLength 8  -nGPU 2 -depth 20 -batchSize 128 -dataset cifar100 -nEpochs 100 -netType 'our_v35_avg_seqOut' -save 'checkpoints_our_v35_avg_seqOut_cond4' -resume 'checkpoints_our_v35_avg_seqOut_cond3' 2>&1 | tee log_our_v35_avg_seqOut_cond4.txt
#th main.lua -sequenceOut 'true' -seqLength 8  -LR 0.01 -nGPU 1 -depth 20 -batchSize 128 -dataset cifar100 -nEpochs 100 -netType 'our_v35_avg_seqOut' -save 'checkpoints_our_v35_avg_seqOut_cond4_LR0p01' -resume 'checkpoints_our_v35_avg_seqOut_cond3' 2>&1 | tee log_our_v35_avg_seqOut_cond4_LR0p01.txt
#th main.lua -sequenceOut 'true' -seqLength 8  -LR 0.01 -nGPU 2 -depth 20 -batchSize 128 -dataset cifar100 -nEpochs 90 -netType 'our_v35_avg_seqOut' -save 'checkpoints_our_v35_avg_seqOut_cond3_LR0p01' -resume 'checkpoints_our_v35_avg_seqOut_cond2' 2>&1 | tee log_our_v35_avg_seqOut_cond3_LR0p01.txt
#th main.lua -sequenceOut 'true' -seqLength 8  -nGPU 1 -depth 20 -batchSize 96 -dataset cifar100 -nEpochs 65 -netType 'our_v35_avg_seqOut' -save 'checkpoints_our_v35_avg_seqOut_cond2_LR0p01' -resume 'checkpoints_our_v35_avg_seqOut_cond' -LR 0.01 2>&1 | tee log_our_v35_avg_seqOut_cond2_LR0p01.txt
#th main.lua -sequenceOut 'true' -seqLength 8  -nGPU 1 -depth 20 -batchSize 96 -dataset cifar100 -nEpochs 95 -netType 'our_v35_avg_seqOut' -save 'checkpoints_our_v35_avg_seqOut_cond2_LR0p001' -resume 'checkpoints_our_v35_avg_seqOut_cond2_LR0p01' -LR 0.001 2>&1 | tee log_our_v35_avg_seqOut_cond3_LR0p001.txt
#th main.lua -sequenceOut 'true' -seqLength 8  -nGPU 1 -depth 20 -batchSize 96 -dataset cifar100 -nEpochs 80 -netType 'our_v35_avg_seqOut' -save 'checkpoints_our_v35_avg_seqOut_cond2' -resume 'checkpoints_our_v35_avg_seqOut_cond' 2>&1 | tee log_our_v35_avg_seqOut_cond2.txt
