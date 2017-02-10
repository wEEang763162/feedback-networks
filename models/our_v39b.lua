--
--  Copyright (c) 2016, Facebook, Inc.
--  All rights reserved.
--
--  This source code is licensed under the BSD-style license found in the
--  LICENSE file in the root directory of this source tree. An additional grant
--  of patent rights can be found in the PATENTS file in the same directory.
--
--  The ResNet model definition
--

local nn = require 'nn'
require 'cunn'
require 'ConvLSTM_resnet4'
require 'cunn'
require 'rnn'
local checkpoints = require 'checkpoints'

local Convolution = cudnn.SpatialConvolution
local Avg = cudnn.SpatialAveragePooling
local ReLU = cudnn.ReLU
local Max = nn.SpatialMaxPooling
local SBatchNorm = nn.SpatialBatchNormalization

local function createModel(opt)
   local depth = opt.depth
   local shortcutType = opt.shortcutType or 'B'
   local iChannels

   -- The shortcut layer is either identity or 1x1 convolution
   local function shortcut(nInputPlane, nOutputPlane, stride)
      local useConv = shortcutType == 'C' or
         (shortcutType == 'B' and nInputPlane ~= nOutputPlane)
      if useConv then
         -- 1x1 convolution
         return nn.Sequential()
            :add(Convolution(nInputPlane, nOutputPlane, 1, 1, stride, stride))
            :add(SBatchNorm(nOutputPlane))
      elseif nInputPlane ~= nOutputPlane then
         -- Strided, zero-padded identity shortcut
         return nn.Sequential()
            :add(nn.SpatialAveragePooling(1, 1, stride, stride))
            :add(nn.Concat(2)
               :add(nn.Identity())
               :add(nn.MulConstant(0)))
      elseif nInputPlane == nOutputPlane and stride > 2 then
         return nn.Sequential()
            :add(nn.SpatialAveragePooling(1, 1, stride, stride))
            :add(nn.Concat(2)
               :add(nn.Identity())
               :add(nn.MulConstant(0)))
      else
         return nn.Identity()
      end
   end

   -- The basic residual layer block for 18 and 34 layer network, and the
   -- CIFAR networks
   local function basicblock(n, stride)
      local nInputPlane = iChannels
      iChannels = n

      local s = nn.Sequential()
      s:add(Convolution(nInputPlane,n,3,3,stride,stride,1,1))
      s:add(SBatchNorm(n))
      s:add(ReLU(true))
      s:add(Convolution(n,n,3,3,1,1,1,1))
      s:add(SBatchNorm(n))

      return nn.Sequential()
         :add(nn.ConcatTable()
            :add(s)
            :add(shortcut(nInputPlane, n, stride)))
         :add(nn.CAddTable(true))
         :add(ReLU(true))
   end

   -- The basic residual layer block for 18 and 34 layer network, and the
   -- CIFAR networks
   local function basicblock2(n, ic, stride)
      local nInputPlane = ic

      local s = nn.Sequential()
      s:add(Convolution(nInputPlane,n,3,3,stride,stride,1,1))
      s:add(SBatchNorm(n))
      s:add(ReLU(true))
      s:add(Convolution(n,n,3,3,1,1,1,1))
      s:add(SBatchNorm(n))

      return nn.Sequential()
         :add(nn.ConcatTable()
            :add(s)
            :add(shortcut(nInputPlane, n, stride)))
         :add(nn.CAddTable(true))
         :add(ReLU(true))
   end

   -- The bottleneck residual layer for 50, 101, and 152 layer networks
   local function bottleneck(n, stride)
      local nInputPlane = iChannels
      iChannels = n * 4

      local s = nn.Sequential()
      s:add(Convolution(nInputPlane,n,1,1,1,1,0,0))
      s:add(SBatchNorm(n))
      s:add(ReLU(true))
      s:add(Convolution(n,n,3,3,stride,stride,1,1))
      s:add(SBatchNorm(n))
      s:add(ReLU(true))
      s:add(Convolution(n,n*4,1,1,1,1,0,0))
      s:add(SBatchNorm(n * 4))

      return nn.Sequential()
         :add(nn.ConcatTable()
            :add(s)
            :add(shortcut(nInputPlane, n * 4, stride)))
         :add(nn.CAddTable(true))
         :add(ReLU(true))
   end

   -- Creates count residual blocks with specified number of features
   local function layer(block, features, count, stride)
      local s = nn.Sequential()
      for i=1,count do
         s:add(block(features, i == 1 and stride or 1))
      end
      return s
   end

   -- Creates count residual blocks with specified number of features
   local function layer2(block, features, ic, count, stride)
      local s = nn.Sequential()
      for i=1,count do
         s:add(block(features, ic, i == 1 and stride or 1))
      end
      return s
   end

   local model = nn.Sequential()
   if opt.dataset == 'imagenet' then
      -- Configurations for ResNet:
      --  num. residual blocks, num features, residual block function
      local cfg = {
         [18]  = {{2, 2, 2, 2}, 512, basicblock},
         [34]  = {{3, 4, 6, 3}, 512, basicblock},
         [50]  = {{3, 4, 6, 3}, 2048, bottleneck},
         [101] = {{3, 4, 23, 3}, 2048, bottleneck},
         [152] = {{3, 8, 36, 3}, 2048, bottleneck},
      }

      assert(cfg[depth], 'Invalid depth: ' .. tostring(depth))
      local def, nFeatures, block = table.unpack(cfg[depth])
      iChannels = 64
      print(' | ResNet-' .. depth .. ' ImageNet')

      -- The ResNet ImageNet model
      model:add(Convolution(3,64,7,7,2,2,3,3))
      model:add(SBatchNorm(64))
      model:add(ReLU(true))
      model:add(Max(3,3,2,2,1,1))
      model:add(layer(block, 64, def[1]))
      model:add(layer(block, 128, def[2], 2))
      model:add(layer(block, 256, def[3], 2))
      model:add(layer(block, 512, def[4], 2))
      model:add(Avg(7, 7, 1, 1))
      model:add(nn.View(nFeatures):setNumInputDims(3))
      model:add(nn.Linear(nFeatures, 1000))
   elseif opt.dataset == 'cifar10' then
      -- Model type specifies number of layers for CIFAR-10 model
      assert((depth - 2) % 6 == 0, 'depth should be one of 20, 32, 44, 56, 110, 1202')
      local n = (depth - 2) / 6
      iChannels = 16
      print(' | ResNet-' .. depth .. ' CIFAR-10')

      -- The ResNet CIFAR-10 model
      model:add(Convolution(3,16,3,3,1,1,1,1))
      model:add(SBatchNorm(16))
      model:add(ReLU(true))
      model:add(layer(basicblock, 16, n))
      model:add(layer(basicblock, 32, n, 2))
      model:add(layer(basicblock, 64, n, 2))
      model:add(Avg(8, 8, 1, 1))
      model:add(nn.View(64):setNumInputDims(3))
      model:add(nn.Linear(64, 10))
   elseif opt.dataset == 'cifar100' then
      -- Model type specifies number of layers for CIFAR-100 model
      assert((depth - 2) % 6 == 0, 'depth should be one of 20, 32, 44, 56, 110, 1202')
      local n = (depth - 2) / 6
      local N = opt.batchSize
      iChannels = 32
      T = 8
      D = iChannels
      print(' | ResNet-' .. depth .. ' CIFAR-100')

      -- The ResNet CIFAR-100 model
      model:add(Convolution(3,iChannels,3,3,1,1,1,1))
      model:add(SBatchNorm(iChannels))
      model:add(ReLU(true))
      -- model:add(Avg(1,1,2,2))

      model:add(nn.Replicate(T))
      model:add(nn.Contiguous())
      model:add(nn.View(T, -1, D, 32, 32))
      model:add(nn.SplitTable(1))

      -- model:add(nn.Sequencer(Convolution(64,64,1,1,2,2)))
      -- model:add(nn.Sequencer(Avg(2,2,2,2)))
      -- model:add(nn.Sequencer(Convolution(16,32,3,3,2,2,1,1)))
      -- model:add(nn.Sequencer(SBatchNorm(32)))
      -- model:add(nn.Sequencer(ReLU(true)))
      model:add(nn.Sequencer(nn.ConvLSTM_resnet4(32, 64, T, 3, 3, 2, N/opt.nGPU, opt.nGPU)))
      model:add(nn.SelectTable(-1))
      model:add(nn.Replicate(T))
      model:add(nn.Contiguous())
      model:add(nn.SplitTable(1))

      -- model:add(nn.Sequencer(Convolution(64,64,1,1,2,2)))
      -- model:add(nn.Sequencer(Convolution(32,64,3,3,2,2,1,1)))
      -- model:add(nn.Sequencer(SBatchNorm(64)))
      -- model:add(nn.Sequencer(ReLU(true)))
      model:add(nn.Sequencer(nn.ConvLSTM_resnet4(64, 128, T, 3, 3, 2, N/opt.nGPU, opt.nGPU)))
      model:add(nn.SelectTable(-1))

      -- model:add(nn.JoinTable(1))
      -- model:add(nn.View(T, -1, 128, 8, 8))
      -- model:add(nn.Mean(1))
      -- model:add(nn.Squeeze(1))

      -- model:add(Avg(8, 8, 1, 1))
      -- model:add(nn.View(64):setNumInputDims(3))
      -- model:add(nn.Linear(64, 100))
      model:add(nn.View(8192):setNumInputDims(3))
      model:add(nn.Linear(8192, 100))
   else
      error('invalid dataset: ' .. opt.dataset)
   end

   local function ConvInit(name)
      for k,v in pairs(model:findModules(name)) do
         local n = v.kW*v.kH*v.nOutputPlane
         v.weight:normal(0,math.sqrt(2/n))
         if cudnn.version >= 4000 then
            v.bias = nil
            v.gradBias = nil
         else
            v.bias:zero()
         end
      end
   end
   local function BNInit(name)
      for k,v in pairs(model:findModules(name)) do
         v.weight:fill(1)
         v.bias:zero()
      end
   end

   ConvInit('cudnn.SpatialConvolution')
   ConvInit('nn.SpatialConvolution')
   BNInit('fbnn.SpatialBatchNormalization')
   BNInit('cudnn.SpatialBatchNormalization')
   BNInit('nn.SpatialBatchNormalization')
   for k,v in pairs(model:findModules('nn.Linear')) do
      v.bias:zero()
   end
   model:cuda()

   if opt.cudnn == 'deterministic' then
      model:apply(function(m)
         if m.setMode then m:setMode(1,1,1) end
      end)
   end

   model:get(1).gradInput = nil
   
   -- for testing purpose only
   if opt.testOnly then
      print ("[Test phase]")
      local checkpoint, optimState = checkpoints.latest(opt)
      local modelPath = paths.concat(opt.resume, checkpoint.modelFile)
      trained_model = torch.load(modelPath)
   end
   if opt.testOnly then
     model = trained_model:clone('weight', 'bias')
     model:replace(function(module)
       if torch.typename(module) == 'nn.Replicate' then
         return nn.Replicate(opt.seqLength)
       else
         return module
       end
     end)
     model:replace(function(module)
       if torch.typename(module) == 'nn.View' then
         if #module.size == 5 then
           if module.size[3] == 32 then
             return nn.View(opt.seqLength, -1, D, 32, 32)
           elseif module.size[3] == 128 then
             return nn.View(opt.seqLength, -1, 128, 8, 8)
           end
         else
           return module
         end
       else
         return module
       end
     end)
   end

   if opt.testOnly then
     print ("Revised model:")
     -- print (model)
     return model
   end

   return model
end

return createModel
