g++ tins.s -o tins -mcmodel=medany -mabi=lp64d -march=rv64imadcv -latomic -static
g++ tttu_rv.s -o tttu_rv -mcmodel=medany -mabi=lp64d -march=rv64imadcv -latomic -static
g++ e_rv.s -o e_rv -mcmodel=medany -mabi=lp64d -march=rv64imadcv -latomic -static
g++ sieve_rv.s -o sieve_rv -mcmodel=medany -mabi=lp64d -march=rv64imadcv -latomic -static

