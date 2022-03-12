; Magic: 0x07230203
; Version: 0x00010500 (Version: 1.5.0)
; Generator: 0x00080001 (käsin tehty artisaanikoodi)
; Bound: 100
; Schema: 0
    OpCapability Shader
    OpCapability GroupNonUniform
    OpCapability GroupNonUniformArithmetic
    OpCapability GroupNonUniformBallot
    OpCapability GroupNonUniformQuad
    OpCapability GroupNonUniformVote
    OpCapability Groups
    OpCapability VariablePointersStorageBuffer
    OpCapability VulkanMemoryModelDeviceScopeKHR

    OpCapability VulkanMemoryModel

    OpMemoryModel Logical Vulkan
    OpEntryPoint GLCompute %main "main" %invocation_id %SubgroupSize %SubgroupID %SubgroupLocalID %out %input
    OpExecutionMode %main LocalSize 1024 1 1
    OpDecorate %invocation_id BuiltIn GlobalInvocationId

    OpDecorate %oa ArrayStride 4
    OpMemberDecorate %os 0 Offset 0
    OpDecorate %os Block
    OpDecorate %out DescriptorSet 0
    OpDecorate %out Binding 0
    OpDecorate %out Aliased

    OpDecorate %lra ArrayStride 4
    OpMemberDecorate %lrs 0 Offset 0
    OpDecorate %lrs Block
    OpDecorate %input DescriptorSet 0
    OpDecorate %input Binding 1

    OpDecorate %SubgroupSize RelaxedPrecision
    OpDecorate %SubgroupSize Flat
    OpDecorate %SubgroupSize BuiltIn SubgroupSize

    OpDecorate %SubgroupLocalID RelaxedPrecision
    OpDecorate %SubgroupLocalID Flat
    OpDecorate %SubgroupLocalID BuiltIn SubgroupLocalInvocationId

    OpDecorate %SubgroupID RelaxedPrecision
    OpDecorate %SubgroupID Flat
    OpDecorate %SubgroupID BuiltIn SubgroupId

    OpDecorate %spec_constant_1 SpecId 0

; All types, variables, and constants
    %1 = OpTypeInt 32 0
    %void = OpTypeVoid
    %11 = OpTypeFunction %void
    %bool = OpTypeBool
    %float = OpTypeFloat 32

    %uint_0 = OpConstant %1 0
    %uint_1 = OpConstant %1 1
    %uint_2 = OpConstant %1 2
    %uint_3 = OpConstant %1 3
    %uint_5 = OpConstant %1 5
    %uint_32 = OpConstant %1 32
    %uint_64 = OpConstant %1 64

    %float_0 = OpConstant %float 0
    %float_1 = OpConstant %float 1

    %true = OpConstantTrue %bool
    %false = OpConstantFalse %bool

    %_ptr_Input_uint = OpTypePointer Input %1
    %SubgroupSize = OpVariable %_ptr_Input_uint Input
    %SubgroupLocalID = OpVariable %_ptr_Input_uint Input
    %SubgroupID = OpVariable %_ptr_Input_uint Input

; Wg
    %wg_vec = OpTypeVector %1 3
    %wg_vec_p = OpTypePointer Input %wg_vec
    %invocation_id = OpVariable %wg_vec_p Input
    %wg = OpTypePointer Input %1

    %lra = OpTypeArray %float %uint_64
    %lrs = OpTypeStruct %lra
    %lrsp = OpTypePointer StorageBuffer %lrs
    %input = OpVariable %lrsp StorageBuffer

    %oa = OpTypeArray %float %uint_64
    %os = OpTypeStruct %oa
    %osp = OpTypePointer StorageBuffer %os
    %out = OpVariable %osp StorageBuffer

; Pointer types
    %_ptr_Function_uint = OpTypePointer Function %1
    %_ptr_Uniform_uint = OpTypePointer StorageBuffer %1
    %_ptr_Uniform_float = OpTypePointer StorageBuffer %float
    %_ptr_Uniform_bool = OpTypePointer StorageBuffer %bool
    %_ptr_Function_float = OpTypePointer Function %float

; Spec Const

    %spec_constant_1 = OpSpecConstant %1 1

