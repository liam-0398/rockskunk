i7-9750H on battery, binary on NFS share.
# dsp/lpf
3 runs, 5,000,000 iterations
Optimizer dead code elimination, no register allocation
/NFS/Code/rockskunk $ > time ./lpf
1.000 
real    0m0.099s
user    0m0.076s
sys     0m0.008s
/NFS/Code/rockskunk $ > time ./lpf
1.000 
real    0m0.189s
user    0m0.091s
sys     0m0.012s
/NFS/Code/rockskunk $ > time ./lpf
1.000 
real    0m0.097s
user    0m0.088s
sys     0m0.006s

# dsp/firfilter
99 arrays, loops 100
Optimizer dead code elimination, no register allocation
/NFS/Code/rockskunk $ > time ./firfilter
1.000 
real    0m0.033s
user    0m0.009s
sys     0m0.005s
/NFS/Code/rockskunk $ > time ./firfilter
1.000 
real    0m0.008s
user    0m0.006s
sys     0m0.001s
/NFS/Code/rockskunk $ > time ./firfilter
1.000 
real    0m0.021s
user    0m0.013s
sys     0m0.007s
/NFS/Code/rockskunk $ > 

# dsp/advreverb
/NFS/Code/rockskunk $ > time ./advreverb 
0.500 

real    0m4.529s
user    0m4.527s
sys     0m0.004s
/NFS/Code/rockskunk $ > time ./advreverb 
0.500 

real    0m4.470s
user    0m4.449s
sys     0m0.021s
/NFS/Code/rockskunk $ > time ./advreverb 
0.500 

real    0m4.438s
user    0m4.427s
sys     0m0.008s
/NFS/Code/rockskunk $ > 

