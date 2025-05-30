// RUN: mlir-translate -mlir-to-llvmir %s | FileCheck %s

module attributes {dlti.dl_spec = #dlti.dl_spec<#dlti.dl_entry<"dlti.alloca_memory_space", 5 : ui32>>, llvm.target_triple = "amdgcn-amd-amdhsa", omp.is_target_device = true} {
  llvm.func @_QQmain() attributes {fir.bindc_name = "main"} {
    %0 = llvm.mlir.addressof @_QFEi : !llvm.ptr
    %1 = llvm.mlir.addressof @_QFEsp : !llvm.ptr
    %2 = omp.map.info var_ptr(%1 : !llvm.ptr, i32) map_clauses(tofrom) capture(ByRef) -> !llvm.ptr {name = "sp"}
    %3 = omp.map.info var_ptr(%0 : !llvm.ptr, i32) map_clauses(to) capture(ByCopy) -> !llvm.ptr {name = "i"}
    omp.target map_entries(%2 -> %arg0, %3 -> %arg1 : !llvm.ptr, !llvm.ptr) {
      %4 = llvm.load %arg1 : !llvm.ptr -> i32
      llvm.store %4, %arg0 : i32, !llvm.ptr
      omp.terminator
    }
    llvm.return
  }
  llvm.mlir.global internal @_QFEi() {addr_space = 0 : i32} : i32 {
    %0 = llvm.mlir.constant(1 : i32) : i32
    llvm.return %0 : i32
  }
  llvm.mlir.global internal @_QFEsp() {addr_space = 0 : i32} : i32 {
    %0 = llvm.mlir.constant(0 : i32) : i32
    llvm.return %0 : i32
  }
}

// CHECK: define {{.*}} void @__omp_offloading_{{.*}}_{{.*}}__QQmain_l{{.*}}(ptr %[[DYN_PTR:.*]], ptr %[[ARG_BYREF:.*]], ptr %[[ARG_BYCOPY:.*]]) #{{[0-9]+}} {

// CHECK: entry:
// CHECK: %[[ALLOCA_BYREF:.*]] = alloca ptr, align 8, addrspace(5)
// CHECK: %[[ALLOCA_ASCAST:.*]] = addrspacecast ptr addrspace(5) %[[ALLOCA_BYREF]] to ptr
// CHECK: store ptr %[[ARG_BYREF]], ptr %[[ALLOCA_ASCAST]], align 8
// CHECK: %[[ALLOCA_BYCOPY:.*]] = alloca ptr, align 8, addrspace(5)
// CHECK: %[[ALLOCA_ASCAST2:.*]] = addrspacecast ptr addrspace(5) %[[ALLOCA_BYCOPY]] to ptr
// CHECK: store ptr %[[ARG_BYCOPY]], ptr %[[ALLOCA_ASCAST2]], align 8

// CHECK: user_code.entry:                                  ; preds = %entry
// CHECK: %[[LOAD_BYREF:.*]] = load ptr, ptr %[[ALLOCA_ASCAST]], align 8
// CHECK: br label %outlined.body

// CHECK: outlined.body:
// CHECK: br label %omp.target

// CHECK: omp.target:
// CHECK:  %[[VAL_LOAD_BYCOPY:.*]] = load i32, ptr %[[ALLOCA_ASCAST2]], align 4
// CHECK:  store i32 %[[VAL_LOAD_BYCOPY]], ptr %[[LOAD_BYREF]], align 4
// CHECK: br label %omp.region.cont