; Some access flags
    %none = OpConstant %1 0x0
    %Volatile = OpConstant %1 0x1
    %Acquire = OpConstant %1 0x2
    %Release = OpConstant %1 0x4
    %AcquireRelease = OpConstant %1 0x8
    %MakePointerVisible = OpConstant %1 0x10
    %NonPrivatePointer = OpConstant %1 0x20
    %UniformMemory = OpConstant %1 0x40

    %apply_signature = OpTypeFunction %float %_ptr_Uniform_float

    %main = OpFunction %void None %11
    %16 = OpLabel
        ; loop iterator variable
        %iter = OpVariable %_ptr_Function_uint Function

        %sgs_o = OpLoad %1 %SubgroupSize
        %sgli_o = OpLoad %1 %SubgroupLocalID

        ; invocation id ptr, "thread" id
        %52 = OpAccessChain %wg %invocation_id %uint_0
        %53 = OpLoad %1 %52

        ; the following code is pseudocode for the following:
        ;
        ; reduce
        ; define iter
        ; match iter
        ;   true => {
        ;       sync
        ;       reduce
        ;       iter--
        ;       continue
        ;   },
        ;   false => break

        ; assign an element from input vector to this thread
        %60 = OpAccessChain %_ptr_Uniform_float %input %uint_0 %53 ; nb: input array
        %node = OpFunctionCall %float %apply %60

        ; we iterate up to 64 (input size) / subgroup size
        %iter_x = OpUDiv %1 %uint_64 %sgs_o
        OpStore %iter %iter_x

        OpBranch %while_start ; while
        %while_start = OpLabel
        ; loop end == %endloop, loop continue == %continueloop
        OpLoopMerge %endloop %continueloop None
        OpBranch %rankloop ;
        %rankloop = OpLabel
            ; loop condition
            ; loopgate is gt > 1 because we run reduce above once
            %rloopload = OpLoad %1 %iter
            %loopgate = OpUGreaterThan %bool %rloopload %uint_1
        OpBranchConditional %loopgate %start %endloop
        %start = OpLabel

            ; procedure sync start
            %leader = OpIEqual %bool %sgli_o %uint_0 ; are we subgroup leader?
            OpSelectionMerge %leader_end None
            OpBranchConditional %leader %leader_t %leader_f
            %leader_t = OpLabel ; if true

                %sync_ptr = OpAccessChain %_ptr_Uniform_float %out %uint_0 %53 ; nb: out array
                %sync_val = OpLoad %float %sync_ptr

                ; we need to figure out the index in the global memory registry
                ; to which we want to move the result. one way to figure this out
                ; is by dividing the global thread ID by the device's subgroup size
                ; i.e., the 32nd thread will get an index of 1 (32 / 32), which
                ; corresponds to the second memory slot in the global memory
                %dest = OpUDiv %1 %53 %sgs_o
                %sync_dest = OpAccessChain %_ptr_Uniform_float %out %uint_0 %dest
                OpStore %sync_dest %sync_val

                ; TODO: clear out the previous value after the move has happened
                ; nb: has to ensure we are not the subgroup group 0 (e.g. the target sg)

                OpBranch %leader_end
            %leader_f = OpLabel ; else
                OpBranch %leader_end
            %leader_end = OpLabel ; end
            ; procedure sync end

        OpBranch %continueloop
        %continueloop = OpLabel ; continue block

            ; since we use if above, we must block here
            ; this is essentially a precondition to wait for syncing to end
            OpControlBarrier %uint_1 %uint_1 %UniformMemory

            ; now that we have shifted values from subgroups to the first one,
            ; we must run one more reduction
            %70 = OpAccessChain %_ptr_Uniform_float %out %uint_0 %53
            %node_inner = OpFunctionCall %float %apply %70

            ; finally, we have to progress out while condition
            %iterLoad = OpLoad %1 %iter
            %iterAdd = OpISub %1 %iterLoad %uint_1
            OpStore %iter %iterAdd

        OpBranch %while_start
        %endloop = OpLabel

    OpReturn
    OpFunctionEnd

    %apply = OpFunction %float None %apply_signature
    %63 = OpFunctionParameter %_ptr_Uniform_float
    %apply_label = OpLabel

        %sgs = OpLoad %1 %SubgroupSize
        %sgi = OpLoad %1 %SubgroupID
        %sgli = OpLoad %1 %SubgroupLocalID

        ; invocation id ptr, "thread" id
        %inner_52 = OpAccessChain %wg %invocation_id %uint_0
        %inner_53 = OpLoad %1 %inner_52

        ; subgroup (sometimes called "warp") reduce
        ;
        ; each thread in a subgroup receives the sum of each
        ; threads' value in register %63
        %sum = OpGroupNonUniformFAdd %float %uint_3 Reduce %63

        ; in APL:
        ; dim.x = (0 = B) x +/w
        %leader_ko = OpIEqual %bool %sgli %uint_0 ; are we subgroup leader?
        %leader_uint = OpSelect %1 %leader_ko %uint_1 %uint_0 ; if so, assign 1, else 0
        %leader_float = OpConvertUToF %float %leader_uint ; conversion for mul
        %leader_val = OpFMul %float %sum %leader_float ; then multiple subgroup result with the assign
        ; effectively, if we are subgroup leader, we "keep" our value, otherwise we clear it as 0

        ; then, we store this value to our dim.x location
        %sum_dest = OpAccessChain %_ptr_Uniform_float %out %uint_0 %inner_53
        OpStore %sum_dest %leader_val

        OpReturnValue %sum
    OpFunctionEnd