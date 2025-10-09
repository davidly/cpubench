# cpubench
A collection of benchmarks in C and assembly ported to various CPUs

This repo is mostly interesting for learning how instruction sets compare based on roughly equivalent assembly implementations of three benchmarks for a variety of CPUs.

It shows that for some apps newer CPUs offer instructions that make them faster. For others any performance improvements are due to clock speed, pipelining, speculative execution, etc. rather than improvements in instruction set architecture.

Benchmarks:

* sieve: The classic from BYTE magazine in 1981. Measures array access and loop performance
* e: calculates the value of e to 192 digits. Measures integer division, modulo, and multiplication performance along with array and loop performance
* ttt: proves one can't win at tic-tac-toe if the opponent is competent, from 1983's War Games. Measures function call, array, loop, and conditional performance

<img width="1673" height="438" alt="table" src="https://github.com/user-attachments/assets/8b8b3679-ba2e-4890-bae3-baceae5b7b1e" />


Notes:

* this table shows instruction counts for various benchmarks written in assembly and C ported to various CPUs.
* assembly always wins. I made optimizations a good compiler could make, but none fully implement yet.
* I'm not an expert at writing assembly for any of these architectures. I am certain others could make dramatic improvements. That said, these implementations are of roughly equal quality.
* I used the C compiler that generates on average the fastest code for each platform. Other compilers are faster for some code patterns. The C code varies somewhat between platforms to improve performance.
* I measured instruction counts on emulators I have written for each CPU aside from AMD64, which was measured in gdb. Emulators are available in sister repos.
* These are tiny benchmarks that fit in the smallest/fastest caches each CPU might have. Even so, Cycles per Instruction is a fraught metric that vendors spout but have little real-world meaning
* The cpi metrics shown here are for workloads that are similar to these benchmarks
* year available refers to when a computer containing the CPU was commercially available. CPUs themselves were available 1-3 years before these dates
* sparc v7 (the first sparc chip used in Sun Solaris workstations) had no integer multiply or divide instructions, so E runs slowly
* sparc v7 TTT and SIEVE share assembly implementations with v8
* the 8080 was notoriously difficult for C compilers to target; local variables require lots of instructions to work
* arm64 does especially well on E due to its multiply & add and multiply & subtract instructions
* older cpus required far more cycles per instruction and their clock rates were much lower
* SIEVE is largely the same for all CPUs for i8086 and later, which is pretty amazing
* the 6502 can only do math on 8-bit quantities. So E and SIEVE are slow because they require 16-bit arithmetic
* newer CPUs generally require fewer instructions that older CPUs, but the degree is highly dependent on the workload
* the C version of E on the 68000 performs badly because the GNU C runtime has a very slow integer division function. 
* the Z80 assembly version of E only differs from the 8080 version in that software-based integer division can use the Z80's 16-bit subtraction instruction
* the Z80 and 8086 have instructions that loop over up to 64k memory locations, so instruction counts can be deceiving
* hardware-based multiply and divide instructions can take many cycles, so instruction counts can be deceiving
* the 68000 is generally a 32-bit CPU. It's mixed 32 and 16-bit for multiply+divide and 16-bit at the hardware level for RAM access
  * 68000: i32 / i16 = i16 & remainder i16. i16 * i16 = i32. signed and unsigned for divide
