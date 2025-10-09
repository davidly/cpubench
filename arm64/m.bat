gcc -o e_arm e_arm.s -nostdlib -nostartfiles -nodefaultlibs -march=native -mcpu=native -lpthread -static
gcc -o sieve_arm sieve_arm.s -nostdlib -nostartfiles -nodefaultlibs -march=native -mcpu=native -lpthread -static
gcc -o tttu_arm tttu_arm.s -march=native -mcpu=native -lpthread -static

