---
layout: post
title: How to read GoLang static single-assignment (SSA) form intermediate representation
---

We will start off by kicking out a simple example of uncomplicated for-range loop:

```
    package main

    import "fmt"

    type S struct {
        b [8]byte
    }

    func keys(m map[S]struct{}) [][]byte {
        var z [][]byte
        for k := range m {
            z = append(z, k.b[:])
        }
        return z
    }

    func main() {
        fmt.Println(keys(map[S]struct{}{
            S{b: [8]byte{1}}: struct{}{},
            S{b: [8]byte{2}}: struct{}{},
        }))
    }
```

Try to guess what will be printed out before running it.

The answer to the results may be found in GoLang specification under
the topic [](https://golang.org/ref/spec#For_statements).

Let's take a look into what compiler generates. In order see
intermediate representation (IR) of the program execute:

```
    env GOSSAFUNC=keys go build your_file_name.go
```

The compiler will print SSA representation, transformation steps
and the assembly at the end for function `keys`. Let's take a look
why we've got a result we've got.

Open `ssa.html`.

Take a look at first column:

```
b1:                                 ; new block label {b1} -
                                    ; program begining (init).
v1 = InitMem <mem>                  ; program heap
v2 = SP <uintptr>                   ; stack pointer
v3 = SB <uintptr>                   ; stack base
v4 = Addr <*map[S]struct {}> {m} v2 ; Get variable address {m}
                                    ; on stack (v2) of type
                                    ; <*map...> and remember it as v4.
                                    ; {m} - is first input argument.
v5 = Addr <*[][]byte> {~r1} v2      ; Get address of function result
                                    ; (return) variable {~r1}
v6 = Arg <map[S]struct {}> {m}      ; Get value of function argument
                                    ; {m}
v7 = ConstSlice <[][]byte>          ; Const slice nil lvalue of type.
v8 = Addr <*uint8> {type."".S} v3   ; Adress of the {S} struct type
                                    ; from global namespace (package).
v9 = OffPtr <**byte> [0] v2         ; New pointer to offset v2[0] =
                                    ; v2 + 0 = SP + 0 = SP
v10 = Store <mem> {*byte} v9 v8 v1  ; Store v8 to v9 at v1 memory.
                                    ; Put <S> type ptr on the stack.
                                    ; Returns memory.
                                    ; Store dstptr srcaddr mem -> mem
; arg0: stack[0] = S.(type)
v11 = StaticCall <mem> {runtime.newobject} [16] v10 ; create new obj
                                    ; of type v10 (type."".S) on heap
v12 = OffPtr <**S> [8] v2           ; Pointer to stack[+8] of <**S>
v13 = Load <*S> v12 v11             ; Pop stack value [0:8].
                                    ; The result of newobject(S.typ)
                                    ; call -> unsafe.Pointer from
                                    ; stack[0:8]

> at this point it is equivalent to
> var z [][]byte
> s := new(S)

v14 = Addr <*map.iter[S]struct {}> {.autotmp_6} v2 ; Get address
                                    ; of the local var {.autotmp_6}
                                    ; which will store map iter ptr.
v15 = VarDef <mem> {.autotmp_6} v11 ; Define new variable {.autotmp_6}
v16 = Zero <mem> {map.iter[S]struct {}} [96] v14 v15 ; Init with zeroe
                                    ; {.autotmp_6} of len 96 byte1

> var .autotmp_6 map.iter[S]struct{}

v17 = Addr <*uint8> {type.map["".S]struct {}} v3 ; Get adress of map
                                    ; type {map[S]struct{}}
v18 = Store <mem> {*byte} v9 v17 v16 ; Put type address on stack v2+0.
v19 = OffPtr <*map[S]struct {}> [8] v2 ; Pointer stack+8.
v20 = Store <mem> {map[S]struct {}} v19 v6 v18 ; [stack+8]={m} map ptr
v21 = Addr <*map.iter[S]struct {}> {.autotmp_6} v2 ; addr of tmp var
v22 = OffPtr <**map.iter[S]struct {}> [16] v2 ; ptr stack+16
v23 = Store <mem> {*map.iter[S]struct {}} v22 v21 v20 ; [stack+16]=
                                    ; val of tmp var = map iter ptr
; func mapiterinit(mapType *byte, hmap map[any]any, hiter *any)
; arg0: stack[0] = type.map["".S]struct {}
; arg1: stack[8] = {m} map from func keys arg0
; arg2: stack[16]= map iter ptr (to init)
v24 = StaticCall <mem> {runtime.mapiterinit} [24] v23 ; init map
                                    ; iter struct

> runtime.mapiterinit(map[S]struct{}.(type), m, &.autotmp_6)

v29 = ConstNil <*S>                 ; const nil S ptr lval
v39 = Const64 <int> [0]             ; int64 = 0 lval
v41 = Const64 <int> [8]
v51 = Const64 <int> [1]
v54 = Addr <*uint8> {type.[]uint8} v3 ; addr of []uint8 type
v57 = OffPtr <**[]byte> [8] v2      ; ptr to stack[8] (arg1) - z.len
v59 = OffPtr <*int> [16] v2         ; arg2
v61 = OffPtr <*int> [24] v2         ; arg3
v63 = OffPtr <*int> [32] v2         ; arg4 - z.ptr
v66 = OffPtr <**[]byte> [40] v2     ; arg5 - z.len
v68 = OffPtr <*int> [48] v2         ; arg6 - z.cap
v70 = OffPtr <*int> [56] v2         ; arg7
v90 = OffPtr <**map.iter[S]struct {}> [0] v2
                                    ; arg0 ptr to iter map ref
Plain → b2                          ; go to block b2
                                    ; straight away

; Assembly for block b1

00000 TEXT	"".keys(SB)
00001 FUNCDATA	$0, gclocals·0bc550b6b95948f318d057651e9cddea(SB)
00002 FUNCDATA	$1, gclocals·7ad199d7c1ca183f0a4df6a1e24a2a09(SB)

> s := new(S)
00003  LEAQ	type."".S(SB), AX
00004  MOVQ	AX, (SP)
00005  PCDATA	$0, $0
00006  CALL	runtime.newobject(SB)
00007  MOVQ	8(SP), AX
00008  MOVQ	AX, "".&k-104(SP)

> var .autotmp_6 map.iter[S]struct{}
00009  LEAQ	""..autotmp_6-96(SP), DI
00010  XORPS	X0, X0
00011  ADDQ	$-32, DI
00012  DUFFZERO	$273

> runtime.mapiterinit(map[S]struct{}.(type), m, &.autotmp_6)
00013  LEAQ	type.map["".S]struct {}(SB), CX
00014  MOVQ	CX, (SP)
00015  MOVQ	"".m(SP), CX
00016  MOVQ	CX, 8(SP)
00017  LEAQ	""..autotmp_6-96(SP), CX
00018  MOVQ	CX, 16(SP)
00019  PCDATA	$0, $1
00020  CALL	runtime.mapiterinit(SB)
00021  MOVL	$0, AX
00022  MOVQ	AX, CX
00023  MOVL	$0, DX
00024  JMP	32

======================================================================

b2: ← b1 b4                         ; new block {b2} - loop edge chck
                                    ;   continue if iter.key != nil,
                                    ;   with incoming jumps from {b1}
                                    ;   (init) and {b4}
v27 = Phi <mem> v24 v93             ; v27 = mem state
                                    ;   of runtime.mapiterinit if {b1}
                                    ;   of runtime.mapiternext if {b4}
v99 = Phi <[][]byte> v7 v88         ; v99 = mem state
                                    ;   of nil slice lval if from {b1}
                                    ;   of appended slice if from {b4}
v100 = Phi <*S> v13 v101            ; v3 = mem state
                                    ;   of new &S{} ptr if from {b1}
                                    ;   of copy of next item if {b4}
v25 = Addr <*map.iter[S]struct {}> {.autotmp_6} v2
                                    ; v25 = addr of {.autotmp_6} on v2
                                    ;   which is ptr to map iterator
v26 = OffPtr <**S> [0] v25          ; v26 = ptr to the ptr to S (map
                                    ;   elelment) (first byte in
                                    ;   map iterator var v25[0])
v28 = Load <*S> v26 v27             ; v28 = load cur {*S} Key from itr
v30 = NeqPtr <bool> v28 v29         ; v30 = v28<*S> != v29<nil>
If v30 → b3 b5 (likely)             ; goto {b3} if v30 == true, and
                                    ; to {b5} if not

> b2:
> var key *S = .autotmp_6.key
> if S != nil {
>   goto {b3}
> } else {
>   goto {b5}
> }

00029 MOVQ	"".z.cap-120(SP), AX
00030 MOVQ	"".z.len-128(SP), CX
00031 MOVQ	"".z.ptr-112(SP), DX
00032 MOVQ	""..autotmp_6-96(SP), BX
00033 TESTQ	BX, BX
00034 JEQ	76

======================================================================

b3: ← b2                            ; new block {b3} - load iter.key
                                    ;   and save it to local var,
                                    ;   with path fr {b2}
v31 = Addr <*map.iter[S]struct {}> {.autotmp_6} v2
                                    ; v31 = addr of {.autotmp_6} at v2
v32 = OffPtr <**S> [0] v31          ; v32 = ptr to v32[0] =
                                    ;   &.autotmp_6.key
v33 = Copy <mem> v27                ; v33 = copy map iter mem state
v34 = Load <*S> v32 v33             ; v34 = load cur map iter .key ptr
v35 = NilCheck <void> v34 v33       ; v35 = check result against <nil>
                                    ;   Panics if arg0 is nil.
v36 = Copy <*S> v100                ; v36 = copy ptr of local var
                                    ;   for holding cur S key val
v37 = Move <mem> {S} [8] v36 v34 v33; put cur key val (v34) to the v36
v38 = OffPtr <*[8]byte> [0] v36     ; v38 = ptr to v36[0] (ptr)
v40 = NilCheck <void> v38 v37       ; v40 = check v38 (s.b) for nil val
                                    ;   Panics if arg0 is nil.
v42 = IsSliceInBounds <bool> v39 v41; 0 <= arg0(0) <= arg1(8). arg1 is
                                    ;   guaranteed >= 0.
If v42 → b6 b7 (likely)             ; continue to {b6}, or
                                    ;   panic in {b7} if !{v42}

> b3:
> if iter.key == nil {
>    panic("key is nil")
> }
> *s = *iter.key                    ; where iter.key is unsafe.Ptr(*S)
> if s.b == nil {
>    panic("no next key")
> }

00035 MOVQ	(BX), BX
00036 MOVQ	"".&k-104(SP), SI
00037 MOVQ	BX, (SI)
00038 TESTB	AX, (SI)
00039 LEAQ	1(CX), BX
00040 CMPQ	BX, AX
00041 JGT	59

======================================================================

b4: ← b9                            ; step iterator next item
v89 = Addr <*map.iter[S]struct {}> {.autotmp_6} v2
                                    ; v89 = addr of {.autotmp_6} at v2
v91 = Copy <mem> v87                ; v91 = copy last mem state
v92 = Store <mem> {*map.iter[S]struct {}} v90 v89 v91
                                    ; put map iter ptr on stack top
v93 = StaticCall <mem> {runtime.mapiternext} [8] v92
                                    ; call for next map iter item
Plain → b2                          ; goto b2

> runtime.mapiternext(&.autotmp_6)

00025 LEAQ	""..autotmp_6-96(SP), AX
00026 MOVQ	AX, (SP)
00027 PCDATA	$0, $2
; func mapiternext(&.autotmp_6)
00028 CALL	runtime.mapiternext(SB)

======================================================================

b5: ← b2                            ; block to return from func
v94 = Copy <mem> v27                ; v94 = copy map iter mem state
v95 = VarKill <mem> {.autotmp_6} v94; dealloc local var {.autotmp_6}
v96 = Copy <[][]byte> v99           ; v96 = copy {z} mem state
v97 = VarDef <mem> {~r1} v95        ; v97 = return return value [][]b
v98 = Store <mem> {[][]byte} v5 v96 v97 
                                    ; put {z} to return val {~r1}
Ret v98                             ; return with mem state v98 {~r1}

> return z

00076 MOVQ	DX, "".~r1+8(SP)
00077 MOVQ	CX, "".~r1+16(SP)
00078 MOVQ	AX, "".~r1+24(SP)
00079 RET

======================================================================

b6: ← b3                            ; make new slice []byte
v45 = Sub64 <int> v41 v39           ; v45 = arg0 - arg1 = 8 - 0 = 8
v46 = SliceMake <[]byte> v38 v45 v45; v46 = new slice of []byte, len 8
                                    ;   pointing to {s.b} memory
v47 = Copy <[][]byte> v99           ; v47 = copy {z} slice [][]byte
v48 = SlicePtr <*[]byte> v47        ; v48 = z.ptr
v49 = SliceLen <int> v47            ; v49 = z.len
v50 = SliceCap <int> v47            ; v50 = z.cap
v52 = Add64 <int> v49 v51           ; v52 = z.len + 1
v53 = Greater64 <bool> v52 v50      ; v53 = (z.len + 1) > z.cap
If v53 → b8 b9 (unlikely)           ; if v53 true
                                    ;   goto {b8} to growslice, else
                                    ;   goto {b9} to append element

> z0 := s.b[:8]
> if len(z) + 1 > cap(z) {
>   goto {b8}
> } else {
>   goto {b9}
> }

00042 MOVQ	DX, "".z.ptr-112(SP)
00043 MOVQ	BX, "".z.len-128(SP)
00044 MOVQ	AX, "".z.cap-120(SP)
00045 LEAQ (CX)(CX*2), CX
00046 MOVQ	$8, 8(DX)(CX*8)
00047 MOVQ	$8, 16(DX)(CX*8)
00048 MOVL runtime.writeBarrier(SB), DI
00049 LEAQ (DX)(CX*8), R8
00050 TESTL DI, DI
00051 JNE	54

======================================================================

b7: ← b3                            ; panic for bad slice
v43 = Copy <mem> v37                ; copy map iter mem state after
                                    ;   reading cur key in {b3}
v44 = StaticCall <mem> {runtime.panicslice} v43 
Exit v44

> runtime.panicslice()

00052 MOVQ	SI, (DX)(CX*8)
00053 JMP	25

00054 MOVQ	R8, (SP)
00055 MOVQ	SI, 8(SP)
00056 PCDATA $0, $2
00057 CALL runtime.writebarrierptr(SB)
00058 JMP	25

======================================================================

b8: ← b6                            ; grow slice
v55 = Copy <mem> v37                ; copy cur key S mem state
v56 = Store <mem> {*uint8} v9 v54 v55 ; put {type.[]uint8} addrto arg0
v58 = Store <mem> {*[]byte} v57 v48 v56 ; put {z.ptr} to arg1
v60 = Store <mem> {int} v59 v49 v58 ; put {z.len} to arg2
v62 = Store <mem> {int} v61 v50 v60 ; put {z.cap} to arg3
v64 = Store <mem> {int} v63 v52 v62 ; put {z.len+1} new size to arg4
; func growslice(typ *byte, old []any, cap int) (ary []any)
v65 = StaticCall <mem> {runtime.growslice} [64] v64
                                    ; call runtime.growslice with args
                                    ; of 64 bytes long
v67 = Load <*[]byte> v66 v65        ; load new z.ptr
v69 = Load <int> v68 v65            ; load new z.len
v71 = Load <int> v70 v65            ; load new z.cap
v72 = Add64 <int> v69 v51           ; v72 = z.len + 1
Plain → b9                          ; goto to append

> runtime.growslice([]uint8.(type), z, len(z) + 1)

00059 MOVQ	CX, "".z.len-128(SP)
00060 LEAQ type.[]uint8(SB), SI
00061 MOVQ	SI, (SP)
00062 MOVQ	DX, 8(SP)
00063 MOVQ	CX, 16(SP)
00064 MOVQ	AX, 24(SP)
00065 MOVQ	BX, 32(SP)
00066 PCDATA $0, $1
00067 CALL runtime.growslice(SB)

======================================================================

b9: ← b6 b8                         ; append element
v74 = Phi <*[]byte> v48 v67         ; v74 = z.ptr
v75 = Phi <int> v52 v72             ; v75 = z.len + 1
v76 = Phi <int> v50 v71             ; v76 = z.cap
v81 = Phi <mem> v37 v65             ; latest mem state
v73 = Copy <[]byte> v46             ; copy new slice of len 8
v77 = PtrIndex <*[]byte> v74 v49    ; v77 = z[z.len] ptr of el ix
v78 = PtrIndex <*[]byte> v77 v39    ; v78 = z[z.len]+0 ptr of el ix
v79 = SliceLen <int> v73            ; v79 = new slice len (8)
v80 = OffPtr <*int> [8] v78         ; v80 = ptr to z last el
v82 = Store <mem> {int} v80 v79 v81 ; z[z.len]+8 = z0.len
v83 = SliceCap <int> v73            ; z0.cap 8
v84 = OffPtr <*int> [16] v78        ; v84 = z[z.len]+16 ptr
v85 = Store <mem> {int} v84 v83 v82 ; z[z.len]+16 = z0.cap 8
v86 = SlicePtr <*uint8> v73         ; v86 = z0.ptr
v87 = Store <mem> {*uint8} v78 v86 v85
                                    ; z[z.len]+0 = z0.ptr
v88 = SliceMake <[][]byte> v74 v75 v76
                                    ; make {z} grow by 1
v101 = Copy <*S> v36                ; copy {s} local key var
Plain → b4                          ; goto {b4}

> z[z.len] = z0
> z = z[:len(z)+1]

name z[[][]byte]: v7 v47 v88 v96 v99
name &k[*S]: v13 v36 v100 v101

00068 MOVQ 40(SP), DX
00069 MOVQ 48(SP), AX
00070 MOVQ 56(SP), CX
00071 LEAQ 1(AX), BX
00072 MOVQ "".&k-104(SP), SI
00073 MOVQ	CX, AX
00074 MOVQ "".z.len-128(SP), CX
00075 JMP	42

```

Conclusion
===

The original `keys` function rolls out into something like:

```
func keys(m map[S]struct{}) [][]byte {
    var z [][]byte

    var iter map.iter[S]struct{}
    runtime.mapiterinit(map[S]struct{}.(type), m, &iter)

    s := new(S)
    for iter.key != nil {
        if iter.key == nil {
           panic("key is nil")
        }
        *s = *iter.key
        if s.b == nil {
           panic("no next key")
        }

        runtime.mapiternext(&iter)

        z0 := s.b[:8]
        if len(z) + 1 > cap(z) {
            runtime.growslice([]uint8.(type), z, len(z) + 1)
        }

        z[len(z)] = z0
        z = z[:len(z)+1]
    }

    return z
}
```

Compiler allocated separate local variable for keeping
local state of the next item from the iterator on each
iteration of for-range loop. Slice which is appending
to the {z} slice is created against the same memory area
{s.b}. That is why function ends up with a slice {z}
containing the same values.

Go SSA does not differ much from the target assembly,
although blocks and instructions got reduced and sorted
during various optimization passes.

Links
===

- [go/ssa/doc.go](https://github.com/golang/tools/blob/master/go/ssa/doc.go)
- [GOSSAFUNC handler](https://github.com/golang/go/tree/master/src/cmd/compile/internal/gc/ssa_test.go)
- [cmd/compile/internal/ssa](https://github.com/golang/go/tree/master/src/cmd/compile/internal/ssa/\*)
- [instructions defs](https://github.com/golang/go/tree/master/src/cmd/compile/internal/ssa/gen/genericOps.go)
- [golang internal ssa docs](https://golang.org/pkg/cmd/compile/internal/ssa/)
